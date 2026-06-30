# Architecture Reference

> System design patterns, scalability strategies, and architectural decision frameworks for production backends.

## Table of Contents

1. [Monolith vs Microservices](#1-monolith-vs-microservices)
2. [Domain-Driven Design (DDD)](#2-domain-driven-design-ddd)
3. [Event-Driven Architecture](#3-event-driven-architecture)
4. [CQRS & Event Sourcing](#4-cqrs--event-sourcing)
5. [Layered Architecture](#5-layered-architecture)
6. [Hexagonal Architecture](#6-hexagonal-architecture)
7. [Serverless & Edge](#7-serverless--edge)
8. [Scalability Patterns](#8-scalability-patterns)
9. [Data Consistency](#9-data-consistency)
10. [Resilience Patterns](#10-resilience-patterns)

---

## 1. Monolith vs Microservices

### When to Choose Monolith

- **Team size < 10**: Single codebase reduces cognitive load
- **Time to market**: Rapid prototyping, MVPs, early-stage startups
- **Complex transactions**: Heavy ACID requirements across domains
- **Operational simplicity**: Small ops team, limited infrastructure budget
- **Tight coupling**: Domains are naturally interdependent

### Monolith Best Practices

```
┌─────────────────────────────────────┐
│           Monolith App               │
├─────────────────────────────────────┤
│  API Layer  │  Business Logic  │  Data  │
│  (REST/gRPC)│   (Services)     │ Layer  │
├─────────────────────────────────────┤
│  Shared Kernel (utils, types)       │
└─────────────────────────────────────┘
```

- **Modular monolith**: Internal modules with clear boundaries, prepare for future extraction
- **Vertical slicing**: Features cut through all layers (API → logic → DB)
- **Database per module**: Logical separation within same physical DB (schema separation)
- **API gateway**: Even monoliths benefit from a thin gateway for auth, rate limiting
- **Background jobs**: Extract heavy processing to async workers (Redis queue, Celery, BullMQ)

### When to Choose Microservices

- **Team size > 20**: Conway's law — teams own services
- **Independent deployment**: Different release cadences per domain
- **Technology diversity**: Different languages for different problems (ML in Python, API in Go)
- **Scale independently**: One service needs 10x resources, others don't
- **Organizational autonomy**: Different teams, different priorities

### Microservices Best Practices

```
┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
│  Auth   │  │ Orders  │  │Catalog  │  │Payments │
│ Service │  │ Service │  │ Service │  │ Service │
└────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘
     │            │            │            │
     └────────────┴────────────┴────────────┘
                    │
            ┌───────┴───────┐
            │  Event Bus     │
            │ (Kafka/NATS)   │
            └───────────────┘
```

- **Service boundaries**: Align with bounded contexts (DDD), not CRUD entities
- **Database per service**: Never share databases; use APIs or events for cross-service data
- **Async communication**: Prefer events over synchronous calls; use sagas for transactions
- **API gateway**: Single entry point, handles auth, rate limiting, routing, BFF
- **Service discovery**: Consul, etcd, or Kubernetes DNS for inter-service communication
- **Circuit breakers**: Prevent cascade failures (see Resilience Patterns)
- **Distributed tracing**: Jaeger, Zipkin to trace requests across services
- **Backwards compatibility**: Version your APIs; never break existing consumers

### The Hybrid Approach: Modular Monolith → Microservices

Start with a modular monolith, extract services when:

1. One module changes 10x more than others
2. One module needs 10x more resources
3. One team wants different tech stack
4. One module needs independent scaling

Extract sequence:
1. **API extraction**: Move API layer to gateway first
2. **Database separation**: Create separate schema, sync via CDC (Debezium)
3. **Code extraction**: Move module to new service, keep DB sync
4. **Event migration**: Switch from sync DB to async events
5. **Cleanup**: Remove old code, old DB references

---

## 2. Domain-Driven Design (DDD)

### Core Concepts

| Concept | Definition | Example |
|---------|-----------|---------|
| **Bounded Context** | Boundary where domain model applies | `Order` in Order context ≠ `Order` in Shipping context |
| **Aggregate** | Cluster of domain objects with root entity | `Order` aggregate: Order + OrderLine + Address |
| **Entity** | Object with identity that persists over time | `User`, `Order`, `Product` |
| **Value Object** | Immutable object defined by attributes, no identity | `Money`, `Address`, `Email` |
| **Domain Event** | Something that happened in the domain | `OrderPlaced`, `PaymentReceived` |
| **Repository** | Abstract collection of aggregates | `OrderRepository` |
| **Domain Service** | Operations that don't belong to an entity | `PricingService`, `FraudDetectionService` |

### Project Structure (DDD + Hexagonal)

```
src/
├── domain/                    # Domain layer (pure, no dependencies)
│   ├── order/
│   │   ├── aggregate.ts       # Order aggregate root
│   │   ├── entity.ts          # OrderLine entity
│   │   ├── value-object.ts    # Money, Address
│   │   ├── event.ts           # OrderPlaced, OrderCancelled
│   │   ├── repository.ts      # Interface (port)
│   │   └── service.ts         # Domain service
│   └── user/
│       ├── aggregate.ts
│       └── ...
├── application/               # Application layer (use cases)
│   ├── order/
│   │   ├── commands/          # PlaceOrder, CancelOrder
│   │   ├── queries/           # GetOrder, ListOrders
│   │   └── handlers.ts        # Command/query handlers
├── infrastructure/            # Infrastructure layer (adapters)
│   ├── persistence/
│   │   ├── prisma/            # Prisma implementation of repositories
│   │   └── redis/             # Cache implementation
│   ├── messaging/
│   │   └── kafka/             # Event publisher implementation
│   └── web/
│       └── controllers/       # HTTP controllers
└── shared/                    # Shared kernel (types, utils)
```

### Aggregates & Transaction Boundaries

```typescript
// Order aggregate — all changes go through aggregate root
class Order {
  private id: OrderId;
  private lines: OrderLine[];
  private status: OrderStatus;
  private total: Money;

  // Only way to add a line — ensures invariants
  addLine(product: Product, quantity: number): void {
    if (this.status !== OrderStatus.DRAFT) {
      throw new DomainError('Cannot modify submitted order');
    }
    const line = new OrderLine(product.id, product.price, quantity);
    this.lines.push(line);
    this.recalculateTotal();
  }

  submit(): void {
    if (this.lines.length === 0) throw new DomainError('Empty order');
    if (this.total.amount <= 0) throw new DomainError('Invalid total');
    this.status = OrderStatus.SUBMITTED;
    this.recordEvent(new OrderSubmitted(this.id, this.total));
  }

  // Load from DB — bypasses business rules, for reconstruction only
  static reconstitute(id: OrderId, lines: OrderLine[], status: OrderStatus): Order {
    const order = new Order();
    order.id = id;
    order.lines = lines;
    order.status = status;
    return order;
  }
}
```

### Anti-Corruption Layer (ACL)

When integrating with external systems or legacy code, use an ACL to prevent their model from leaking into your domain:

```typescript
// External system (legacy) — don't let this into your domain
interface LegacyCustomer {
  cust_id: number;
  cust_name: string;
  cust_addr: string;
}

// ACL: Translator
class LegacyCustomerTranslator {
  toDomain(legacy: LegacyCustomer): Customer {
    return new Customer(
      new CustomerId(legacy.cust_id.toString()),
      new Name(legacy.cust_name),
      this.parseAddress(legacy.cust_addr)
    );
  }

  private parseAddress(addr: string): Address {
    // Handle legacy format: "123 Main St, City, ST 12345"
    const parts = addr.split(', ');
    return new Address(parts[0], parts[1], parts[2].split(' ')[0], parts[2].split(' ')[1]);
  }
}

// Repository uses ACL to keep domain pure
class CustomerRepository implements ICustomerRepository {
  constructor(
    private legacyApi: LegacyCustomerApi,
    private translator: LegacyCustomerTranslator
  ) {}

  async findById(id: CustomerId): Promise<Customer | null> {
    const legacy = await this.legacyApi.getCustomer(id.value);
    return legacy ? this.translator.toDomain(legacy) : null;
  }
}
```

---

## 3. Event-Driven Architecture

### Event Patterns

| Pattern | Use Case | Implementation |
|---------|----------|---------------|
| **Event Notification** | Notify other services something happened | Simple event: `OrderPlaced` → send email |
| **Event-Carried State Transfer** | Share full state for replication | Event includes full `Order` payload → sync read model |
| **Event Sourcing** | State as sequence of events | Store events, reconstruct state by replaying |
| **CQRS** | Separate read/write models | Commands write to event store, queries read from projections |
| **Saga** | Distributed transactions | Choreography (events) or orchestration (coordinator) |

### Event Bus Technologies

| Technology | Best For | Trade-offs |
|------------|----------|------------|
| **Kafka** | High throughput, durability, replay | Operational complexity, latency ~10ms |
| **NATS** | Simplicity, speed, cloud-native | Less ecosystem, no persistence by default |
| **Redis Streams** | In-memory, low latency | Data loss risk, limited retention |
| **RabbitMQ** | Complex routing, enterprise | Slower than Kafka, single point of failure |
| **AWS SNS/SQS** | AWS-native, managed | Vendor lock-in, limited features |
| **Google Pub/Sub** | GCP-native, global | Vendor lock-in, cost at scale |

### Event Schema Evolution

Use schema registry (Confluent Schema Registry, AWS Glue) with:

- **Backward compatibility**: New consumers read old events
- **Forward compatibility**: Old consumers read new events
- **Full compatibility**: Both directions

Best practices:
- **Never rename fields** — add new, deprecate old
- **Never change types** — add new field with new type
- **Use optional fields** — `required` prevents evolution
- **Version in schema** — ` "version": "1.0.0"` in schema metadata
- **Event type in payload** — `{"type": "OrderPlaced", "version": "1", ...}`

### Saga Pattern for Distributed Transactions

**Choreography Saga**: Services react to events, no central coordinator

```
Order Service        Payment Service       Inventory Service
     │                      │                       │
     │── OrderPlaced ──────>│                       │
     │                      │── PaymentCompleted ──>│
     │                      │                       │── InventoryReserved
     │<─────────────────────│                       │
```

- Pros: Loose coupling, no single point of failure
- Cons: Hard to understand flow, circular dependencies risk

**Orchestration Saga**: Central coordinator manages steps

```
         ┌──────────────┐
         │   Saga Orchestrator  │
         └──────┬───────┘
                │
     ┌──────────┼──────────┐
     │          │          │
Order │      Payment   Inventory
Svc   │        Svc       Svc
```

- Pros: Clear flow, centralized error handling, easy to debug
- Cons: Orchestrator is a single point of failure, tighter coupling

Use choreography for simple flows (2-3 services), orchestration for complex flows (5+ steps).

---

## 4. CQRS & Event Sourcing

### CQRS (Command Query Responsibility Segregation)

Separate read and write models:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Command   │────>│  Write Model │────>│ Event Store │
│  (Create,   │     │ (Aggregate)  │     │ (Kafka/DB)  │
│   Update)   │     └─────────────┘     └──────┬──────┘
└─────────────┘                                │
                                              │ Events
┌─────────────┐     ┌─────────────┐     ┌─────┴─────┐
│    Query    │<────│  Read Model │<────│ Projection │
│   (Read)    │     │  (Denormalized)│    │  (Worker)  │
└─────────────┘     └─────────────┘     └─────────────┘
```

**When to use CQRS**:
- Read and write patterns are very different (e.g., complex reads, simple writes)
- Need to scale reads and writes independently
- Event sourcing is already in use
- Read model needs to be denormalized for performance

**When NOT to use CQRS**:
- Simple CRUD application
- Strong consistency required for reads (eventual consistency only)
- Team not experienced with distributed systems

### Event Sourcing

Store state as a sequence of events:

```typescript
interface Event {
  type: string;
  aggregateId: string;
  version: number;
  timestamp: Date;
  payload: Record<string, any>;
}

// Event store
class EventStore {
  async append(events: Event[], expectedVersion: number): Promise<void>;
  async getEvents(aggregateId: string): Promise<Event[]>;
  async getEventsByType(type: string): Promise<Event[]>;
}

// Reconstruct aggregate
class Order {
  static async load(id: OrderId, store: EventStore): Promise<Order> {
    const events = await store.getEvents(id.value);
    const order = new Order();
    for (const event of events) {
      order.apply(event);  // No validation, just state change
    }
    return order;
  }

  private apply(event: Event): void {
    switch (event.type) {
      case 'OrderCreated':
        this.id = new OrderId(event.aggregateId);
        this.status = OrderStatus.DRAFT;
        break;
      case 'OrderLineAdded':
        this.lines.push(new OrderLine(event.payload.productId, event.payload.price, event.payload.quantity));
        break;
      case 'OrderSubmitted':
        this.status = OrderStatus.SUBMITTED;
        break;
    }
  }
}
```

**Event Sourcing Benefits**:
- Complete audit log of all changes
- Temporal queries — "what was the state at time T?"
- Easy to add new read models (replay events)
- Debugging — replay exact sequence to reproduce bugs

**Event Sourcing Challenges**:
- Event schema evolution is critical and complex
- Snapshots needed for performance (replaying 100k events is slow)
- Requires strong understanding of DDD
- Projections can lag (eventual consistency)

---

## 5. Layered Architecture

Classic layered architecture (onion architecture):

```
┌─────────────────────────────────────┐
│         Presentation Layer           │  ← Controllers, DTOs, API docs
│    (HTTP / gRPC / GraphQL / CLI)   │
├─────────────────────────────────────┤
│          Application Layer          │  ← Use cases, command handlers,
│    (Services, Commands, Queries)    │     transaction boundaries
├─────────────────────────────────────┤
│           Domain Layer              │  ← Entities, value objects,
│    (Aggregates, Services, Events)   │     domain events, repository interfaces
├─────────────────────────────────────┤
│        Infrastructure Layer         │  ← DB, HTTP clients, message queues,
│    (Persistence, External APIs)      │     external services
└─────────────────────────────────────┘
```

**Dependency Rule**: Dependencies point inward. Infrastructure depends on Domain, never the reverse.

```typescript
// Domain layer — pure, no external dependencies
interface IOrderRepository {
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
}

// Application layer — orchestrates domain objects
class PlaceOrderHandler {
  constructor(
    private orderRepository: IOrderRepository,
    private eventBus: IEventBus,
    private pricingService: PricingService
  ) {}

  async execute(command: PlaceOrderCommand): Promise<void> {
    const order = Order.create(command.customerId, command.lines);
    order.calculateTotal(this.pricingService);
    await this.orderRepository.save(order);
    await this.eventBus.publish(order.domainEvents);
  }
}

// Infrastructure layer — implements domain interfaces
class PrismaOrderRepository implements IOrderRepository {
  constructor(private prisma: PrismaClient) {}

  async findById(id: OrderId): Promise<Order | null> {
    const data = await this.prisma.order.findUnique({ where: { id: id.value } });
    return data ? OrderMapper.toDomain(data) : null;
  }

  async save(order: Order): Promise<void> {
    const data = OrderMapper.toPersistence(order);
    await this.prisma.order.upsert({
      where: { id: data.id },
      create: data,
      update: data,
    });
  }
}
```

---

## 6. Hexagonal Architecture (Ports & Adapters)

Hexagonal architecture inverts dependencies — the domain defines interfaces (ports), infrastructure provides implementations (adapters):

```
         ┌─────────────────────────────────────┐
         │          ┌─────────┐              │
         │          │  Domain │              │
         │          │  Core   │              │
         │          └────┬────┘              │
         │    ┌─────────┼─────────┐         │
         │    │         │         │         │
         │ ┌──┴──┐   ┌──┴──┐   ┌──┴──┐      │
         │ │Port 1│   │Port 2│   │Port 3│     │
         │ └──┬──┘   └──┬──┘   └──┬──┘      │
         │    │         │         │         │
         │ ┌──┴──┐   ┌──┴──┐   ┌──┴──┐      │
         │ │Adptr│   │Adptr│   │Adptr│      │
         │ │  1  │   │  2  │   │  3  │      │
         │ └──┬──┘   └──┬──┘   └──┬──┘      │
         │    │         │         │         │
         └────┼─────────┼─────────┼─────────┘
              │         │         │
         ┌────┘         │         └────┐
         │              │              │
    ┌────┴────┐   ┌────┴────┐   ┌────┴────┐
    │  HTTP   │   │  Kafka  │   │  Prisma  │
    │Controller│   │Consumer │   │  Client  │
    └─────────┘   └─────────┘   └─────────┘
```

**Ports** (interfaces defined in domain):
```typescript
// Driven port (domain needs this)
interface IOrderRepository {
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
}

interface IEventPublisher {
  publish(event: DomainEvent): Promise<void>;
}

// Driving port (domain exposes this)
interface IPlaceOrderUseCase {
  execute(command: PlaceOrderCommand): Promise<void>;
}
```

**Adapters** (implementations in infrastructure):
```typescript
// Driven adapter
class PrismaOrderRepository implements IOrderRepository {
  // Uses Prisma, but domain doesn't know about Prisma
}

class KafkaEventPublisher implements IEventPublisher {
  // Uses Kafka, but domain doesn't know about Kafka
}

// Driving adapter
class HttpOrderController {
  // Receives HTTP requests, calls domain use case
  constructor(private useCase: IPlaceOrderUseCase) {}

  @Post('/orders')
  async placeOrder(@Body() dto: PlaceOrderDto) {
    await this.useCase.execute(dto.toCommand());
  }
}
```

---

## 7. Serverless & Edge

### Serverless Functions (FaaS)

| Provider | Service | Cold Start | Max Runtime | Best For |
|----------|---------|------------|-------------|----------|
| AWS | Lambda | 100-1000ms | 15 min | Event processing, APIs |
| Google | Cloud Functions | 200-2000ms | 60 min | GCP integrations |
| Azure | Functions | 200-1000ms | 10 min | Microsoft ecosystem |
| Cloudflare | Workers | 0-50ms | 30 sec | Edge, ultra-low latency |
| Vercel | Functions | 0-500ms | 5 min | Next.js, frontend APIs |

### Edge Architecture

```
User ──> CDN Edge (Cloudflare) ──> Origin (API)
              │
              ├── Cache static assets
              ├── Rate limit
              ├── Auth (JWT verification)
              ├── A/B routing
              └── Serverless function (lightweight)
```

**Edge Best Practices**:
- **Stateless**: No session affinity, store state in KV (Redis, Cloudflare KV)
- **Lightweight**: < 50MB bundle, < 100ms execution
- **No long-running**: Use queues for async work
- **Cache aggressively**: Cache at edge for 1s-1h depending on data volatility
- **Environment injection**: Use env vars, not files
- **Local dev**: Use `wrangler dev` (Cloudflare), `sam local` (AWS)

### Hono + Cloudflare Workers Example

```typescript
// Edge API — runs in 200+ data centers globally
import { Hono } from 'hono';
import { jwt } from 'hono/jwt';
import { cors } from 'hono/cors';
import { rateLimit } from './middleware/rate-limit';

const app = new Hono();

app.use(cors({ origin: ['https://myapp.com'] }));
app.use(rateLimit({ requests: 100, window: '1m' }));
app.use('/api/*', jwt({ secret: c.env.JWT_SECRET }));

app.get('/api/products/:id', async (c) => {
  const cache = c.env.CACHE;
  const cacheKey = `product:${c.req.param('id')}`;

  // Check KV cache first (edge, < 1ms)
  const cached = await cache.get(cacheKey);
  if (cached) return c.json(JSON.parse(cached));

  // Fallback to D1 database (SQLite, ~5ms)
  const product = await c.env.DB
    .prepare('SELECT * FROM products WHERE id = ?')
    .bind(c.req.param('id'))
    .first();

  if (!product) return c.json({ error: 'Not found' }, 404);

  // Cache for 5 minutes at edge
  await cache.put(cacheKey, JSON.stringify(product), { expirationTtl: 300 });

  return c.json(product);
});

export default app;
```

---

## 8. Scalability Patterns

### Horizontal Scaling Strategies

| Strategy | When | How |
|----------|------|-----|
| **Load Balancing** | Single server overloaded | NGINX, HAProxy, ALB — round-robin, least connections |
| **Database Sharding** | Single DB can't handle writes | Shard by user_id, geo, or tenant |
| **Read Replicas** | Read-heavy workload | Route reads to replicas, writes to primary |
| **Caching** | Repeated expensive queries | Redis, CDN, application-level caching |
| **CDN** | Static assets, API responses | Cloudflare, CloudFront — cache at edge |
| **Async Processing** | Heavy operations block API | Queue jobs, process in background |
| **Auto-scaling** | Variable traffic | K8s HPA, AWS ASG based on CPU/memory |
| **Rate Limiting** | Protect from abuse | Token bucket, leaky bucket per user/IP |

### Database Sharding Example

```typescript
// Consistent hashing for shard routing
function getShard(userId: string, shardCount: number): number {
  const hash = crypto.createHash('md5').update(userId).digest('hex');
  return parseInt(hash.substring(0, 8), 16) % shardCount;
}

// Shard configuration
const shards = [
  { id: 0, host: 'shard-0.db', readHosts: ['shard-0-replica.db'] },
  { id: 1, host: 'shard-1.db', readHosts: ['shard-1-replica.db'] },
  { id: 2, host: 'shard-2.db', readHosts: ['shard-2-replica.db'] },
];

class ShardedUserRepository {
  async findById(userId: string): Promise<User | null> {
    const shard = getShard(userId, shards.length);
    const db = getConnection(shards[shard].host);
    return db.query('SELECT * FROM users WHERE id = $1', [userId]);
  }

  async findByEmail(email: string): Promise<User | null> {
    // Email lookup table — all emails in one shard or use secondary index
    const lookupDb = getConnection(shards[0].host); // Central lookup
    const userId = await lookupDb.query('SELECT user_id FROM email_lookup WHERE email = $1', [email]);
    if (!userId) return null;
    return this.findById(userId);
  }
}
```

---

## 9. Data Consistency

### CAP Theorem Trade-offs

| System | Consistency | Availability | Partition Tolerance | Use Case |
|--------|-------------|--------------|----------------------|----------|
| PostgreSQL | Strong | Yes | No (single node) | Transactions, ACID |
| MongoDB (default) | Eventual | Yes | Yes | Documents, flexibility |
| Cassandra | Eventual | Yes | Yes | High write throughput |
| Redis | Strong (single) | Yes | No | Cache, sessions |
| etcd | Strong | Yes | Yes | Config, service discovery |
| Kafka | Configurable | Yes | Yes | Event streaming |

### Consistency Patterns

**Strong Consistency**:
- Single database with ACID transactions
- Distributed transactions (2PC, 3PC) — complex, slow
- Paxos/Raft consensus (etcd, Zookeeper)

**Eventual Consistency**:
- Event sourcing + projections
- CQRS with read model lag
- Database replication lag
- Cache invalidation

**Optimistic Locking**:
```typescript
async function updateBalance(userId: string, amount: number, expectedVersion: number): Promise<void> {
  const result = await db.query(
    'UPDATE accounts SET balance = balance + $1, version = version + 1 WHERE id = $2 AND version = $3',
    [amount, userId, expectedVersion]
  );
  if (result.rowCount === 0) {
    throw new OptimisticLockError('Balance changed, retry');
  }
}
```

**Saga Pattern** (see Event-Driven Architecture):
- Compensating transactions for rollback
- Eventual consistency across services
- Order: Reserve → Payment → Ship → Deliver
- Compensation: Refund → Cancel → Unreserve

---

## 10. Resilience Patterns

### Circuit Breaker

Prevent cascade failures by stopping requests to failing services:

```typescript
interface CircuitBreakerState {
  status: 'closed' | 'open' | 'half-open';
  failures: number;
  lastFailure: Date;
  successThreshold: number;
  failureThreshold: number;
  timeout: number; // ms
}

class CircuitBreaker {
  private state: CircuitBreakerState = {
    status: 'closed',
    failures: 0,
    lastFailure: new Date(0),
    successThreshold: 3,
    failureThreshold: 5,
    timeout: 30000,
  };

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state.status === 'open') {
      if (Date.now() - this.state.lastFailure.getTime() < this.state.timeout) {
        throw new CircuitBreakerOpenError('Circuit breaker is open');
      }
      this.state.status = 'half-open';
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    if (this.state.status === 'half-open') {
      this.state.successThreshold--;
      if (this.state.successThreshold <= 0) {
        this.state.status = 'closed';
        this.state.failures = 0;
      }
    }
  }

  private onFailure(): void {
    this.state.failures++;
    this.state.lastFailure = new Date();
    if (this.state.failures >= this.state.failureThreshold) {
      this.state.status = 'open';
    }
  }
}
```

### Bulkhead

Isolate failures to prevent resource exhaustion:

```typescript
// Separate connection pools per service
const pools = {
  orders: new Pool({ max: 20 }),
  payments: new Pool({ max: 10 }), // Smaller pool for slower service
  notifications: new Pool({ max: 5 }), // Fire-and-forget, small pool
};

// If payments is slow, it can't starve orders
async function getOrders() {
  return pools.orders.query('SELECT * FROM orders');
}
```

### Retry with Exponential Backoff

```typescript
async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 100
): Promise<T> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === maxRetries - 1) throw error;
      const delay = baseDelay * Math.pow(2, attempt); // 100, 200, 400
      await sleep(delay + Math.random() * 100); // Add jitter
    }
  }
  throw new Error('Unreachable');
}
```

### Timeout

```typescript
async function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => setTimeout(() => reject(new TimeoutError()), ms)),
  ]);
}

