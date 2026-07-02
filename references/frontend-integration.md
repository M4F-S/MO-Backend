# Frontend Integration Reference

## Table of Contents
1. [CORS Configuration](#cors-configuration)
2. [BFF (Backend for Frontend)](#bff-backend-for-frontend)
3. [Shared Types Generation](#shared-types-generation)
4. [Next.js API Routes](#nextjs-api-routes)
5. [Auth for SPAs](#auth-for-spas)
6. [tRPC](#trpc)
7. [GraphQL for Frontend](#graphql-for-frontend)
8. [REST for Frontend](#rest-for-frontend)
9. [File Upload Handling](#file-upload-handling)
10. [WebSocket from Frontend](#websocket-from-frontend)
11. [SSE from Frontend](#sse-from-frontend)
12. [Real-Time State Sync](#real-time-state-sync)

---

## CORS Configuration

### Per-Environment Allowlists

```typescript
// cors-config.ts
interface CorsConfig {
  allowedOrigins: string[];
  allowedMethods: string[];
  allowedHeaders: string[];
  exposedHeaders: string[];
  allowCredentials: boolean;
  maxAge: number;
  preflightContinue: boolean;
}

const corsConfigs: Record<string, CorsConfig> = {
  development: {
    allowedOrigins: ['http://localhost:3000', 'http://localhost:5173', 'http://localhost:4200'],
    allowedMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type', 'X-Request-ID', 'X-Correlation-ID', 'Accept-Language'],
    exposedHeaders: ['X-Request-ID', 'X-Total-Count', 'X-RateLimit-Remaining'],
    allowCredentials: true,
    maxAge: 86400,
    preflightContinue: false,
  },
  staging: {
    allowedOrigins: ['https://staging.example.com', 'https://app-staging.example.com'],
    allowedMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type', 'X-Request-ID', 'X-Correlation-ID', 'Accept-Language'],
    exposedHeaders: ['X-Request-ID', 'X-Total-Count', 'X-RateLimit-Remaining'],
    allowCredentials: true,
    maxAge: 86400,
    preflightContinue: false,
  },
  production: {
    allowedOrigins: ['https://app.example.com', 'https://admin.example.com'],
    allowedMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type', 'X-Request-ID', 'X-Correlation-ID', 'Accept-Language'],
    exposedHeaders: ['X-Request-ID', 'X-Total-Count', 'X-RateLimit-Remaining'],
    allowCredentials: true,
    maxAge: 86400,
    preflightContinue: false,
  },
};

export function getCorsConfig(environment: string): CorsConfig {
  return corsConfigs[environment] || corsConfigs.development;
}
```

### Express CORS Implementation

```typescript
// cors-middleware.ts
import cors from 'cors';
import { getCorsConfig } from './cors-config';

export function corsMiddleware(environment: string) {
  const config = getCorsConfig(environment);

  return cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl, etc.)
      if (!origin) return callback(null, true);
      if (config.allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      callback(new Error(`Origin ${origin} not allowed by CORS`));
    },
    methods: config.allowedMethods,
    allowedHeaders: config.allowedHeaders,
    exposedHeaders: config.exposedHeaders,
    credentials: config.allowCredentials,
    maxAge: config.maxAge,
    preflightContinue: config.preflightContinue,
  });
}

// Handle CORS errors
export function corsErrorHandler(err: Error, req: Request, res: Response, next: NextFunction) {
  if (err.message?.includes('CORS')) {
    res.status(403).json({ error: 'CORS policy violation', message: err.message });
  } else {
    next(err);
  }
}
```

### Preflight Request Handling

```typescript
// preflight-handler.ts
export function handlePreflight(req: Request, res: Response, next: NextFunction) {
  if (req.method === 'OPTIONS') {
    res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Request-ID');
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    res.setHeader('Access-Control-Max-Age', '86400');
    res.setHeader('Vary', 'Origin'); // Important for caching
    res.status(204).send();
    return;
  }

  // Add Vary header for proper cache behavior
  res.setHeader('Vary', 'Origin, Access-Control-Request-Headers, Access-Control-Request-Method');
  next();
}
```

### Vary Header Best Practices

```typescript
// vary-header.ts
export function addVaryHeaders(req: Request, res: Response, next: NextFunction) {
  // Tell caches that responses vary based on these headers
  res.vary('Origin');
  res.vary('Accept-Encoding');
  res.vary('Accept-Language');
  res.vary('Authorization');
  next();
}
```

---

## BFF (Backend for Frontend)

### Pattern Overview

**When to Use BFF:**
- Multiple frontend platforms (web, mobile, admin) need different data shapes
- Frontend teams need autonomy from backend API evolution
- Complex aggregation across multiple services
- Need for frontend-specific caching or optimization

**When NOT to Use BFF:**
- Single frontend consuming a simple REST API
- Backend already provides GraphQL
- Team too small to maintain extra service

### Next.js API Routes as BFF

```typescript
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const page = searchParams.get('page') || '1';
  const limit = searchParams.get('limit') || '10';

  // Call backend service
  const response = await fetch(`${process.env.BACKEND_URL}/users?page=${page}&limit=${limit}`, {
    headers: {
      'Authorization': request.headers.get('Authorization') || '',
      'X-Request-ID': request.headers.get('X-Request-ID') || crypto.randomUUID(),
    },
  });

  if (!response.ok) {
    return NextResponse.json(
      { error: 'Failed to fetch users' },
      { status: response.status }
    );
  }

  const data = await response.json();

  // Transform for frontend needs
  return NextResponse.json({
    users: data.items.map(transformUserForFrontend),
    pagination: {
      currentPage: data.page,
      totalPages: data.totalPages,
      totalItems: data.total,
      hasNextPage: data.page < data.totalPages,
      hasPrevPage: data.page > 1,
    },
  });
}

function transformUserForFrontend(user: BackendUser): FrontendUser {
  return {
    id: user.id,
    name: `${user.firstName} ${user.lastName}`,
    email: user.email,
    avatarUrl: user.avatarUrl || '/default-avatar.png',
    role: user.role,
    isActive: user.status === 'active',
    memberSince: user.createdAt,
    // Omit sensitive fields not needed by frontend
  };
}
```

### Separate BFF Service

```typescript
// bff-service.ts
import express from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';

const app = express();

// Auth middleware for all BFF routes
app.use('/api/*', authenticateRequest);

// Aggregate multiple backend calls
app.get('/api/dashboard', async (req, res) => {
  const [user, orders, notifications] = await Promise.all([
    fetchUser(req.user.id),
    fetchRecentOrders(req.user.id),
    fetchNotifications(req.user.id),
  ]);

  res.json({
    user: { name: user.name, avatar: user.avatar },
    recentOrders: orders.slice(0, 5),
    unreadNotifications: notifications.filter(n => !n.read).length,
    quickActions: deriveQuickActions(user, orders),
  });
});

// Proxy specific routes to backend
app.use('/api/users', createProxyMiddleware({
  target: process.env.USER_SERVICE_URL,
  changeOrigin: true,
  pathRewrite: { '^/api/users': '/users' },
  onProxyReq: (proxyReq, req) => {
    proxyReq.setHeader('X-User-ID', req.user.id);
  },
}));
```

---

## Shared Types Generation

### OpenAPI → TypeScript

```yaml
# openapi.yaml (excerpt)
openapi: 3.0.0
info:
  title: Order API
  version: 1.0.0
paths:
  /orders:
    get:
      operationId: listOrders
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [pending, confirmed, shipped, delivered, cancelled]
      responses:
        200:
          description: List of orders
          content:
            application/json:
              schema:
                type: object
                properties:
                  items:
                    type: array
                    items:
                      $ref: '#/components/schemas/Order'
                  total:
                    type: integer
components:
  schemas:
    Order:
      type: object
      required: [id, userId, status, total, createdAt]
      properties:
        id:
          type: string
          format: uuid
        userId:
          type: string
          format: uuid
        status:
          type: string
          enum: [pending, confirmed, shipped, delivered, cancelled]
        items:
          type: array
          items:
            $ref: '#/components/schemas/OrderItem'
        total:
          type: number
          format: decimal
        shippingAddress:
          $ref: '#/components/schemas/Address'
        createdAt:
          type: string
          format: date-time
```

```bash
# Generate TypeScript types from OpenAPI
npm install -g openapi-typescript

openapi-typescript openapi.yaml --output types/api.ts
```

```typescript
// Generated types (types/api.ts)
export interface paths {
  '/orders': {
    get: {
      parameters: {
        query: {
          status?: 'pending' | 'confirmed' | 'shipped' | 'delivered' | 'cancelled';
        };
      };
      responses: {
        200: {
          content: {
            'application/json': {
              items: components['schemas']['Order'][];
              total: number;
            };
          };
        };
      };
    };
  };
}

export interface components {
  schemas: {
    Order: {
      id: string;
      userId: string;
      status: 'pending' | 'confirmed' | 'shipped' | 'delivered' | 'cancelled';
      items?: components['schemas']['OrderItem'][];
      total: number;
      shippingAddress?: components['schemas']['Address'];
      createdAt: string;
    };
  };
}
```

### Prisma → Zod

```typescript
// prisma-to-zod.ts
import { z } from 'zod';
import { Prisma } from '@prisma/client';

// Manually mirror Prisma types in Zod for validation
const OrderStatus = z.enum(['pending', 'confirmed', 'shipped', 'delivered', 'cancelled']);

const OrderItemSchema = z.object({
  productId: z.string().uuid(),
  quantity: z.number().int().positive(),
  price: z.number().positive(),
});

const AddressSchema = z.object({
  street: z.string().min(1).max(255),
  city: z.string().min(1).max(100),
  state: z.string().length(2),
  zip: z.string().regex(/^\d{5}(-\d{4})?$/),
  country: z.string().default('US'),
});

export const CreateOrderSchema = z.object({
  items: z.array(OrderItemSchema).min(1),
  shippingAddress: AddressSchema,
  notes: z.string().max(1000).optional(),
});

export type CreateOrderInput = z.infer<typeof CreateOrderSchema>;

// Or use automatic generator
// npm install prisma-zod-generator
// generator zod {
//   provider = "prisma-zod-generator"
//   output   = "./zod"
// }
```

### GraphQL Codegen

```yaml
# codegen.yml
overwrite: true
schema: "http://localhost:4000/graphql"
documents: "src/graphql/**/*.graphql"
generates:
  src/graphql/generated.ts:
    plugins:
      - "typescript"
      - "typescript-operations"
      - "typescript-react-apollo"
    config:
      withHooks: true
      withComponent: false
      withHOC: false
```

```graphql
# src/graphql/GetOrders.graphql
query GetOrders($status: OrderStatus, $limit: Int) {
  orders(status: $status, limit: $limit) {
    id
    status
    total
    items {
      productId
      quantity
    }
    createdAt
  }
}
```

```typescript
// Generated hook (use in React component)
import { useGetOrdersQuery } from './graphql/generated';

function OrderList() {
  const { data, loading, error } = useGetOrdersQuery({
    variables: { status: 'PENDING', limit: 10 },
  });

  if (loading) return <Skeleton />;
  if (error) return <ErrorMessage error={error} />;

  return (
    <ul>
      {data?.orders.map(order => (
        <li key={order.id}>{order.status} - ${order.total}</li>
      ))}
    </ul>
  );
}
```

---

## Next.js API Routes

### Auth Middleware

```typescript
// app/api/middleware/auth.ts
import { NextRequest, NextResponse } from 'next/server';
import { verifyToken } from '@/lib/auth';

export async function authMiddleware(request: NextRequest) {
  const token = request.cookies.get('session')?.value;

  if (!token) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const user = await verifyToken(token);
    request.user = user; // Extend NextRequest type
    return null; // Continue to handler
  } catch {
    return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
  }
}

// Type extension
// types/next.d.ts
declare module 'next/server' {
  interface NextRequest {
    user?: {
      id: string;
      email: string;
      role: string;
    };
  }
}
```

### Proxy to Backend

```typescript
// app/api/[...path]/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest, { params }: { params: { path: string[] } }) {
  const path = params.path.join('/');
  const searchParams = request.nextUrl.searchParams.toString();
  const url = `${process.env.BACKEND_URL}/${path}${searchParams ? `?${searchParams}` : ''}`;

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Authorization': request.headers.get('Authorization') || '',
      'Content-Type': 'application/json',
      'X-Request-ID': crypto.randomUUID(),
    },
  });

  const data = await response.json();
  return NextResponse.json(data, { status: response.status });
}

export async function POST(request: NextRequest, { params }: { params: { path: string[] } }) {
  const path = params.path.join('/');
  const body = await request.json();

  const response = await fetch(`${process.env.BACKEND_URL}/${path}`, {
    method: 'POST',
    headers: {
      'Authorization': request.headers.get('Authorization') || '',
      'Content-Type': 'application/json',
      'X-Request-ID': crypto.randomUUID(),
    },
    body: JSON.stringify(body),
  });

  const data = await response.json();
  return NextResponse.json(data, { status: response.status });
}
```

### Server-Side Data Fetching

```typescript
// app/page.tsx (Server Component)
async function getDashboardData(userId: string) {
  const response = await fetch(`${process.env.API_URL}/dashboard/${userId}`, {
    headers: { Authorization: `Bearer ${process.env.API_KEY}` },
    next: { revalidate: 60 }, // ISR: revalidate every 60s
  });

  if (!response.ok) throw new Error('Failed to fetch dashboard');
  return response.json();
}

export default async function DashboardPage() {
  const session = await getServerSession();
  if (!session) redirect('/login');

  const data = await getDashboardData(session.user.id);

  return <Dashboard data={data} />;
}
```

### File Uploads

```typescript
// app/api/upload/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const s3 = new S3Client({ region: 'us-east-1' });

export async function POST(request: NextRequest) {
  const formData = await request.formData();
  const file = formData.get('file') as File;

  if (!file) {
    return NextResponse.json({ error: 'No file provided' }, { status: 400 });
  }

  // Validate file
  const maxSize = 10 * 1024 * 1024; // 10MB
  if (file.size > maxSize) {
    return NextResponse.json({ error: 'File too large' }, { status: 413 });
  }

  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
  if (!allowedTypes.includes(file.type)) {
    return NextResponse.json({ error: 'Invalid file type' }, { status: 415 });
  }

  // Generate presigned URL for direct S3 upload
  const key = `uploads/${Date.now()}-${file.name}`;
  const command = new PutObjectCommand({
    Bucket: process.env.S3_BUCKET,
    Key: key,
    ContentType: file.type,
  });

  const presignedUrl = await getSignedUrl(s3, command, { expiresIn: 300 });

  return NextResponse.json({
    presignedUrl,
    key,
    expiresIn: 300,
  });
}
```

---

## Auth for SPAs

### httpOnly Cookies vs localStorage

```typescript
// auth-strategy.ts
interface AuthStrategy {
  method: 'cookie' | 'localStorage';
  pros: string[];
  cons: string[];
  xssVulnerable: boolean;
  csrfVulnerable: boolean;
  recommended: boolean;
}

const authStrategies: AuthStrategy[] = [
  {
    method: 'cookie',
    pros: ['XSS-resistant', 'Automatic send with requests', 'Can be httpOnly + secure + sameSite'],
    cons: ['CSRF risk without tokens', 'Size limits (~4KB)', 'Subdomain sharing complexity'],
    xssVulnerable: false,
    csrfVulnerable: true, // Mitigated with SameSite + CSRF token
    recommended: true,
  },
  {
    method: 'localStorage',
    pros: ['Simple implementation', 'No CSRF risk', 'Large storage'],
    cons: ['Vulnerable to XSS', 'Must manually attach to every request', 'No built-in expiry'],
    xssVulnerable: true,
    csrfVulnerable: false,
    recommended: false,
  },
];

// Recommended: httpOnly cookie + refresh token rotation
```

### Refresh Token Rotation

```typescript
// auth-service.ts
interface TokenPair {
  accessToken: string;
  refreshToken: string;
  accessTokenExpires: Date;
  refreshTokenExpires: Date;
}

class AuthService {
  async login(email: string, password: string): Promise<TokenPair> {
    const user = await this.validateCredentials(email, password);
    return this.generateTokenPair(user);
  }

  async refreshTokens(refreshToken: string): Promise<TokenPair> {
    const stored = await this.tokenStore.get(refreshToken);
    if (!stored || stored.revoked || new Date() > stored.expiresAt) {
      throw new Error('Invalid refresh token');
    }

    // Rotate: invalidate old, issue new
    await this.tokenStore.revoke(stored.id);
    const user = await this.userService.findById(stored.userId);
    return this.generateTokenPair(user);
  }

  private generateTokenPair(user: User): TokenPair {
    const accessToken = jwt.sign(
      { sub: user.id, role: user.role },
      process.env.ACCESS_TOKEN_SECRET,
      { expiresIn: '15m' }
    );

    const refreshToken = crypto.randomUUID();
    const refreshTokenHash = hashToken(refreshToken);

    // Store hashed refresh token
    this.tokenStore.create({
      userId: user.id,
      tokenHash: refreshTokenHash,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      createdAt: new Date(),
    });

    return {
      accessToken,
      refreshToken,
      accessTokenExpires: new Date(Date.now() + 15 * 60 * 1000),
      refreshTokenExpires: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    };
  }
}
```

### CSRF Protection

```typescript
// csrf-protection.ts
import csrf from 'csurf';

// Backend: CSRF token generation
const csrfProtection = csrf({
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
  },
});

app.get('/api/csrf-token', csrfProtection, (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});

// Protected routes
app.post('/api/orders', csrfProtection, async (req, res) => {
  // CSRF token automatically validated
});

// Frontend: Fetch and attach CSRF token
async function apiClient(endpoint: string, options: RequestInit = {}) {
  const csrfToken = await getCsrfToken(); // From cookie or header
  return fetch(endpoint, {
    ...options,
    headers: {
      ...options.headers,
      'X-CSRF-Token': csrfToken,
    },
    credentials: 'include',
  });
}
```

---

## tRPC

### Full-Stack Type Safety

```typescript
// server/trpc.ts
import { initTRPC } from '@trpc/server';
import { z } from 'zod';

const t = initTRPC.create();

export const router = t.router;
export const publicProcedure = t.procedure;
export const middleware = t.middleware;

// Auth middleware
const isAuthed = middleware(({ ctx, next }) => {
  if (!ctx.user) throw new Error('UNAUTHORIZED');
  return next({ ctx: { user: ctx.user } });
});

export const authedProcedure = t.procedure.use(isAuthed);
```

```typescript
// server/routers/order.ts
import { router, publicProcedure, authedProcedure } from '../trpc';
import { z } from 'zod';

export const orderRouter = router({
  // Public procedure
  getById: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input, ctx }) => {
      return ctx.prisma.order.findUnique({ where: { id: input.id } });
    }),

  // Protected procedure
  create: authedProcedure
    .input(z.object({
      items: z.array(z.object({
        productId: z.string().uuid(),
        quantity: z.number().int().positive(),
      })).min(1),
      shippingAddress: z.object({
        street: z.string(),
        city: z.string(),
        zip: z.string(),
      }),
    }))
    .mutation(async ({ input, ctx }) => {
      return ctx.prisma.order.create({
        data: {
          userId: ctx.user.id,
          ...input,
          status: 'PENDING',
        },
      });
    }),

  // Subscription for real-time updates
  onStatusChange: authedProcedure
    .input(z.object({ orderId: z.string().uuid() }))
    .subscription(async function* ({ input, ctx }) {
      for await (const event of ctx.eventEmitter.on(`order:${input.orderId}`)) {
        yield event;
      }
    }),
});
```

```typescript
// server/index.ts - Main router
import { router } from './trpc';
import { orderRouter } from './routers/order';
import { userRouter } from './routers/user';

export const appRouter = router({
  order: orderRouter,
  user: userRouter,
});

export type AppRouter = typeof appRouter;
```

```typescript
// client/trpc.ts
import { createTRPCNext } from '@trpc/next';
import { httpBatchLink } from '@trpc/client';
import { AppRouter } from '../server';

export const trpc = createTRPCNext<AppRouter>({
  config() {
    return {
      links: [
        httpBatchLink({
          url: '/api/trpc',
          headers() {
            return {
              Authorization: `Bearer ${getToken()}`,
            };
          },
        }),
      ],
    };
  },
});
```

```typescript
// client/components/OrderList.tsx
import { trpc } from '../trpc';

function OrderList() {
  // Fully typed - autocomplete works for all routes
  const { data: orders, isLoading } = trpc.order.list.useQuery({
    status: 'PENDING',
    limit: 10,
  });

  const createOrder = trpc.order.create.useMutation({
    onSuccess: () => {
      // Auto-invalidates related queries
      utils.order.list.invalidate();
    },
  });

  if (isLoading) return <Loading />;

  return (
    <div>
      {orders?.map(order => (
        <OrderCard key={order.id} order={order} />
      ))}
      <button onClick={() => createOrder.mutate({ items: [...], shippingAddress: {...} })}>
        Create Order
      </button>
    </div>
  );
}
```

---

## GraphQL for Frontend

### Apollo Client Setup

```typescript
// client/apollo.ts
import { ApolloClient, InMemoryCache, createHttpLink, split } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { createClient } from 'graphql-ws';
import { getMainDefinition } from '@apollo/client/utilities';

const httpLink = createHttpLink({
  uri: '/graphql',
  credentials: 'include',
});

const authLink = setContext((_, { headers }) => {
  const token = getToken();
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : '',
    },
  };
});

const wsLink = new GraphQLWsLink(createClient({
  url: 'wss://api.example.com/graphql',
  connectionParams: {
    authorization: getToken(),
  },
}));

// Split based on operation type
const splitLink = split(
  ({ query }) => {
    const definition = getMainDefinition(query);
    return (
      definition.kind === 'OperationDefinition' &&
      definition.operation === 'subscription'
    );
  },
  wsLink,
  authLink.concat(httpLink)
);

export const client = new ApolloClient({
  link: splitLink,
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          orders: {
            // Merge paginated results
            keyArgs: ['status'],
            merge(existing = [], incoming) {
              return [...existing, ...incoming];
            },
          },
        },
      },
      Order: {
        keyFields: ['id'],
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      fetchPolicy: 'cache-and-network',
    },
  },
});
```

### Fragments and Caching

```graphql
# fragments/OrderFragments.graphql
fragment OrderFields on Order {
  id
  status
  total
  createdAt
  items {
    productId
    quantity
    price
  }
}

fragment UserFields on User {
  id
  name
  email
  avatar
}
```

```typescript
// Using fragments with cache updates
import { gql } from '@apollo/client';

const GET_ORDERS = gql`
  query GetOrders($status: OrderStatus) {
    orders(status: $status) {
      ...OrderFields
    }
  }
  ${ORDER_FIELDS}
`;

// Optimistic update
function updateOrderStatus(orderId: string, newStatus: string) {
  client.mutate({
    mutation: UPDATE_ORDER_STATUS,
    variables: { id: orderId, status: newStatus },
    optimisticResponse: {
      updateOrderStatus: {
        id: orderId,
        status: newStatus,
        __typename: 'Order',
      },
    },
    update(cache, { data }) {
      cache.modify({
        id: cache.identify({ id: orderId, __typename: 'Order' }),
        fields: {
          status() {
            return data.updateOrderStatus.status;
          },
        },
      });
    },
  });
}
```

### Subscriptions

```typescript
// Real-time order status updates
const ORDER_STATUS_SUBSCRIPTION = gql`
  subscription OnOrderStatusChanged($orderId: ID!) {
    orderStatusChanged(orderId: $orderId) {
      id
      status
      updatedAt
    }
  }
`;

function OrderStatusTracker({ orderId }: { orderId: string }) {
  const { data } = useSubscription(ORDER_STATUS_SUBSCRIPTION, {
    variables: { orderId },
  });

  useEffect(() => {
    if (data?.orderStatusChanged) {
      toast.success(`Order status updated to ${data.orderStatusChanged.status}`);
    }
  }, [data]);

  return null;
}
```

---

## REST for Frontend

### Fetch Patterns

```typescript
// api-client.ts
interface ApiClientConfig {
  baseUrl: string;
  defaultHeaders: Record<string, string>;
  timeout: number;
  retries: number;
  retryDelay: number;
}

class ApiClient {
  private config: ApiClientConfig;

  async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${this.config.baseUrl}${endpoint}`;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.config.timeout);

    try {
      const response = await fetch(url, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...this.config.defaultHeaders,
          ...options.headers,
        },
        signal: controller.signal,
        credentials: 'include',
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const error = await response.json().catch(() => ({}));
        throw new ApiError(response.status, error.message || 'Request failed', error);
      }

      if (response.status === 204) return null as T;
      return response.json();
    } catch (error) {
      clearTimeout(timeoutId);
      if (error.name === 'AbortError') {
        throw new ApiError(408, 'Request timeout');
      }
      throw error;
    }
  }

  async get<T>(endpoint: string, params?: Record<string, string>): Promise<T> {
    const query = params ? `?${new URLSearchParams(params)}` : '';
    return this.request<T>(`${endpoint}${query}`, { method: 'GET' });
  }

  async post<T>(endpoint: string, body: unknown): Promise<T> {
    return this.request<T>(endpoint, { method: 'POST', body: JSON.stringify(body) });
  }
}

class ApiError extends Error {
  constructor(public status: number, message: string, public data?: any) {
    super(message);
  }
}
```

### Pagination

```typescript
// pagination-types.ts
interface PaginatedResponse<T> {
  items: T[];
  pagination: {
    currentPage: number;
    totalPages: number;
    totalItems: number;
    hasNextPage: boolean;
    hasPrevPage: boolean;
  };
}

interface PaginationParams {
  page?: number;
  limit?: number;
  cursor?: string;
}

// Cursor-based pagination (recommended)
async function fetchOrders(cursor?: string): Promise<PaginatedResponse<Order>> {
  const params = new URLSearchParams();
  if (cursor) params.set('cursor', cursor);
  params.set('limit', '20');

  const response = await fetch(`/api/orders?${params}`);
  return response.json();
}

// React hook for infinite scroll
function useInfiniteOrders() {
  return useInfiniteQuery({
    queryKey: ['orders'],
    queryFn: ({ pageParam }) => fetchOrders(pageParam),
    getNextPageParam: (lastPage) =>
      lastPage.pagination.hasNextPage ? lastPage.pagination.nextCursor : undefined,
  });
}
```

### Filtering & Sorting

```typescript
// Filter/sort params
interface ListParams {
  filter?: Record<string, string | string[]>;
  sort?: { field: string; direction: 'asc' | 'desc' };
  page?: number;
  limit?: number;
}

// URL building
function buildListUrl(base: string, params: ListParams): string {
  const url = new URL(base, window.location.origin);

  if (params.filter) {
    for (const [key, value] of Object.entries(params.filter)) {
      if (Array.isArray(value)) {
        value.forEach(v => url.searchParams.append(`filter[${key}]`, v));
      } else {
        url.searchParams.set(`filter[${key}]`, value);
      }
    }
  }

  if (params.sort) {
    url.searchParams.set('sort', `${params.sort.field},${params.sort.direction}`);
  }

  if (params.page) url.searchParams.set('page', String(params.page));
  if (params.limit) url.searchParams.set('limit', String(params.limit));

  return url.toString();
}

// Usage: /api/orders?filter[status]=pending&filter[status]=confirmed&sort=createdAt,desc&page=1&limit=20
```

### Error Handling

```typescript
// error-handler.ts
interface ApiErrorResponse {
  status: number;
  code: string;
  message: string;
  details?: Record<string, string[]>;
  retryAfter?: number;
}

class FrontendErrorHandler {
  handle(error: ApiError): void {
    switch (error.status) {
      case 400:
        this.handleBadRequest(error);
        break;
      case 401:
        this.redirectToLogin();
        break;
      case 403:
        this.showForbidden();
        break;
      case 404:
        this.showNotFound();
        break;
      case 409:
        this.handleConflict(error);
        break;
      case 422:
        this.handleValidation(error);
        break;
      case 429:
        this.handleRateLimit(error);
        break;
      case 500:
      case 502:
      case 503:
        this.showServerError(error);
        break;
      default:
        this.showGenericError(error);
    }
  }

  private handleValidation(error: ApiError): void {
    const details = error.data?.details || {};
    for (const [field, messages] of Object.entries(details)) {
      form.setError(field, { message: messages[0] });
    }
  }

  private handleRateLimit(error: ApiError): void {
    const retryAfter = error.data?.retryAfter || 60;
    toast.error(`Rate limited. Please try again in ${retryAfter} seconds.`);
  }
}
```

---

## File Upload Handling

### Multipart Upload

```typescript
// multipart-upload.ts
async function uploadFile(file: File, onProgress: (progress: number) => void): Promise<UploadResult> {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('filename', file.name);
  formData.append('contentType', file.type);

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();

    xhr.upload.addEventListener('progress', (event) => {
      if (event.lengthComputable) {
        const progress = (event.loaded / event.total) * 100;
        onProgress(progress);
      }
    });

    xhr.addEventListener('load', () => {
      if (xhr.status === 200) {
        resolve(JSON.parse(xhr.responseText));
      } else {
        reject(new Error(`Upload failed: ${xhr.statusText}`));
      }
    });

    xhr.addEventListener('error', () => reject(new Error('Upload failed')));
    xhr.addEventListener('abort', () => reject(new Error('Upload aborted')));

    xhr.open('POST', '/api/upload');
    xhr.setRequestHeader('Authorization', `Bearer ${getToken()}`);
    xhr.send(formData);
  });
}
```

### Presigned URLs (Direct S3 Upload)

```typescript
// direct-upload.ts
async function uploadToS3(file: File): Promise<string> {
  // 1. Get presigned URL from backend
  const { presignedUrl, key, publicUrl } = await fetch('/api/upload/presigned', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: file.name,
      contentType: file.type,
      size: file.size,
    }),
  }).then(r => r.json());

  // 2. Upload directly to S3
  const response = await fetch(presignedUrl, {
    method: 'PUT',
    body: file,
    headers: {
      'Content-Type': file.type,
    },
  });

  if (!response.ok) throw new Error('S3 upload failed');

  // 3. Confirm upload to backend
  await fetch('/api/upload/confirm', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ key }),
  });

  return publicUrl;
}
```

### Validation

```typescript
// file-validation.ts
interface FileValidation {
  maxSize: number;
  allowedTypes: string[];
  allowedExtensions: string[];
  maxWidth?: number;
  maxHeight?: number;
}

