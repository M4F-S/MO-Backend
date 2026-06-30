# API Design Standards

> RESTful, GraphQL, and gRPC API design patterns, versioning strategies, and documentation standards for production backends.

## Table of Contents

1. [RESTful API Design](#1-restful-api-design)
2. [GraphQL](#2-graphql)
3. [gRPC](#3-grpc)
4. [API Versioning](#4-api-versioning)
5. [Rate Limiting & Throttling](#5-rate-limiting--throttling)
6. [Error Handling](#6-error-handling)
7. [Pagination](#7-pagination)
8. [Filtering & Sorting](#8-filtering--sorting)
9. [Caching](#9-caching)
10. [API Documentation](#10-api-documentation)
11. [Webhooks](#11-webhooks)

---

## 1. RESTful API Design

### URL Structure

| Resource | URL | Methods |
|----------|-----|---------|
| Collection | `/api/v1/users` | GET (list), POST (create) |
| Single item | `/api/v1/users/{id}` | GET, PUT, PATCH, DELETE |
| Nested resource | `/api/v1/users/{id}/orders` | GET, POST |
| Action | `/api/v1/users/{id}/activate` | POST (not GET) |

### HTTP Method Usage

| Method | Idempotent | Safe | Use For |
|--------|------------|------|---------|
| GET | Yes | Yes | Read, always |
| POST | No | No | Create, action, complex query |
| PUT | Yes | No | Full update (replace) |
| PATCH | No | No | Partial update |
| DELETE | Yes | No | Remove |
| HEAD | Yes | Yes | Metadata check |
| OPTIONS | Yes | Yes | CORS preflight |

### Resource Naming

- **Plural nouns**: `/users`, `/orders`, `/products` — not `/user`, `/getUser`
- **Lowercase with hyphens**: `/order-items`, `/shipping-addresses`
- **No verbs in URL**: `/users/{id}/activate` not `/activateUser`
- **No trailing slashes**: `/users` not `/users/`
- **No file extensions**: `/users` not `/users.json`

### Request/Response Format

```json
// POST /api/v1/users
// Request
{
  "email": "user@example.com",
  "name": "John Doe",
  "role": "user"
}

// Response (201 Created)
{
  "id": "usr_123456789",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "user",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z",
  "links": {
    "self": "/api/v1/users/usr_123456789",
    "orders": "/api/v1/users/usr_123456789/orders"
  }
}
```

### Status Codes

| Code | When to Use | Response Body |
|------|-------------|---------------|
| 200 | Success (GET, PUT, PATCH) | Resource or list |
| 201 | Created (POST) | New resource + Location header |
| 202 | Accepted (async) | Status URL |
| 204 | No content (DELETE) | Empty |
| 400 | Bad request (validation) | Error details |
| 401 | Unauthorized (missing auth) | Error message |
| 403 | Forbidden (no permission) | Error message |
| 404 | Not found | Error message |
| 409 | Conflict (duplicate) | Error details |
| 422 | Unprocessable (business logic) | Error details |
| 429 | Too many requests | Retry-After header |
| 500 | Server error | Error ID (no details) |
| 503 | Service unavailable | Retry-After header |

### HATEOAS (Optional)

```json
{
  "id": "usr_123",
  "name": "John",
  "links": {
    "self": { "href": "/api/v1/users/usr_123" },
    "orders": { "href": "/api/v1/users/usr_123/orders" },
    "edit": { "href": "/api/v1/users/usr_123", "method": "PATCH" },
    "delete": { "href": "/api/v1/users/usr_123", "method": "DELETE" }
  }
}
```

---

## 2. GraphQL

### When to Use GraphQL

- **Frontend needs flexibility**: Different views need different data shapes
- **Mobile optimization**: Reduce over-fetching for bandwidth-constrained clients
- **Multiple consumers**: Web, mobile, IoT — different data requirements
- **Rapid iteration**: Frontend teams can change queries without backend changes

### When NOT to Use GraphQL

- **Simple CRUD**: REST is simpler, better caching
- **File uploads**: REST multipart is simpler
- **Caching at edge**: GraphQL breaks HTTP caching; needs DataLoader + Redis
- **Team unfamiliarity**: Learning curve, tooling complexity

### Schema Design

```graphql
# schema.graphql
type User {
  id: ID!
  email: String!
  name: String
  role: Role!
  orders: [Order!]! @hasRole(roles: [ADMIN, USER])
  createdAt: DateTime!
}

enum Role {
  ADMIN
  USER
  GUEST
}

type Order {
  id: ID!
  userId: ID!
  user: User!
  items: [OrderItem!]!
  total: Money!
  status: OrderStatus!
}

type OrderItem {
  product: Product!
  quantity: Int!
  price: Money!
}

type Product {
  id: ID!
  name: String!
  price: Money!
  stock: Int!
}

type Money {
  amount: Float!
  currency: String!
}

enum OrderStatus {
  PENDING
  PAID
  SHIPPED
  DELIVERED
  CANCELLED
}

type Query {
  user(id: ID!): User
  users(
    filter: UserFilter
    pagination: PaginationInput
  ): UserConnection!
  me: User!
}

type Mutation {
  createUser(input: CreateUserInput!): User!
  updateUser(id: ID!, input: UpdateUserInput!): User!
  deleteUser(id: ID!): Boolean!
}

input UserFilter {
  role: Role
  emailContains: String
  createdAfter: DateTime
}

input PaginationInput {
  first: Int = 20
  after: String
}

type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type UserEdge {
  node: User!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  endCursor: String
  hasPreviousPage: Boolean!
  startCursor: String
}

# Error handling
interface Error {
  message: String!
  code: String!
  field: [String!]
}
```

### Resolver Pattern with DataLoader

```typescript
// N+1 query prevention
import DataLoader from 'dataloader';

const userLoader = new DataLoader(async (userIds: string[]) => {
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
  });
  return userIds.map(id => users.find(u => u.id === id));
});

const resolvers = {
  Query: {
    user: (_: any, { id }: { id: string }) => userLoader.load(id),
  },
  Order: {
    user: (order: Order) => userLoader.load(order.userId),
  },
};
```

### GraphQL Security

```typescript
// Depth limiting
import { createComplexityLimitRule } from 'graphql-validation-complexity';

const MAX_DEPTH = 7;
const MAX_COMPLEXITY = 1000;

const rules = [
  createComplexityLimitRule(MAX_COMPLEXITY, {
    onComplete: (complexity: number) => {
      console.log('Query complexity:', complexity);
    },
  }),
];

// Query cost analysis
const CostDirective = new GraphQLDirective({
  name: 'cost',
  locations: [DirectiveLocation.FIELD_DEFINITION],
  args: {
    complexity: { type: GraphQLInt },
    multipliers: { type: new GraphQLList(GraphQLString) },
  },
});
```

---

## 3. gRPC

### When to Use gRPC

- **Service-to-service**: Internal microservices (high performance, type safety)
- **Real-time streaming**: Bi-directional streaming, low latency
- **Polyglot systems**: Generate client libraries in 10+ languages
- **Mobile backends**: Protobuf is compact, fast serialization

### When NOT to Use gRPC

- **Public APIs**: Browser support is poor (needs grpc-web proxy)
- **Simple integrations**: REST is simpler, better tooling
- **Debugging**: Binary protocol is hard to inspect

### Protobuf Definition

```protobuf
// api.proto
syntax = "proto3";
package orders;

service OrderService {
  rpc GetOrder(GetOrderRequest) returns (Order);
  rpc CreateOrder(CreateOrderRequest) returns (Order);
  rpc UpdateOrder(UpdateOrderRequest) returns (Order);
  rpc DeleteOrder(DeleteOrderRequest) returns (google.protobuf.Empty);
  rpc StreamOrders(StreamOrdersRequest) returns (stream Order);
}

message GetOrderRequest {
  string id = 1;
}

message CreateOrderRequest {
  string user_id = 1;
  repeated OrderItem items = 2;
  string currency = 3 = "USD";
}

message Order {
  string id = 1;
  string user_id = 2;
  repeated OrderItem items = 3;
  Money total = 4;
  OrderStatus status = 5;
  google.protobuf.Timestamp created_at = 6;
}

message OrderItem {
  string product_id = 1;
  int32 quantity = 2;
  Money price = 3;
}

message Money {
  double amount = 1;
  string currency = 2;
}

enum OrderStatus {
  ORDER_STATUS_UNSPECIFIED = 0;
  PENDING = 1;
  PAID = 2;
  SHIPPED = 3;
  DELIVERED = 4;
  CANCELLED = 5;
}
```

### gRPC Server (Go)

```go
package main

import (
	"context"
	"log"
	"net"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/emptypb"
	pb "orders"
)

type server struct {
	pb.UnimplementedOrderServiceServer
}

func (s *server) GetOrder(ctx context.Context, req *pb.GetOrderRequest) (*pb.Order, error) {
	order, err := db.FindOrder(req.Id)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "order not found: %v", err)
	}
	return orderToProto(order), nil
}

func (s *server) StreamOrders(req *pb.StreamOrdersRequest, stream pb.OrderService_StreamOrdersServer) error {
	orders := db.StreamOrders(req.UserId)
	for order := range orders {
		if err := stream.Send(orderToProto(order)); err != nil {
			return err
		}
	}
	return nil
}

func main() {
	lis, err := net.Listen("tcp", ":50051")
	if err != nil { log.Fatal(err) }
	
	s := grpc.NewServer(
		grpc.UnaryInterceptor(authInterceptor),
		grpc.StreamInterceptor(streamAuthInterceptor),
	)
	pb.RegisterOrderServiceServer(s, &server{})
	
	log.Println("gRPC server on :50051")
	if err := s.Serve(lis); err != nil { log.Fatal(err) }
}
```

---

## 4. API Versioning

### Versioning Strategies

| Strategy | URL | Pros | Cons |
|----------|-----|------|------|
| **URL Path** | `/api/v1/users` | Simple, cache-friendly | URL changes, breaks bookmarks |
| **Header** | `Accept: application/vnd.api+json;version=1` | Clean URLs | Harder to test, less visible |
| **Query Param** | `/api/users?version=1` | Easy to switch | Pollutes URL, caching issues |
| **Content-Type** | `Content-Type: application/vnd.company.v1+json` | Semantic | Complex, non-standard |

**Recommended**: URL path for public APIs, header for internal APIs.

### Version Lifecycle

```
Current: v2 (active development)
Previous: v1 (maintenance, bug fixes only)
Deprecated: v0 (sunset, 6-month warning)
```

**Sunset Policy**:
1. Announce deprecation in API response headers: `Sunset: 2024-12-31T00:00:00Z`
2. Email all API consumers with migration guide
3. Add deprecation warning in docs, SDKs
4. After sunset date: return 410 Gone with migration link

### Backwards Compatibility Rules

- **Never remove fields** — deprecate, return null
- **Never change types** — add new field with new type
- **Never make optional required** — breaking change
- **Never change enum values** — add new, don't rename
- **Never change URL paths** — keep old, redirect if possible
- **Always add new fields as optional** — with sensible defaults

---

## 5. Rate Limiting & Throttling

### Strategies

| Strategy | Algorithm | Use Case |
|----------|-----------|----------|
| **Fixed Window** | Count requests in time window | Simple, but burst at window boundaries |
| **Sliding Window** | Count in rolling window | Smooth, no burst, more memory |
| **Token Bucket** | Tokens added at rate, burst allowed | Flexible, allows bursts |
| **Leaky Bucket** | Constant outflow rate | Smooth output, no burst |

### Implementation (Redis + Token Bucket)

```typescript
import Redis from 'ioredis';

class RateLimiter {
  constructor(private redis: Redis) {}

  async check(key: string, limit: number, window: number): Promise<{ allowed: boolean; remaining: number; reset: number }> {
    const now = Date.now();
    const windowKey = `${key}:${Math.floor(now / (window * 1000))}`;
    
    const pipeline = this.redis.pipeline();
    pipeline.incr(windowKey);
    pipeline.expire(windowKey, window);
    
    const results = await pipeline.exec();
    const count = results[0][1] as number;
    
    return {
      allowed: count <= limit,
      remaining: Math.max(0, limit - count),
      reset: Math.ceil((Math.floor(now / (window * 1000)) + 1) * window * 1000 / 1000),
    };
  }
}

// Middleware
async function rateLimitMiddleware(req: Request, res: Response, next: NextFunction) {
  const key = `rate_limit:${req.user?.id ?? req.ip}`;
  const result = await rateLimiter.check(key, 100, 60); // 100 requests/minute
  
  res.setHeader('X-RateLimit-Limit', 100);
  res.setHeader('X-RateLimit-Remaining', result.remaining);
  res.setHeader('X-RateLimit-Reset', result.reset);
  
  if (!result.allowed) {
    return res.status(429).json({ error: 'Too many requests', retryAfter: result.reset });
  }
  next();
}
```

### Rate Limit Headers

```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705312800
X-RateLimit-Window: 60
```

---

## 6. Error Handling

### Error Response Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format",
        "code": "INVALID_EMAIL"
      },
      {
        "field": "password",
        "message": "Password must be at least 8 characters",
        "code": "PASSWORD_TOO_SHORT"
      }
    ],
    "links": {
      "documentation": "https://docs.example.com/errors/VALIDATION_ERROR"
    }
  }
}
```

### Error Codes

| Code | HTTP | Description |
|------|------|-------------|
| `INVALID_REQUEST` | 400 | Malformed request |
| `VALIDATION_ERROR` | 400 | Validation failed |
| `UNAUTHORIZED` | 401 | Missing/invalid credentials |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Resource already exists |
| `UNPROCESSABLE` | 422 | Business logic error |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Server error (don't expose details) |
| `SERVICE_UNAVAILABLE` | 503 | Downstream service unavailable |

### Error Handling in Code

```typescript
// Domain errors — business logic
class DomainError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode: number = 400
  ) {
    super(message);
  }
}

class NotFoundError extends DomainError {
  constructor(resource: string) {
    super(`${resource} not found`, 'NOT_FOUND', 404);
  }
}

class ValidationError extends DomainError {
  constructor(public details: ValidationDetail[]) {
    super('Validation failed', 'VALIDATION_ERROR', 400);
  }
}

// Global error handler
app.use((error: Error, req: Request, res: Response, next: NextFunction) => {
  const requestId = req.headers['x-request-id'] || crypto.randomUUID();
  
  if (error instanceof DomainError) {
    return res.status(error.statusCode).json({
      error: {
        code: error.code,
        message: error.message,
        requestId,
        details: error instanceof ValidationError ? error.details : undefined,
      },
    });
  }
  
  // Log full stack trace for 500s
  console.error('Unhandled error:', error);
  
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
      requestId,
    },
  });
});
```

---

## 7. Pagination

### Offset Pagination

```http
GET /api/v1/users?offset=20&limit=20
```

```json
{
  "data": [...],
  "pagination": {
    "offset": 20,
    "limit": 20,
    "total": 150,
    "hasMore": true
  }
}
```

**Pros**: Simple, skip to any page
**Cons**: Slow at large offsets (`OFFSET 1000000`), inconsistent during writes

### Cursor Pagination (Recommended)

```http
GET /api/v1/users?cursor=eyJpZCI6MTIzfQ&limit=20
```

```json
{
  "data": [...],
  "pagination": {
    "nextCursor": "eyJpZCI6MTQ1fQ",
    "previousCursor": "eyJpZCI6MTAwfQ",
    "hasNext": true,
    "hasPrevious": true
  }
}
```

**Pros**: Consistent during writes, fast at any scale, no total count needed
**Cons**: Can't jump to arbitrary page, complex for simple use cases

### Implementation (Cursor)

```typescript
async function paginateWithCursor<T>(
  query: Knex.QueryBuilder,
  cursor: string | null,
  limit: number = 20,
  sortField: string = 'id'
): Promise<CursorPaginatedResult<T>> {
  const decodedCursor = cursor ? JSON.parse(Buffer.from(cursor, 'base64').toString()) : null;
  
  if (decodedCursor) {
    query.where(sortField, '>', decodedCursor[sortField]);
  }
  
  const items = await query.orderBy(sortField, 'asc').limit(limit + 1);
  const hasNext = items.length > limit;
  const results = items.slice(0, limit);
  
  return {
    data: results,
    pagination: {
      nextCursor: hasNext ? Buffer.from(JSON.stringify({ [sortField]: results[results.length - 1][sortField] })).toString('base64') : null,
      previousCursor: null, // Calculate if needed
      hasNext,
      hasPrevious: !!decodedCursor,
    },
  };
}
```

---

## 8. Filtering & Sorting

### Filtering Syntax

```http
GET /api/v1/users?filter[role]=admin&filter[createdAt][gte]=2024-01-01
GET /api/v1/products?filter[price][gte]=10&filter[price][lte]=100&filter[category]=electronics
GET /api/v1/orders?filter[status]=pending,paid&filter[total][gt]=100
```

Operators: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `in`, `nin`, `contains`, `startsWith`, `endsWith`

### Sorting Syntax

```http
GET /api/v1/users?sort=-createdAt,name        # - = descending
GET /api/v1/products?sort=price,-popularity
```

### Implementation

```typescript
function buildFilter(query: Knex.QueryBuilder, filters: Record<string, any>): void {
  for (const [field, condition] of Object.entries(filters)) {
    if (typeof condition === 'string') {
      query.where(field, condition);
    } else if (typeof condition === 'object') {
      for (const [op, value] of Object.entries(condition)) {
        switch (op) {
          case 'eq': query.where(field, value); break;
          case 'neq': query.whereNot(field, value); break;
          case 'gt': query.where(field, '>', value); break;
          case 'gte': query.where(field, '>=', value); break;
          case 'lt': query.where(field, '<', value); break;
          case 'lte': query.where(field, '<=', value); break;
          case 'in': query.whereIn(field, Array.isArray(value) ? value : [value]); break;
          case 'contains': query.where(field, 'like', `%${value}%`); break;
          case 'startsWith': query.where(field, 'like', `${value}%`); break;
        }
      }
    }
  }
}

function buildSort(query: Knex.QueryBuilder, sort: string): void {
  const fields = sort.split(',');
  for (const field of fields) {
    const isDesc = field.startsWith('-');
    const column = isDesc ? field.slice(1) : field;
    query.orderBy(column, isDesc ? 'desc' : 'asc');
  }
}
```

---

## 9. Caching

### Cache Strategies

| Strategy | When | How |
|----------|------|-----|
| **Cache-Aside** | Read-heavy, cache misses OK | App checks cache, falls back to DB |
| **Write-Through** | Read-heavy, consistency critical | Write to cache + DB simultaneously |
| **Write-Behind** | Write-heavy, eventual OK | Write to cache, async flush to DB |
| **Read-Through** | Simple lookups | Cache loads from DB on miss |

### Cache-Aside Example

```typescript
class ProductService {
  async getProduct(id: string): Promise<Product> {
    const cacheKey = `product:${id}`;
    
    // 1. Check cache
    const cached = await redis.get(cacheKey);
    if (cached) return JSON.parse(cached);
    
    // 2. Load from DB
    const product = await db.products.findById(id);
    if (!product) throw new NotFoundError('Product');
    
    // 3. Write to cache (TTL based on data volatility)
    await redis.setex(cacheKey, 300, JSON.stringify(product)); // 5 min
    
    return product;
  }

  async updateProduct(id: string, data: UpdateProductDto): Promise<Product> {
    const product = await db.products.update(id, data);
    
    // Invalidate cache (not update — race condition risk)
    await redis.del(`product:${id}`);
    await redis.del('products:list'); // Invalidate list caches too
    
    return product;
  }
}
```

### Cache Headers

```http
HTTP/1.1 200 OK
Cache-Control: public, max-age=60, stale-while-revalidate=300
ETag: "abc123"
Last-Modified: Mon, 15 Jan 2024 10:00:00 GMT
Vary: Accept-Encoding, Authorization
```

---

## 10. API Documentation

### OpenAPI 3.1 Specification

```yaml
openapi: 3.1.0
info:
  title: MO-Backend API
  version: 1.0.0
  description: Production-grade backend API
  contact:
    name: API Support
    email: api@example.com
  license:
    name: MIT

servers:
  - url: https://api.example.com/v1
    description: Production
  - url: https://staging-api.example.com/v1
    description: Staging

paths:
  /users:
    get:
      summary: List users
      operationId: listUsers
      tags: [Users]
      parameters:
        - name: limit
          in: query
          schema: { type: integer, default: 20, maximum: 100 }
        - name: cursor
          in: query
          schema: { type: string }
      responses:
        '200':
          description: List of users
          content:
            application/json:
              schema: { $ref: '#/components/schemas/UserList' }
    post:
      summary: Create user
      operationId: createUser
      tags: [Users]
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/CreateUserInput' }
      responses:
        '201':
          description: Created user
          content:
            application/json:
              schema: { $ref: '#/components/schemas/User' }

components:
  schemas:
    User:
      type: object
      required: [id, email, createdAt]
      properties:
        id: { type: string, format: uuid }
        email: { type: string, format: email }
        name: { type: string }
        role: { type: string, enum: [admin, user, guest] }
        createdAt: { type: string, format: date-time }

securitySchemes:
  bearerAuth:
    type: http
    scheme: bearer
    bearerFormat: JWT

security:
  - bearerAuth: []
```

### Documentation Tools

| Tool | Best For | Output |
|------|----------|--------|
| **Swagger UI** | Interactive API docs | Web UI |
| **ReDoc** | Clean, responsive docs | Web UI |
| **Postman** | Collections, testing | App + Web |
| **Insomnia** | Open source alternative | App |
| **ReadMe** | Developer portals | Hosted docs |
| **Stoplight** | Design-first workflows | Studio + Docs |

---

## 11. Webhooks

### Webhook Design

```http
POST /webhooks/orders
Content-Type: application/json
X-Webhook-Signature: sha256=abc123...
X-Webhook-Id: wh_123456
X-Webhook-Timestamp: 1705312800
X-Webhook-Event: order.created

{
  "event": "order.created",
  "timestamp": "2024-01-15T10:00:00Z",
  "webhookId": "wh_123456",
  "data": {
    "orderId": "ord_123",
    "userId": "usr_456",
    "total": { "amount": 99.99, "currency": "USD" },
    "items": [...]
  }
}
```

### Webhook Security

```typescript
import crypto from 'crypto';

function verifyWebhook(payload: string, signature: string, secret: string): boolean {
  const expected = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(`sha256=${expected}`)
  );
}

// Replay prevention (idempotency)
async function processWebhook(webhookId: string, payload: any): Promise<void> {
  const lock = await redis.set(`webhook:${webhookId}`, 'processing', 'NX', 'EX', 60);
  if (!lock) {
    console.log(`Webhook ${webhookId} already processed`);
    return;
  }
  
  try {
    await handleEvent(payload);
    await redis.set(`webhook:${webhookId}`, 'completed', 'EX', 86400);
  } catch (error) {
    await redis.del(`webhook:${webhookId}`); // Release lock for retry
    throw error;
  }
}
```

### Webhook Retry Policy

| Attempt | Delay | Strategy |
|---------|-------|----------|
| 1 | 0s | Immediate |
| 2 | 5s | Linear |
| 3 | 25s | Exponential |
| 4 | 2m | Exponential |
| 5 | 10m | Exponential |
| 6+ | 1h | Fixed (max 24h) |

**Webhook Best Practices**:
- **Idempotency**: Same webhook ID → same result
- **Signature verification**: HMAC-SHA256 with timestamp tolerance
- **Timeout**: 5-10s, don't block sender
- **Acknowledge quickly**: Return 2xx immediately, process async
- **Event types**: Include in payload and header
- **Retry with backoff**: Exponential, with jitter
- **Dead letter**: After 24h, send to DLQ for manual review
- **Signature version**: `v1=sha256=...` for future-proofing

## References

- [REST API Design Best Practices](https://docs.microsoft.com/en-us/azure/architecture/best-practices/api-design)
- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)
- [gRPC Best Practices](https://grpc.io/docs/guides/)
- [OpenAPI Specification](https://spec.openapis.org/oas/v3.1.0.html)
- [Stripe API Design](https://stripe.com/docs/api)
- [GitHub API v3](https://docs.github.com/en/rest)
- [Zalando RESTful Guidelines](https://opensource.zalando.com/restful-api-guidelines/)
- [Microsoft API Guidelines](https://github.com/microsoft/api-guidelines)
