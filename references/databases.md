# Database Design & Selection

> SQL vs NoSQL, indexing strategies, sharding, replication, ORM selection, and query optimization for production databases.

## Table of Contents

1. [Database Selection](#1-database-selection)
2. [Schema Design](#2-schema-design)
3. [Indexing Strategies](#3-indexing-strategies)
4. [Query Optimization](#4-query-optimization)
5. [Connection Pooling](#5-connection-pooling)
6. [Replication & High Availability](#6-replication--high-availability)
7. [Sharding](#7-sharding)
8. [Caching Strategies](#8-caching-strategies)
9. [ORM Selection](#9-orm-selection)
10. [Migrations](#10-migrations)
11. [Time-Series Data](#11-time-series-data)
12. [Full-Text Search](#12-full-text-search)

---

## 1. Database Selection

### Database Types Comparison

| Database | Type | Best For | ACID | Scale | Complexity |
|----------|------|----------|------|-------|------------|
| **PostgreSQL** | Relational | General purpose, complex queries, JSON | Full | Vertical + read replicas | Low |
| **MySQL** | Relational | Web apps, read-heavy | Full | Vertical + read replicas | Low |
| **SQLite** | Embedded | Mobile, edge, testing | Full | Single node | Very low |
| **MongoDB** | Document | Flexible schema, rapid iteration | Document-level | Horizontal | Medium |
| **Redis** | Key-value | Cache, sessions, real-time | None (or Lua) | Cluster | Low |
| **Elasticsearch** | Search | Full-text, analytics | Eventual | Horizontal | Medium |
| **TimescaleDB** | Time-series | IoT, metrics, monitoring | Full | Horizontal | Low |
| **InfluxDB** | Time-series | High ingest, short retention | Eventual | Horizontal | Medium |
| **Neo4j** | Graph | Relationships, recommendations | Full | Cluster | Medium |
| **DynamoDB** | Key-value | AWS, simple queries, massive scale | Eventual | Auto | Low |
| **CockroachDB** | Distributed | Global SQL, always-on | Full | Horizontal | Medium |
| **TiDB** | Distributed | MySQL-compatible, horizontal | Full | Horizontal | Medium |
| **PlanetScale** | MySQL | Serverless, branching | Full | Auto | Very low |
| **Supabase** | PostgreSQL | Serverless, real-time | Full | Auto | Very low |

### Decision Matrix

| Requirement | Recommendation |
|-------------|---------------|
| ACID transactions + complex joins | PostgreSQL |
| Rapid prototyping, flexible schema | MongoDB or PostgreSQL JSONB |
| High write throughput (logs, events) | TimescaleDB or Kafka |
| Full-text search | Elasticsearch or PostgreSQL tsvector |
| Cache / sessions / real-time | Redis |
| Graph relationships | Neo4j |
| AWS serverless, massive scale | DynamoDB |
| Global distribution, always-on | CockroachDB or Spanner |
| Edge / offline / mobile | SQLite |

---

## 2. Schema Design

### Normalization vs Denormalization

| Level | Description | Use Case |
|-------|-------------|----------|
| **1NF** | Atomic values, no repeating groups | Always |
| **2NF** | No partial dependencies | Always |
| **3NF** | No transitive dependencies | Default |
| **Denormalized** | Intentional redundancy for performance | Read-heavy, analytics |

### PostgreSQL Schema Example

```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  role VARCHAR(50) NOT NULL DEFAULT 'user',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ, -- Soft delete

  CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_role ON users(role) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- Orders table with foreign key
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
  currency VARCHAR(3) NOT NULL DEFAULT 'USD',
  shipping_address JSONB,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT valid_status CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
  CONSTRAINT positive_total CHECK (total_amount >= 0)
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status) WHERE status NOT IN ('delivered', 'cancelled');
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_metadata ON orders USING GIN(metadata); -- JSONB index

-- Order items (weak entity)
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(10, 2) NOT NULL,

  CONSTRAINT positive_quantity CHECK (quantity > 0),
  CONSTRAINT positive_price CHECK (unit_price >= 0)
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### MongoDB Schema Example

```javascript
// Users collection
{
  _id: ObjectId('...'),
  email: 'user@example.com',
  passwordHash: '...',
  profile: {
    name: 'John Doe',
    avatar: 'https://...',
  },
  role: 'user',
  isActive: true,
  createdAt: ISODate('2024-01-15T10:00:00Z'),
  updatedAt: ISODate('2024-01-15T10:00:00Z'),
}

// Orders collection (embedded items for atomicity)
{
  _id: ObjectId('...'),
  userId: ObjectId('...'),
  status: 'pending',
  items: [
    { productId: ObjectId('...'), name: 'Widget', quantity: 2, price: 19.99 },
    { productId: ObjectId('...'), name: 'Gadget', quantity: 1, price: 49.99 },
  ],
  total: 89.97,
  shippingAddress: {
    street: '123 Main St',
    city: 'San Francisco',
    state: 'CA',
    zip: '94102',
  },
  createdAt: ISODate('...'),
}

// Indexes
db.users.createIndex({ email: 1 }, { unique: true });
db.users.createIndex({ role: 1, createdAt: -1 });
db.orders.createIndex({ userId: 1, createdAt: -1 });
db.orders.createIndex({ status: 1 }, { partialFilterExpression: { status: { $in: ['pending', 'paid'] } } });
```

---

## 3. Indexing Strategies

### PostgreSQL Index Types

| Index Type | Best For | Example |
|------------|----------|---------|
| **B-tree** (default) | Equality, range, ordering | `CREATE INDEX ON users(email)` |
| **Hash** | Equality only (rarely used) | `CREATE INDEX ON users USING HASH(email)` |
| **GIN** | JSONB, arrays, full-text | `CREATE INDEX ON orders USING GIN(metadata)` |
| **GiST** | Spatial, nearest-neighbor | `CREATE INDEX ON locations USING GiST(point)` |
| **SP-GiST** | Quad trees, k-d trees | `CREATE INDEX ON ranges USING SP-GiST(range)` |
| **BRIN** | Large, naturally ordered tables | `CREATE INDEX ON logs USING BRIN(created_at)` |

### Composite Index Design

```sql
-- Order matters: equality first, then range, then ordering
CREATE INDEX idx_orders_user_status_created 
  ON orders(user_id, status, created_at DESC);

-- Query patterns this supports:
-- WHERE user_id = ? AND status = ? ORDER BY created_at DESC ✓
-- WHERE user_id = ? AND status IN (...) ✓ (partial)
-- WHERE user_id = ? ORDER BY created_at DESC ✓ (partial)
-- WHERE status = ? ✗ (user_id missing)
```

### Indexing Best Practices

- **Index for WHERE, JOIN, ORDER BY, GROUP BY**: If a column is used in these clauses, consider indexing
- **Avoid over-indexing**: Every index slows down writes, uses disk space
- **Partial indexes**: Index only hot data (e.g., `WHERE status = 'pending'`)
- **Covering indexes**: Include all queried columns in index for index-only scans
- **Expression indexes**: Index on expressions (e.g., `LOWER(email)`)
- **Analyze regularly**: `ANALYZE` updates statistics for query planner

### Index-Only Scan Example

```sql
-- Covering index: includes all columns needed for query
CREATE INDEX idx_orders_covering 
  ON orders(user_id, status, created_at) 
  INCLUDE (total_amount, currency);

-- This query can use index-only scan (no table access)
SELECT user_id, status, created_at, total_amount, currency
FROM orders 
WHERE user_id = '...' AND status = 'pending';
```

---

## 4. Query Optimization

### EXPLAIN ANALYZE

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT u.email, o.status, o.total_amount
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE u.role = 'admin'
  AND o.status = 'pending'
  AND o.created_at > '2024-01-01'
ORDER BY o.created_at DESC
LIMIT 20;
```

### Common Query Anti-Patterns

```sql
-- ❌ SELECT * (retrieves unnecessary columns)
SELECT * FROM users WHERE id = '...';

-- ✅ Select only needed columns
SELECT id, email, name FROM users WHERE id = '...';

-- ❌ N+1 queries (in loop)
for (const user of users) {
  orders = await db.orders.find({ userId: user.id }); // N queries!
}

-- ✅ Single query with JOIN or IN
SELECT * FROM orders WHERE user_id IN (...);

-- ❌ Functions on indexed columns (prevents index use)
WHERE DATE(created_at) = '2024-01-01'

-- ✅ Range query on raw column
WHERE created_at >= '2024-01-01' AND created_at < '2024-01-02'

-- ❌ LIKE with leading wildcard
WHERE email LIKE '%@example.com'

-- ✅ Trigram index for partial matches (pg_trgm extension)
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_users_email_trgm ON users USING GIN(email gin_trgm_ops);
WHERE email LIKE '%@example.com' -- Now uses index

-- ❌ OR conditions (often suboptimal)
WHERE status = 'pending' OR status = 'paid'

-- ✅ IN or UNION
WHERE status IN ('pending', 'paid')
-- OR
SELECT ... WHERE status = 'pending'
UNION ALL
SELECT ... WHERE status = 'paid'
```

### Query Optimization Techniques

| Technique | When | How |
|-----------|------|-----|
| **Materialized Views** | Expensive aggregations queried often | `CREATE MATERIALIZED VIEW` + refresh |
| **Partitioning** | Large tables (100M+ rows) | By time, range, or hash |
| **Batch Processing** | Large inserts/updates | `COPY`, bulk inserts, temp tables |
| **Connection Pooling** | High concurrency | PgBouncer, RDS Proxy |
| **Read Replicas** | Read-heavy workloads | Route reads to replicas |
| **Caching** | Repeated queries | Redis, application cache |
| **Denormalization** | Complex joins too slow | Add redundant columns, materialized views |

---

## 5. Connection Pooling

### Why Pool?

- **Connection overhead**: Establishing a connection takes 5-50ms
- **Resource limits**: PostgreSQL max_connections ~ 100-1000
- **Throughput**: Pooled connections = higher throughput

### Pool Configuration

| Setting | Default | Recommended | Description |
|---------|---------|-------------|-------------|
| `min` | 0 | 5 | Always keep N connections ready |
| `max` | 10 | 20-50 | Max connections per app instance |
| `acquire` | 60000 | 30000 | Max wait for connection (ms) |
| `idle` | 10000 | 60000 | Close idle connections after (ms) |
| `eviction` | 0 | 300000 | Max connection lifetime (ms) |

### PostgreSQL Pool (Node.js - pg-pool)

```typescript
import { Pool } from 'pg';

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'myapp',
  user: 'app_user',
  password: process.env.DB_PASSWORD,
  
  // Pool settings
  min: 5,
  max: 20,
  idleTimeoutMillis: 60000,
  connectionTimeoutMillis: 30000,
  maxUses: 7500, // Recycle after N queries (prevent memory leaks)
});

// Graceful shutdown
async function closePool() {
  await pool.end();
}
```

### PgBouncer (External Pooler)

```ini
; pgbouncer.ini
[databases]
mydb = host=db.internal port=5432 dbname=mydb

[pgbouncer]
listen_port = 6432
listen_addr = 0.0.0.0
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

pool_mode = transaction      ; transaction, session, or statement
max_client_conn = 10000
default_pool_size = 25
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
server_idle_timeout = 600
server_lifetime = 3600
```

---

## 6. Replication & High Availability

### Replication Types

| Type | Consistency | Lag | Use Case |
|------|-------------|-----|----------|
| **Synchronous** | Strong | 0ms | Critical data, small scale |
| **Asynchronous** | Eventual | 1ms-1s | Read scaling, most common |
| **Logical** | Eventual | Configurable | Selective replication, upgrades |
| **Streaming** | Eventual | Near-zero | Hot standby, failover |

### PostgreSQL Streaming Replication Setup

```bash
# Primary server configuration
# postgresql.conf
wal_level = replica
max_wal_senders = 10
wal_keep_size = 1GB
hot_standby = on
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/archive/%f'

# Create replication user
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '...';

# pg_hba.conf
host replication replicator 10.0.0.0/24 scram-sha-256
```

### Read Replica Routing

```typescript
class DatabaseRouter {
  private primary: Pool;
  private replicas: Pool[];
  private replicaIndex = 0;

  constructor(primary: Pool, replicas: Pool[]) {
    this.primary = primary;
    this.replicas = replicas;
  }

  getPool(operation: 'read' | 'write'): Pool {
    if (operation === 'write') return this.primary;
    // Round-robin read replicas
    const pool = this.replicas[this.replicaIndex];
    this.replicaIndex = (this.replicaIndex + 1) % this.replicas.length;
    return pool;
  }
}

// Usage
const db = new DatabaseRouter(primaryPool, [replica1, replica2]);
const writePool = db.getPool('write');
const readPool = db.getPool('read');
```

---

## 7. Sharding

### Sharding Strategies

| Strategy | Key | Pros | Cons |
|----------|-----|------|------|
| **Hash** | hash(user_id) % N | Even distribution | Rebalancing needed |
| **Range** | user_id range | Simple, range queries | Hot spots |
| **List** | region, tenant | Multi-tenant | Manual mapping |
| **Directory** | Lookup table | Flexible | Single point of failure |

### Citus (PostgreSQL Sharding)

```sql
-- Install Citus extension
CREATE EXTENSION citus;

-- Create distributed table
SELECT create_distributed_table('orders', 'user_id');

-- Shard count (default: 32)
SELECT citus.shard_count = 32;

-- Rebalance shards
SELECT rebalance_table_shards('orders');

-- Colocation for joins
SELECT create_distributed_table('order_items', 'user_id', colocate_with => 'orders');
```

---

## 8. Caching Strategies

### Database Cache Layers

| Layer | Technology | Hit Rate | Latency |
|-------|------------|----------|---------|
| **Application** | In-memory (Node.js, Python) | High | ~1μs |
| **Redis** | External cache | Medium | ~1ms |
| **PostgreSQL** | Shared buffers | Medium | ~10μs |
| **OS** | Page cache | High | ~1μs |
| **SSD** | Storage cache | Low | ~100μs |

### Cache Invalidation Patterns

```typescript
// Write-through cache
async function updateUser(id: string, data: UpdateUserDto) {
  const user = await db.users.update(id, data);
  await redis.setex(`user:${id}`, 300, JSON.stringify(user));
  await redis.del('users:list'); // Invalidate list
  return user;
}

// Cache-aside with read-through
async function getUser(id: string) {
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);
  
  const user = await db.users.findById(id);
  if (user) await redis.setex(`user:${id}`, 300, JSON.stringify(user));
  return user;
}

// Write-behind (async persistence)
async function createOrder(data: CreateOrderDto) {
  const order = await redis.lpush('orders:pending', JSON.stringify(data));
  // Background worker persists to DB
  return order;
}
```

---

## 9. ORM Selection

### ORM Comparison

| ORM | Language | Best For | Migrations | Performance | Type Safety |
|-----|----------|----------|------------|-------------|---------------|
| **Prisma** | TypeScript/Node.js | Type safety, DX | Excellent | Good | ⭐ Excellent |
| **TypeORM** | TypeScript/Node.js | Flexibility, decorators | Good | Good | Good |
| **Sequelize** | Node.js | Legacy, wide support | Good | Medium | Poor |
| **Drizzle** | TypeScript/Node.js | SQL-like, lightweight | Good | ⭐ Excellent | ⭐ Excellent |
| **SQLAlchemy** | Python | Flexibility, power | Good | Good | Good |
| **Django ORM** | Python | Rapid development, admin | Excellent | Good | Medium |
| **GORM** | Go | Convention over config | Good | Good | Medium |
| **pgx** | Go | Raw performance, PostgreSQL | N/A | ⭐ Excellent | Good |
| **Ecto** | Elixir | Functional, composable | Excellent | Good | Excellent |

### Prisma Example (Recommended for Node.js)

```typescript
// schema.prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  role      Role     @default(USER)
  isActive  Boolean  @default(true) @map("is_active")
  orders    Order[]
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  @@index([email])
  @@index([role, createdAt])
  @@map("users")
}

model Order {
  id          String      @id @default(cuid())
  userId      String      @map("user_id")
  user        User        @relation(fields: [userId], references: [id])
  status      OrderStatus @default(PENDING)
  totalAmount Decimal     @map("total_amount") @db.Decimal(10, 2)
  items       OrderItem[]
  createdAt   DateTime    @default(now()) @map("created_at")

  @@index([userId, createdAt])
  @@map("orders")
}

// Usage
const user = await prisma.user.create({
  data: { email: 'user@example.com', name: 'John' },
});

const orders = await prisma.order.findMany({
  where: { userId: user.id, status: 'pending' },
  include: { items: true },
  orderBy: { createdAt: 'desc' },
  take: 20,
});
```

---

## 10. Migrations

### Migration Tools

| Tool | Database | Best For | Features |
|------|----------|----------|----------|
| **Prisma Migrate** | PostgreSQL, MySQL, SQLite, MongoDB | Node.js, type safety | Generate from schema, shadow DB |
| **Flyway** | All SQL | Java, enterprise | Versioned, repeatable, callbacks |
| **Liquibase** | All SQL | Java, enterprise | XML/YAML/JSON, rollbacks |
| **Alembic** | SQLAlchemy | Python | Auto-generate, branching |
| **Django Migrations** | Django ORM | Python, Django | Auto-detect, run automatically |
| **Atlas** | PostgreSQL, MySQL | DevOps, CI/CD | Schema as code, declarative |
| **pgroll** | PostgreSQL | Zero-downtime | Expand-contract pattern |

### Zero-Downtime Migrations

```sql
-- Pattern: Expand → Update → Contract

-- 1. Expand: Add new column (nullable or with default)
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT false;
-- Instant: no table rewrite with DEFAULT

-- 2. Dual write: App writes to both old and new
-- Application code update deployed

-- 3. Backfill: Update existing rows in batches
UPDATE users SET email_verified = true WHERE created_at < '2024-01-01';
-- Run in batches of 1000 to avoid lock contention

-- 4. Update: App reads from new, stops writing old
-- Application code update deployed

-- 5. Contract: Remove old column
ALTER TABLE users DROP COLUMN old_email_status;
```

---

## 11. Time-Series Data

### TimescaleDB Setup

```sql
-- Install extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create hypertable
CREATE TABLE metrics (
  time TIMESTAMPTZ NOT NULL,
  device_id TEXT NOT NULL,
  temperature DOUBLE PRECISION,
  humidity DOUBLE PRECISION,
  metadata JSONB
);

-- Convert to hypertable (automatic partitioning by time)
SELECT create_hypertable('metrics', 'time', chunk_time_interval => INTERVAL '1 day');

-- Continuous aggregation (hourly averages)
CREATE MATERIALIZED VIEW metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 hour', time) AS hour,
  device_id,
  AVG(temperature) AS avg_temp,
  AVG(humidity) AS avg_humidity
FROM metrics
GROUP BY hour, device_id;

-- Retention policy (drop chunks after 90 days)
SELECT add_retention_policy('metrics', INTERVAL '90 days');
```

---

## 12. Full-Text Search

### PostgreSQL Full-Text Search

```sql
-- Add search vector column
ALTER TABLE products ADD COLUMN search_vector tsvector;

-- Update index on changes
CREATE OR REPLACE FUNCTION products_search_update()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('english', COALESCE(NEW.name, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.category, '')), 'C');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER products_search_trigger
  BEFORE INSERT OR UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION products_search_update();

-- GIN index for fast search
CREATE INDEX idx_products_search ON products USING GIN(search_vector);

-- Search query
SELECT * FROM products
WHERE search_vector @@ plainto_tsquery('english', 'wireless headphones')
ORDER BY ts_rank(search_vector, plainto_tsquery('english', 'wireless headphones')) DESC;
```

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Use The Index, Luke](https://use-the-index-luke.com/)
- [SQL Performance Explained](https://sql-performance-explained.com/)
- [MongoDB Schema Design Patterns](https://www.mongodb.com/blog/post/building-with-patterns-a-summary)
- [Prisma Best Practices](https://www.prisma.io/docs/guides/performance-and-optimization)
- [Citus Documentation](https://docs.citusdata.com/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