async function validateFile(file: File, rules: FileValidation): Promise<string[]> {
  const errors: string[] = [];

  if (file.size > rules.maxSize) {
    errors.push(`File too large. Max size: ${formatBytes(rules.maxSize)}`);
  }

  if (!rules.allowedTypes.includes(file.type)) {
    errors.push(`Invalid file type. Allowed: ${rules.allowedTypes.join(', ')}`);
  }

  const extension = file.name.split('.').pop()?.toLowerCase();
  if (!rules.allowedExtensions.includes(extension || '')) {
    errors.push(`Invalid extension. Allowed: ${rules.allowedExtensions.join(', ')}`);
  }

  // Image dimension check
  if (rules.maxWidth || rules.maxHeight) {
    const dimensions = await getImageDimensions(file);
    if (rules.maxWidth && dimensions.width > rules.maxWidth) {
      errors.push(`Image width too large. Max: ${rules.maxWidth}px`);
    }
    if (rules.maxHeight && dimensions.height > rules.maxHeight) {
      errors.push(`Image height too large. Max: ${rules.maxHeight}px`);
    }
  }

  return errors;
}
```

---

## WebSocket from Frontend

### Socket.io Client

```typescript
// socket-client.ts
import { io, Socket } from 'socket.io-client';

class SocketClient {
  private socket: Socket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;

