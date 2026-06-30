# Third-Party Integrations

> Webhooks, REST APIs, GraphQL, message queues, SDKs, and integration patterns for connecting with external services.

## Table of Contents

1. [Integration Patterns](#1-integration-patterns)
2. [Webhook Handling](#2-webhook-handling)
3. [REST API Clients](#3-rest-api-clients)
4. [GraphQL Clients](#4-graphql-clients)
5. [Message Queues](#5-message-queues)
6. [SDK Development](#6-sdk-development)
7. [Idempotency](#7-idempotency)
8. [Circuit Breakers](#8-circuit-breakers)
9. [Retry Strategies](#9-retry-strategies)
10. [Error Handling](#10-error-handling)

---

## 1. Integration Patterns

### Sync vs Async Integration

| Pattern | When | Pros | Cons |
|---------|------|------|------|
| **Synchronous HTTP** | Real-time, simple | Immediate feedback | Blocking, coupling |
| **Async Webhook** | Event-driven, decoupled | Loose coupling, scalable | Eventual consistency, ordering |
| **Message Queue** | High volume, reliable | Durability, retry, scale | Complexity, latency |
| **Event Streaming** | Log aggregation, replay | Replay, audit, multiple consumers | Complexity, ordering |
| **Polling** | No webhook support | Simple | Inefficient, delayed |
| **GraphQL Subscription** | Real-time data | Precise updates | Complex, WebSocket overhead |

### Integration Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Your App  │────>│   Adapter   │────>│  External   │
│             │<────│   Layer     │<────│   Service   │
└─────────────┘     └─────────────┘     └─────────────┘
       │
       ├── Sync: HTTP request/response
       ├── Async: Webhook receiver
       ├── Queue: Producer/consumer
       └── Event: Publisher/subscriber
```

---

## 2. Webhook Handling

### Webhook Receiver Design

```typescript
// Webhook endpoint with security
app.post('/webhooks/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
  const signature = req.headers['stripe-signature'] as string;
  const payload = req.body;

  // Verify signature
  try {
    const event = stripe.webhooks.constructEvent(payload, signature, process.env.STRIPE_WEBHOOK_SECRET);

    // Idempotency: check if already processed
    const processed = await redis.get(`webhook:${event.id}`);
    if (processed) {
      return res.status(200).json({ received: true, id: event.id, status: 'already_processed' });
    }

    // Process event
    await processWebhookEvent(event);

    // Mark as processed
    await redis.setex(`webhook:${event.id}`, 86400, 'processed');

    res.status(200).json({ received: true, id: event.id });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(400).json({ error: 'Invalid signature' });
  }
});

async function processWebhookEvent(event: Stripe.Event) {
  switch (event.type) {
    case 'payment_intent.succeeded':
      await handlePaymentSuccess(event.data.object as Stripe.PaymentIntent);
      break;
    case 'payment_intent.payment_failed':
      await handlePaymentFailure(event.data.object as Stripe.PaymentIntent);
      break;
    case 'customer.subscription.deleted':
      await handleSubscriptionCancellation(event.data.object as Stripe.Subscription);
      break;
    default:
      console.log(`Unhandled event type: ${event.type}`);
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

---

## 3. REST API Clients

### HTTP Client Best Practices

```typescript
import axios, { AxiosInstance, AxiosError } from 'axios';
import { retryWithBackoff } from './utils';

class ExternalAPIClient {
  private client: AxiosInstance;
  private circuitBreaker: CircuitBreaker;

  constructor(baseURL: string, apiKey: string) {
    this.client = axios.create({
      baseURL,
      timeout: 10000,
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor: logging
    this.client.interceptors.request.use((config) => {
      console.log(`[API] ${config.method?.toUpperCase()} ${config.url}`);
      return config;
    });

    // Response interceptor: retry + error handling
    this.client.interceptors.response.use(
      (response) => response,
      async (error: AxiosError) => {
        if (error.response?.status === 429) {
          const retryAfter = parseInt(error.response.headers['retry-after'] || '5');
          await sleep(retryAfter * 1000);
          return this.client.request(error.config!);
        }
        if (error.response?.status >= 500) {
          return retryWithBackoff(() => this.client.request(error.config!));
        }
        throw error;
      }
    );

    this.circuitBreaker = new CircuitBreaker({ failureThreshold: 5, timeout: 30000 });
  }

  async getUser(id: string): Promise<User> {
    return this.circuitBreaker.execute(async () => {
      const response = await this.client.get(`/users/${id}`);
      return response.data;
    });
  }
}
```

---

## 4. GraphQL Clients

```typescript
import { GraphQLClient, gql } from 'graphql-request';

const client = new GraphQLClient('https://api.example.com/graphql', {
  headers: { authorization: `Bearer ${token}` },
});

// Query with variables and error handling
const query = gql`
  query GetUser($id: ID!) {
    user(id: $id) {
      id
      email
      name
      orders(first: 10) {
        edges {
          node {
            id
            total
            status
          }
        }
      }
    }
  }
`;

try {
  const data = await client.request(query, { id: 'user_123' });
  console.log(data.user);
} catch (error) {
  if (error.response?.errors) {
    console.error('GraphQL errors:', error.response.errors);
  }
}
```

---

## 5. Message Queues

### Queue Comparison

| Queue | Best For | Durability | Ordering | Scale | Complexity |
|-------|----------|------------|----------|-------|------------|
| **Kafka** | Event streaming, log aggregation | High | Partition | Horizontal | High |
| **RabbitMQ** | Complex routing, enterprise | High | Queue | Vertical | Medium |
| **Redis** | Simple jobs, real-time | Medium (AOF) | FIFO | Vertical | Low |
| **SQS** | AWS, simple, serverless | High | FIFO option | Auto | Low |
| **Pub/Sub** | GCP, real-time | High | Ordering key | Auto | Low |
| **NATS** | Cloud-native, speed | Configurable | Subject | Horizontal | Low |
| **BullMQ** | Node.js, jobs, scheduling | Redis | Job ID | Vertical | Low |

### BullMQ (Node.js)

```typescript
import { Queue, Worker, Job } from 'bullmq';
import Redis from 'ioredis';

const connection = new Redis({ host: 'localhost', port: 6379 });

// Producer
const emailQueue = new Queue('emails', { connection });

await emailQueue.add('send-welcome', {
  userId: 'user_123',
  email: 'user@example.com',
}, {
  delay: 5000,           // Delay 5 seconds
  attempts: 3,           // Retry 3 times
  backoff: { type: 'exponential', delay: 1000 },
  priority: 1,           // Higher = processed first
});

// Consumer
const worker = new Worker('emails', async (job: Job) => {
  console.log(`Processing job ${job.id}: ${job.name}`);
  await sendEmail(job.data);
}, {
  connection,
  concurrency: 5,        // Process 5 jobs concurrently
});

// Error handling
worker.on('failed', (job, error) => {
  console.error(`Job ${job?.id} failed:`, error);
  // Alert on critical failures
});
```

---

## 6. SDK Development

### SDK Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Type-safe** | TypeScript definitions, generics |
| **Configurable** | Options object, environment presets |
| **Retry logic** | Exponential backoff, circuit breaker |
| **Idempotent** | Automatic idempotency keys |
| **Observable** | Event hooks, middleware |
| **Lightweight** | Tree-shakeable, minimal deps |
| **Documented** | JSDoc, examples, README |

### SDK Example

```typescript
// my-sdk.ts
interface SDKOptions {
  apiKey: string;
  baseURL?: string;
  timeout?: number;
  retries?: number;
  environment?: 'production' | 'staging' | 'development';
}

class MySDK {
  private client: AxiosInstance;
  private options: Required<SDKOptions>;

  constructor(options: SDKOptions) {
    this.options = {
      baseURL: 'https://api.example.com',
      timeout: 10000,
      retries: 3,
      environment: 'production',
      ...options,
    };

    this.client = axios.create({
      baseURL: this.options.baseURL,
      timeout: this.options.timeout,
      headers: {
        'Authorization': `Bearer ${this.options.apiKey}`,
        'X-Idempotency-Key': this.generateIdempotencyKey(),
      },
    });
  }

  async createPayment(data: CreatePaymentInput): Promise<Payment> {
    return this.requestWithRetry('/payments', 'POST', data);
  }

  private async requestWithRetry<T>(
    url: string,
    method: string,
    data?: any
  ): Promise<T> {
    for (let attempt = 0; attempt < this.options.retries; attempt++) {
      try {
        const response = await this.client.request({ url, method, data });
        return response.data;
      } catch (error) {
        if (attempt === this.options.retries - 1) throw error;
        await sleep(1000 * Math.pow(2, attempt)); // Exponential backoff
      }
    }
    throw new Error('Unreachable');
  }

  private generateIdempotencyKey(): string {
    return `sdk-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
}

export { MySDK };
export type { SDKOptions, CreatePaymentInput, Payment };
```

---

## 7. Idempotency

### Idempotency Key Pattern

```typescript
// Middleware: ensure idempotent requests
async function idempotencyMiddleware(req: Request, res: Response, next: NextFunction) {
  const idempotencyKey = req.headers['idempotency-key'];
  if (!idempotencyKey) {
    return next(); // Not idempotent, proceed normally
  }

  const cacheKey = `idempotency:${idempotencyKey}`;
  const cached = await redis.get(cacheKey);

  if (cached) {
    const { status, body } = JSON.parse(cached);
    return res.status(status).json(body);
  }

  // Override res.json to cache response
  const originalJson = res.json.bind(res);
  res.json = (body: any) => {
    redis.setex(cacheKey, 86400, JSON.stringify({ status: res.statusCode, body }));
    return originalJson(body);
  };

  next();
}

// Usage: POST /payments with Idempotency-Key: abc123
// First call: processes, caches response
// Second call: returns cached response
```

---

## 8. Circuit Breakers

```typescript
class CircuitBreaker {
  private state: 'closed' | 'open' | 'half-open' = 'closed';
  private failures = 0;
  private lastFailure = 0;
  private readonly threshold: number;
  private readonly timeout: number;

  constructor(options: { threshold: number; timeout: number }) {
    this.threshold = options.threshold;
    this.timeout = options.timeout;
  }

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.lastFailure < this.timeout) {
        throw new Error('Circuit breaker is open');
      }
      this.state = 'half-open';
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
    this.failures = 0;
    this.state = 'closed';
  }

  private onFailure(): void {
    this.failures++;
    this.lastFailure = Date.now();
    if (this.failures >= this.threshold) {
      this.state = 'open';
    }
  }
}
```

---

## 9. Retry Strategies

| Strategy | When | Delay | Use Case |
|----------|------|-------|----------|
| **Fixed** | Transient failures | Constant (1s) | Network blips |
| **Linear** | Increasing load | 1s, 2s, 3s... | Rate limiting |
| **Exponential** | Uncertain recovery | 1s, 2s, 4s, 8s... | Most common |
| **Exponential + Jitter** | Distributed systems | + random(0-100ms) | Thundering herd |
| **Fibonacci** | Gradual backoff | 1s, 1s, 2s, 3s, 5s... | Resource contention |

### Exponential Backoff with Jitter

```typescript
async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 1000
): Promise<T> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === maxRetries - 1) throw error;
      const delay = baseDelay * Math.pow(2, attempt);
      const jitter = Math.random() * 1000;
      await sleep(delay + jitter);
    }
  }
  throw new Error('Unreachable');
}
```

---

## 10. Error Handling

### Integration Error Types

| Error | HTTP Status | Retry? | Action |
|-------|-------------|--------|--------|
| **Timeout** | 504/408 | Yes | Retry with backoff |
| **Rate Limit** | 429 | Yes | Respect Retry-After |
| **Server Error** | 500/502/503 | Yes | Retry, then circuit break |
| **Auth Error** | 401/403 | No | Fix credentials, alert |
| **Not Found** | 404 | No | Fix URL, alert |
| **Bad Request** | 400 | No | Fix request payload |
| **Validation** | 422 | No | Fix payload |
| **Conflict** | 409 | Maybe | Check idempotency |

### Integration Error Response

```json
{
  "error": {
    "code": "INTEGRATION_ERROR",
    "message": "Payment service unavailable",
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:00:00Z",
    "source": "stripe",
    "details": {
      "status": 503,
      "retryAfter": 30,
      "originalError": "Connection timeout"
    }
  }
}
```

## References

- [Stripe API Design](https://stripe.com/docs/api)
- [REST API Best Practices](https://docs.microsoft.com/en-us/azure/architecture/best-practices/api-design)
- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [NATS Documentation](https://docs.nats.io/)
- [BullMQ Documentation](https://docs.bullmq.io/)
- [Idempotency Keys](https://stripe.com/docs/api/idempotency)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