// Usage
const result = await withTimeout(fetchFromSlowService(), 5000);
```

### Fallback / Degrade

```typescript
async function getRecommendations(userId: string): Promise<Recommendation[]> {
  try {
    return await withTimeout(recommendationService.get(userId), 200);
  } catch (error) {
    // Fallback: return cached or popular items
    return await cache.get(`recommendations:${userId}`) ?? popularItems;
  }
}
```

---

## Decision Frameworks

### When to Use What Architecture

| Criteria | Monolith | Microservices | Serverless | Edge |
|----------|----------|--------------|------------|------|
| Team size | < 10 | > 20 | Any | Any |
| Time to market | Fast | Medium | Fast | Fast |
| Operational complexity | Low | High | Low | Low |
| Cost at low traffic | Low | High | Very low | Very low |
| Cost at high traffic | Medium | Medium | High | Low |
| Scale independently | No | Yes | Yes (function) | Yes (region) |
| Latency | Medium | Medium | Medium | Ultra-low |
| Cold starts | No | No | Yes | Minimal |
| Language flexibility | One | Many | One per function | One |
| State persistence | Easy | Hard | Hard | Very hard |

### Technology Selection Matrix

| Concern | Options | Decision Criteria |
|---------|---------|-------------------|
| API Framework | NestJS, FastAPI, Go Gin, Django, Hono | Team skill, performance needs, ecosystem |
| Database | PostgreSQL, MySQL, MongoDB, DynamoDB | ACID needs, query complexity, scale |
| Cache | Redis, Memcached, CDN | Data structures, pub/sub, persistence |
| Queue | Kafka, RabbitMQ, Redis, SQS | Throughput, ordering, durability, ops |
| Auth | Auth0, Keycloak, Cognito, Clerk | Enterprise needs, pricing, self-host |
| Monitoring | Datadog, Prometheus, CloudWatch | Budget, existing stack, alerting needs |
| CI/CD | GitHub Actions, GitLab, Jenkins | Git host, budget, complexity |
| IaC | Terraform, Pulumi, CDK | Team skill, cloud vendor, state management |

## References

- [Martin Fowler — Microservices](https://martinfowler.com/articles/microservices.html)
- [Eric Evans — Domain-Driven Design](https://www.domainlanguage.com/ddd/reference/)
- [Chris Richardson — Microservices Patterns](https://microservices.io/patterns/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Google Cloud Architecture Center](https://cloud.google.com/architecture)
- [Microsoft Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/)