  connect(token: string): void {
    this.socket = io(process.env.NEXT_PUBLIC_WS_URL, {
      auth: { token },
      transports: ['websocket'],
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      reconnectionAttempts: this.maxReconnectAttempts,
    });

    this.socket.on('connect', () => {
      console.log('Socket connected:', this.socket?.id);
      this.reconnectAttempts = 0;
    });

    this.socket.on('connect_error', (error) => {
      console.error('Socket connection error:', error.message);
      this.reconnectAttempts++;
      if (this.reconnectAttempts >= this.maxReconnectAttempts) {
        this.socket?.disconnect();
        this.emit('max_reconnect_exceeded');
      }
    });

    this.socket.on('disconnect', (reason) => {
      console.log('Socket disconnected:', reason);
      if (reason === 'io server disconnect') {
        // Server forced disconnect, need to reconnect manually
        this.socket?.connect();
      }
    });
  }

  joinRoom(room: string): void {
    this.socket?.emit('join', room);
  }

  leaveRoom(room: string): void {
    this.socket?.emit('leave', room);
  }

  on(event: string, callback: (...args: any[]) => void): void {
    this.socket?.on(event, callback);
  }

  off(event: string, callback: (...args: any[]) => void): void {
    this.socket?.off(event, callback);
  }

  emit(event: string, ...args: any[]): void {
    this.socket?.emit(event, ...args);
  }

  disconnect(): void {
    this.socket?.disconnect();
    this.socket = null;
  }
}

export const socketClient = new SocketClient();
```

### React Hook for WebSocket

```typescript
// useSocket.ts
import { useEffect, useCallback, useState } from 'react';
import { socketClient } from './socket-client';

export function useSocket(event: string, room?: string) {
  const [data, setData] = useState<any>(null);
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    const token = getToken();
    socketClient.connect(token);

    socketClient.on('connect', () => setIsConnected(true));
    socketClient.on('disconnect', () => setIsConnected(false));

    if (room) {
      socketClient.joinRoom(room);
    }

    const handler = (payload: any) => setData(payload);
    socketClient.on(event, handler);

    return () => {
      socketClient.off(event, handler);
      if (room) socketClient.leaveRoom(room);
    };
  }, [event, room]);

  const send = useCallback((payload: any) => {
    socketClient.emit(event, payload);
  }, [event]);

  return { data, isConnected, send };
}

// Usage
function OrderUpdates({ orderId }: { orderId: string }) {
  const { data, isConnected } = useSocket('order:update', `order:${orderId}`);

  return (
    <div>
      <Badge color={isConnected ? 'green' : 'red'}>
        {isConnected ? 'Live' : 'Disconnected'}
      </Badge>
      {data && <OrderStatus status={data.status} />}
    </div>
  );
}
```

---

## SSE from Frontend

### EventSource

```typescript
// sse-client.ts
class SSEClient {
  private eventSource: EventSource | null = null;
  private reconnectTimer: NodeJS.Timeout | null = null;
  private lastEventId: string | null = null;

  connect(url: string, token: string): void {
    // EventSource doesn't support custom headers, so use URL param for auth
    const authUrl = `${url}?token=${encodeURIComponent(token)}`;

    this.eventSource = new EventSource(authUrl);

    this.eventSource.onopen = () => {
      console.log('SSE connected');
      if (this.reconnectTimer) {
        clearTimeout(this.reconnectTimer);
        this.reconnectTimer = null;
      }
    };

    this.eventSource.onerror = (error) => {
      console.error('SSE error:', error);
      this.eventSource?.close();

      // Exponential backoff reconnection
      const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
      this.reconnectTimer = setTimeout(() => {
        this.reconnectAttempts++;
        this.connect(url, token);
      }, delay);
    };

    this.eventSource.onmessage = (event) => {
      this.lastEventId = event.lastEventId;
      try {
        const data = JSON.parse(event.data);
        this.handleMessage(data);
      } catch {
        this.handleMessage(event.data);
      }
    };
  }

  addEventListener(type: string, handler: (data: any) => void): void {
    this.eventSource?.addEventListener(type, (event) => {
      handler(JSON.parse(event.data));
    });
  }

  disconnect(): void {
    this.eventSource?.close();
    this.eventSource = null;
  }
}

// React hook
function useSSE(url: string) {
  const [events, setEvents] = useState<any[]>([]);
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const client = new SSEClient();
    client.connect(url, getToken());

    return () => client.disconnect();
  }, [url]);

  return { events, connected };
}
```

### Event Types

```typescript
// sse-events.ts
interface SSEEvent {
  id: string;
  type: string;
  data: unknown;
  retry?: number;
}

// Server sends:
// id: 123
// event: order-update
// data: {"orderId":"abc","status":"shipped"}
//
// id: 124
// event: notification
// data: {"message":"Your order has shipped"}
//
// id: 125
// event: heartbeat
// data: {}
// retry: 5000

// Client handles different event types
const client = new SSEClient();
client.connect('/api/events', token);

client.addEventListener('order-update', (data) => {
  updateOrderInCache(data.orderId, data);
});

client.addEventListener('notification', (data) => {
  toast.info(data.message);
});

client.addEventListener('heartbeat', () => {
  // Keep connection alive, no action needed
});
```

---

## Real-Time State Sync

### CRDTs (Conflict-free Replicated Data Types)

```typescript
// crdt-example.ts (simplified LWW Register)
interface LWWRegister<T> {
  value: T;
  timestamp: number;
  replicaId: string;
}

class LWWRegister<T> {
  private state: { value: T; timestamp: number; replicaId: string };

  constructor(replicaId: string, initialValue: T) {
    this.state = { value: initialValue, timestamp: Date.now(), replicaId };
  }

  set(value: T): void {
    this.state = { value, timestamp: Date.now(), replicaId: this.state.replicaId };
    this.broadcast();
  }

  merge(other: LWWRegister<T>): void {
    if (other.timestamp > this.state.timestamp) {
      this.state = { value: other.value, timestamp: other.timestamp, replicaId: other.replicaId };
    } else if (other.timestamp === this.state.timestamp && other.replicaId > this.state.replicaId) {
      // Tie-break by replicaId
      this.state = { value: other.value, timestamp: other.timestamp, replicaId: other.replicaId };
    }
  }

  private broadcast(): void {
    // Send to other replicas via WebSocket/SSE
  }
}

// Yjs or Automerge for production CRDTs
// npm install yjs
```

### Operational Transforms

```typescript
// operational-transform.ts (simplified)
interface Operation {
  type: 'insert' | 'delete' | 'retain';
  position: number;
  content?: string;
  length?: number;
}

function transform(op1: Operation, op2: Operation): [Operation, Operation] {
  // If both insert at same position, op1 comes first
  if (op1.type === 'insert' && op2.type === 'insert' && op1.position === op2.position) {
    return [
      { ...op1, position: op1.position },
      { ...op2, position: op2.position + (op1.content?.length || 0) },
    ];
  }

  // If one deletes before the other inserts, adjust position
  if (op1.type === 'delete' && op2.type === 'insert' && op1.position < op2.position) {
    return [
      op1,
      { ...op2, position: op2.position - (op1.length || 1) },
    ];
  }

  return [op1, op2];
}
```

### WebSocket State Machine

```typescript
// ws-state-machine.ts
enum ConnectionState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  RECONNECTING = 'reconnecting',
  AUTHENTICATING = 'authenticating',
  AUTHENTICATED = 'authenticated',
  ERROR = 'error',
}

type ConnectionEvent =
  | { type: 'CONNECT' }
  | { type: 'DISCONNECT' }
  | { type: 'CONNECT_SUCCESS' }
  | { type: 'CONNECT_ERROR'; error: Error }
  | { type: 'AUTH_SUCCESS' }
  | { type: 'AUTH_ERROR'; error: Error }
  | { type: 'RECONNECT' }
  | { type: 'MAX_RECONNECT_EXCEEDED' };

const connectionMachine = {
  initial: ConnectionState.DISCONNECTED,
  states: {
    [ConnectionState.DISCONNECTED]: {
      on: { CONNECT: ConnectionState.CONNECTING },
    },
    [ConnectionState.CONNECTING]: {
      on: {
        CONNECT_SUCCESS: ConnectionState.AUTHENTICATING,
        CONNECT_ERROR: ConnectionState.RECONNECTING,
      },
    },
    [ConnectionState.AUTHENTICATING]: {
      on: {
        AUTH_SUCCESS: ConnectionState.AUTHENTICATED,
        AUTH_ERROR: ConnectionState.ERROR,
      },
    },
    [ConnectionState.AUTHENTICATED]: {
      on: {
        DISCONNECT: ConnectionState.DISCONNECTED,
        CONNECT_ERROR: ConnectionState.RECONNECTING,
      },
    },
    [ConnectionState.RECONNECTING]: {
      on: {
        CONNECT_SUCCESS: ConnectionState.AUTHENTICATING,
        CONNECT_ERROR: ConnectionState.RECONNECTING,
        MAX_RECONNECT_EXCEEDED: ConnectionState.ERROR,
      },
    },
    [ConnectionState.ERROR]: {
      on: { CONNECT: ConnectionState.CONNECTING },
    },
  },
};
```

---

## Summary

| Pattern | Best For | Trade-offs |
|---------|----------|------------|
| **CORS** | Cross-origin API access | Security complexity with credentials |
| **BFF** | Multiple frontends, complex aggregation | Adds infrastructure overhead |
| **Shared Types** | Type safety across stack | Build step complexity |
| **Next.js API Routes** | SSR, simplified auth | Tightly coupled to Next.js |
| **httpOnly Cookies** | Secure auth | CSRF requires mitigation |
| **tRPC** | Full-stack TS, no API spec | TS-only ecosystem |
| **GraphQL** | Flexible queries, real-time | Complexity, caching challenges |
| **REST** | Simplicity, caching, tooling | Over-fetching, versioning |
| **Presigned URLs** | Large file uploads | Two-step upload process |
| **WebSocket** | Real-time bidirectional | Connection management complexity |
| **SSE** | Server→client streaming | No client→server, no reconnection control |
| **CRDTs** | Collaborative editing | Complex, library-dependent |

Choose patterns based on team expertise, frontend framework, and real-time requirements. For most applications, start with REST + BFF, add WebSocket/SSE for real-time features, and consider GraphQL or tRPC when type safety and flexibility are paramount.
