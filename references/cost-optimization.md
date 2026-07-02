# Cost Optimization Reference

## Table of Contents
1. [Compute Optimization](#compute-optimization)
2. [Database Optimization](#database-optimization)
3. [Serverless Optimization](#serverless-optimization)
4. [Storage Optimization](#storage-optimization)
5. [CDN Optimization](#cdn-optimization)
6. [Networking Optimization](#networking-optimization)
7. [Caching Optimization](#caching-optimization)
8. [Monitoring Costs](#monitoring-costs)
9. [Third-Party API Costs](#third-party-api-costs)
10. [Development Environments](#development-environments)
11. [Cost Modeling](#cost-modeling)
12. [Code Examples](#code-examples)

---

## Compute Optimization

### Reserved vs On-Demand vs Spot

| Instance Type | Discount | Commitment | Best For | Risk |
|--------------|----------|------------|----------|------|
| **On-Demand** | 0% | None | Spiky workloads, dev/test | None |
| **Reserved** | 30-72% | 1-3 years | Steady-state production | Low |
| **Savings Plans** | 30-72% | Flexible commitment | Mixed instance families | Low |
| **Spot** | 50-90% | None | Fault-tolerant, interruptible | High (2-min notice) |
| **Spot Blocks** | 30-50% | 1-6 hours | Short predictable workloads | Medium |

```typescript
// compute-cost-comparison.ts
interface ComputeOption {
  instanceType: string;
  onDemandPrice: number; // per hour
  reservedPrice: number;
  spotPrice: number;
  availability: number; // % uptime guarantee
}

const m5Large: ComputeOption = {
  instanceType: 'm5.large',
  onDemandPrice: 0.096,
  reservedPrice: 0.058, // 3-year, all upfront
  spotPrice: 0.028,
  availability: 0.99, // Spot can be interrupted
};

function calculateAnnualCost(option: ComputeOption, hoursPerMonth: number, strategy: 'on_demand' | 'reserved' | 'spot' | 'mixed'): number {
  const prices = {
    on_demand: option.onDemandPrice,
    reserved: option.reservedPrice,
    spot: option.spotPrice,
  };

  if (strategy === 'mixed') {
    // 70% reserved (baseline), 30% spot (burstable)
    const baseCost = hoursPerMonth * 0.7 * option.reservedPrice * 12;
    const burstCost = hoursPerMonth * 0.3 * option.spotPrice * 12;
    return baseCost + burstCost;
  }

  return hoursPerMonth * 12 * prices[strategy];
}

// Example: 730 hours/month
// On-demand: $841/year
// Reserved: $508/year (40% savings)
// Mixed: $549/year (35% savings, more flexible)
```

### Auto-Scaling Strategy

```yaml
# k8s-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 3
  maxReplicas: 50
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
        - type: Pods
          value: 4
          periodSeconds: 15
      selectPolicy: Max
```

### Right-Sizing

```typescript
// right-sizing-analyzer.ts
interface ResourceUsage {
  cpuAverage: number;
  cpuPeak: number;
  memoryAverage: number;
  memoryPeak: number;
  duration: number; // days of data
}

function recommendRightSizing(usage: ResourceUsage, currentSpec: ResourceSpec): Recommendation {
  const recommendations: Recommendation[] = [];

  // CPU right-sizing
  if (usage.cpuAverage < 30) {
    recommendations.push({
      type: 'downsize',
      resource: 'cpu',
      current: currentSpec.cpu,
      recommended: Math.ceil(currentSpec.cpu * 0.6),
      estimatedSavings: 40,
      confidence: 'high',
    });
  } else if (usage.cpuAverage > 80) {
    recommendations.push({
      type: 'upsize',
      resource: 'cpu',
      current: currentSpec.cpu,
      recommended: Math.ceil(currentSpec.cpu * 1.5),
      reason: 'High CPU utilization causing throttling',
    });
  }

  // Memory right-sizing
  if (usage.memoryPeak < currentSpec.memory * 0.5) {
    recommendations.push({
      type: 'downsize',
      resource: 'memory',
      current: currentSpec.memory,
      recommended: Math.ceil(currentSpec.memory * 0.6),
      estimatedSavings: 40,
      confidence: 'high',
    });
  }

  return recommendations;
}
```

### Container Density

```yaml
# optimized-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  template:
    spec:
      containers:
        - name: api
          image: api:latest
          resources:
            requests:
              cpu: "100m"       # Guarantee 0.1 CPU
              memory: "256Mi"   # Guarantee 256 MB
            limits:
              cpu: "500m"       # Burst up to 0.5 CPU
              memory: "512Mi"   # Hard limit 512 MB
          # Resource optimization
          env:
            - name: NODE_OPTIONS
              value: "--max-old-space-size=448" # 512MB - 64MB overhead
            - name: UV_THREADPOOL_SIZE
              value: "16" # Reduce from default 128 if I/O bound
```

---

## Database Optimization

### Read Replicas vs Connection Pooling

```typescript
// database-config.ts
interface DatabaseStrategy {
  readReplicas: boolean;
  connectionPooling: boolean;
  pgbouncer: boolean;
  poolingMode: 'transaction' | 'session' | 'statement';
}

const optimizedConfig: DatabaseStrategy = {
  readReplicas: true,
  connectionPooling: true,
  pgbouncer: true,
  poolingMode: 'transaction', // Best for ORM-heavy apps
};

// Prisma with connection pooling + read replicas
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL,          // Primary (writes)
    },
  },
});

// Read replica setup (PostgreSQL)
// PRIMARY_URL=postgresql://user:pass@primary:5432/db
// REPLICA_URL=postgresql://user:pass@replica:5432/db

export async function readQuery<T>(query: () => Promise<T>): Promise<T> {
  // Route to read replica
  return prisma.$queryRaw`SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY;`.then(query);
}
```

### Query Optimization

```typescript
// query-optimization.ts
async function getOrdersWithItems(userId: string) {
  // BAD: N+1 queries
  const orders = await prisma.order.findMany({ where: { userId } });
  for (const order of orders) {
    order.items = await prisma.orderItem.findMany({ where: { orderId: order.id } });
  }

  // GOOD: Single query with join
  const ordersWithItems = await prisma.order.findMany({
    where: { userId },
    include: {
      items: true, // Prisma handles the join
    },
  });

  // BEST: Select only needed fields
  const optimizedOrders = await prisma.order.findMany({
    where: { userId },
    select: {
      id: true,
      status: true,
      total: true,
      items: {
        select: { productId: true, quantity: true },
      },
    },
  });

  return optimizedOrders;
}

// Index analysis
// EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = '...' AND created_at > '...';
// Create composite index: CREATE INDEX idx_orders_user_created ON orders(user_id, created_at DESC);
```

### Index Analysis

```sql
-- Find missing indexes (PostgreSQL)
SELECT
  schemaname,
  tablename,
  attname as column,
  n_tup_read,
  n_tup_fetch
FROM pg_stats
WHERE schemaname = 'public'
ORDER BY n_tup_read DESC
LIMIT 20;

-- Find unused indexes (candidates for removal)
SELECT
  schemaname || '.' || relname as table,
  indexrelname as index,
  pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
  idx_scan as index_scans
FROM pg_stat_user_indexes
WHERE idx_scan < 50
  AND pg_relation_size(indexrelid) > 100000
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Archiving Old Data

```typescript
// data-archiving.ts
interface ArchivalRule {
  table: string;
  condition: string;       // e.g., "created_at < NOW() - INTERVAL '1 year'"
  destination: 's3' | 'glacier' | 'archive_table';
  retention: string;         // e.g., '7 years'
  compression: 'gzip' | 'zstd' | 'none';
}

const archivalRules: ArchivalRule[] = [
  {
    table: 'event_logs',
    condition: "created_at < NOW() - INTERVAL '90 days'",
    destination: 's3',
    retention: '7 years',
    compression: 'zstd',
  },
  {
    table: 'audit_logs',
    condition: "created_at < NOW() - INTERVAL '1 year'",
    destination: 'glacier',
    retention: '10 years',
    compression: 'gzip',
  },
  {
    table: 'session_data',
    condition: "expires_at < NOW() - INTERVAL '7 days'",
    destination: 'archive_table',
    retention: '30 days',
    compression: 'none',
  },
];

class DataArchiver {
  async archive(rule: ArchivalRule): Promise<ArchivalResult> {
    // 1. Export data to file
    const exportQuery = `COPY (
      SELECT * FROM ${rule.table}
      WHERE ${rule.condition}
    ) TO '/tmp/export.csv' WITH (FORMAT CSV, HEADER)`;

    await this.db.$executeRawUnsafe(exportQuery);

    // 2. Compress
    const compressedFile = await compress('/tmp/export.csv', rule.compression);

    // 3. Upload to destination
    if (rule.destination === 's3') {
      await this.s3.upload({
        Bucket: 'data-archive',
        Key: `${rule.table}/${new Date().toISOString()}.csv.${rule.compression}`,
        Body: createReadStream(compressedFile),
        StorageClass: 'GLACIER',
      });
    }

    // 4. Delete archived rows
    await this.db.$executeRawUnsafe(`
      DELETE FROM ${rule.table}
      WHERE ${rule.condition}
    `);

    // 5. VACUUM to reclaim space
    await this.db.$executeRawUnsafe(`VACUUM ${rule.table}`);

    return { archivedRows: await this.countArchivedRows(), destination: rule.destination };
  }
}
```

---

## Serverless Optimization

### Cold Start Mitigation

```typescript
// cold-start-optimization.ts
// 1. Keep functions warm with scheduled invocations
import { CloudWatchEvents } from 'aws-sdk';

const keepWarmRule = {
  Name: 'keep-api-warm',
  ScheduleExpression: 'rate(5 minutes)', // Invoke every 5 minutes
  State: 'ENABLED',
  Targets: [{
    Id: 'warm-target',
    Arn: 'arn:aws:lambda:region:account:function:api-function',
    Input: JSON.stringify({ warm: true }), // Skip heavy init
  }],
};

// 2. Provisioned Concurrency (AWS Lambda)
// aws lambda put-provisioned-concurrency-config \
//   --function-name api-function \
//   --qualifier PROD \
//   --provisioned-concurrent-executions 10

// 3. Minimize initialization code
let dbConnection: DatabaseConnection | null = null;

export const handler = async (event: APIGatewayEvent) => {
  // Lazy initialization outside handler for reuse across invocations
  if (!dbConnection) {
    dbConnection = await createConnection();
  }

  // Skip heavy operations on warm-up calls
  if (event.body && JSON.parse(event.body).warm) {
    return { statusCode: 200, body: 'warm' };
  }

  return handleRequest(event, dbConnection);
};
```

### Memory Tuning

```typescript
// lambda-memory-tuning.ts
interface MemoryConfig {
  allocatedMB: number;
  costPer1Ms: number;
  estimatedDuration: number;
  totalCost: number;
}

function findOptimalMemory(functionConfig: { minMB: number; maxMB: number; stepMB: number }): MemoryConfig {
  const configs: MemoryConfig[] = [];

  for (let mb = functionConfig.minMB; mb <= functionConfig.maxMB; mb += functionConfig.stepMB) {
    const costPerMs = (mb / 1024) * 0.0000166667; // AWS Lambda pricing
    // Higher memory = more CPU = lower duration
    const estimatedDuration = estimateDuration(mb);
    const totalCost = costPerMs * estimatedDuration;

    configs.push({ allocatedMB: mb, costPer1Ms: costPerMs, estimatedDuration, totalCost });
  }

  // Return cheapest configuration
  return configs.reduce((min, current) => current.totalCost < min.totalCost ? current : min);
}

// Tool: aws lambda power-tuning
// https://github.com/alexcasalboni/aws-lambda-power-tuning
```

### Execution Time Limits

```typescript
// timeout-optimization.ts
export const handler = async (event: APIGatewayEvent) => {
  const startTime = Date.now();
  const TIMEOUT_BUFFER = 1000; // 1 second buffer before Lambda timeout
  const functionTimeout = parseInt(process.env.AWS_LAMBDA_FUNCTION_TIMEOUT || '30') * 1000;
  const maxDuration = functionTimeout - TIMEOUT_BUFFER;

  const results = [];
  const items = event.items || [];

  for (const item of items) {
    if (Date.now() - startTime > maxDuration) {
      // Return partial results for reprocessing
      return {
        statusCode: 206, // Partial Content
        body: JSON.stringify({
          processed: results,
          remaining: items.slice(results.length),
          checkpoint: results.length,
        }),
      };
    }

    results.push(await processItem(item));
  }

  return { statusCode: 200, body: JSON.stringify({ processed: results }) };
};
```

---

## Storage Optimization

### Object Storage Tiers

| Tier | Access Pattern | Cost | Retrieval | Use Case |
|------|---------------|------|-----------|----------|
| **Standard** | Frequent | High | Instant | Active assets, hot data |
| **Standard-IA** | Infrequent | Medium | Instant | Backups, older content |
| **One Zone-IA** | Infrequent | Lower | Instant | Reconstructable data |
| **Glacier** | Rare | Low | 1-5 min | Archives, compliance |
| **Glacier Deep** | Very rare | Lowest | 12-48 hours | Long-term retention |
| **Intelligent** | Variable | Auto | Auto | Unknown access patterns |

```typescript
// storage-tiering.ts
import { S3Client, PutObjectCommand, StorageClass } from '@aws-sdk/client-s3';

interface StoragePolicy {
  fileType: string;
  initialTier: StorageClass;
  lifecycleRules: LifecycleRule[];
}

const storagePolicies: StoragePolicy[] = [
  {
    fileType: 'image',
    initialTier: 'STANDARD',
    lifecycleRules: [
      { days: 30, transition: 'STANDARD_IA' },
      { days: 90, transition: 'GLACIER' },
      { days: 365, delete: true },
    ],
  },
  {
    fileType: 'document',
    initialTier: 'STANDARD_IA',
    lifecycleRules: [
      { days: 180, transition: 'GLACIER' },
      { days: 2555, delete: true }, // 7 years for compliance
    ],
  },
  {
    fileType: 'log',
    initialTier: 'ONEZONE_IA',
    lifecycleRules: [
      { days: 30, transition: 'GLACIER_DEEP_ARCHIVE' },
      { days: 2555, delete: true },
    ],
  },
];

// S3 Lifecycle Policy (Terraform)
const s3LifecyclePolicy = {
  rules: [
    {
      id: 'image-lifecycle',
      status: 'Enabled',
      filter: { prefix: 'images/' },
      transitions: [
        { days: 30, storage_class: 'STANDARD_IA' },
        { days: 90, storage_class: 'GLACIER' },
      ],
      expiration: { days: 365 },
    },
    {
      id: 'log-lifecycle',
      status: 'Enabled',
      filter: { prefix: 'logs/' },
      transitions: [
        { days: 30, storage_class: 'GLACIER_DEEP_ARCHIVE' },
      ],
      expiration: { days: 2555 },
    },
  ],
};
```

### Compression

```typescript
// compression-service.ts
import { createGzip, createBrotliCompress } from 'zlib';
import { pipeline } from 'stream';

interface CompressionResult {
  originalSize: number;
  compressedSize: number;
  ratio: number;
  algorithm: 'gzip' | 'brotli' | 'zstd';
}

async function compressAsset(input: Buffer, algorithm: 'gzip' | 'brotli' | 'zstd'): Promise<CompressionResult> {
  let compressed: Buffer;

  switch (algorithm) {
    case 'gzip':
      compressed = await gzip(input);
      break;
    case 'brotli':
      compressed = await brotli(input);
      break;
    case 'zstd':
      compressed = await zstd(input);
      break;
  }

  return {
    originalSize: input.length,
    compressedSize: compressed.length,
    ratio: (1 - compressed.length / input.length) * 100,
    algorithm,
  };
}

// Upload both original and compressed versions
async function uploadWithCompression(key: string, data: Buffer): Promise<void> {
  const gzipResult = await compressAsset(data, 'gzip');
  const brotliResult = await compressAsset(data, 'brotli');

  // Choose best compression
  const best = gzipResult.compressedSize < brotliResult.compressedSize ? gzipResult : brotliResult;

  await s3.putObject({
    Bucket: 'assets',
    Key: key,
    Body: data,
    ContentType: 'application/javascript',
  });

  await s3.putObject({
    Bucket: 'assets',
    Key: `${key}.${best.algorithm}`,
    Body: data, // Use compressed version
    ContentType: 'application/javascript',
    ContentEncoding: best.algorithm,
  });
}
```

---

## CDN Optimization

### Cache Hit Ratio

```typescript
// cdn-analytics.ts
interface CDNMetrics {
  cacheHitRatio: number;
  originRequests: number;
  edgeRequests: number;
  bytesTransferred: number;
  originLatency: number;
  edgeLatency: number;
}

function analyzeCDNPerformance(metrics: CDNMetrics): OptimizationRecommendations {
  const recommendations: OptimizationRecommendations = [];

  if (metrics.cacheHitRatio < 0.85) {
    recommendations.push({
      issue: 'Low cache hit ratio',
      current: `${(metrics.cacheHitRatio * 100).toFixed(1)}%`,
      target: '85%+',
      actions: [
        'Increase cache TTL for static assets',
        'Enable query string normalization',
        'Add cache keys for common parameters',
        'Implement stale-while-revalidate',
      ],
    });
  }

  if (metrics.originLatency > 500) {
    recommendations.push({
      issue: 'High origin latency',
      current: `${metrics.originLatency}ms`,
      target: '<200ms',
      actions: [
        'Enable origin shield',
        'Implement stale-while-revalidate',
        'Add more edge locations',
        'Optimize origin response time',
      ],
    });
  }

  return recommendations;
}
```

### Edge Caching Configuration

```typescript
// cloudflare-cache-config.ts
interface CacheConfig {
  ttl: {
    browser: number;      // Client cache
    edge: number;         // CDN cache
  };
  cacheKey: {
    ignoreQueryString: boolean;
    includeHeaders: string[];
    includeCookies: string[];
  };
  staleWhileRevalidate: number;
  bypassCache: string[];  // Cookie names that bypass cache
}

const cacheConfigs: Record<string, CacheConfig> = {
  static: {
    ttl: { browser: 31536000, edge: 31536000 }, // 1 year
    cacheKey: { ignoreQueryString: true, includeHeaders: [], includeCookies: [] },
    staleWhileRevalidate: 86400,
    bypassCache: [],
  },
  api: {
    ttl: { browser: 0, edge: 60 }, // No browser cache, 1 min edge
    cacheKey: {
      ignoreQueryString: false,
      includeHeaders: ['Accept-Language'],
      includeCookies: ['session'], // Vary by user
    },
    staleWhileRevalidate: 300,
    bypassCache: ['admin_session'],
  },
  page: {
    ttl: { browser: 300, edge: 600 },
    cacheKey: {
      ignoreQueryString: false,
      includeHeaders: ['Accept-Language', 'X-Country'],
      includeCookies: [],
    },
    staleWhileRevalidate: 3600,
    bypassCache: ['auth_token'],
  },
};
```

### Cache Invalidation Strategy

```typescript
// cache-invalidation.ts
interface InvalidationRule {
  pattern: string;
  method: 'purge' | 'soft_purge' | 'version_bump';
  scope: 'url' | 'tag' | 'prefix' | 'all';
  propagation: 'immediate' | 'gradual';
}

class CacheInvalidator {
  async invalidateByTag(tags: string[]): Promise<void> {
    // Cloudflare
    await fetch('https://api.cloudflare.com/client/v4/zones/zone_id/purge_cache', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.CF_API_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ tags }),
    });
  }

  async invalidateByPrefix(prefix: string): Promise<void> {
    // Fastly
    await fetch('https://api.fastly.com/service/service_id/purge', {
      method: 'POST',
      headers: {
        'Fastly-Token': process.env.FASTLY_TOKEN,
        'Fastly-Soft-Purge': '1',
      },
      body: JSON.stringify({ surrogate_keys: [prefix] }),
    });
  }

  // Version-based cache busting (recommended for assets)
  versionBustUrl(url: string, version: string): string {
    const separator = url.includes('?') ? '&' : '?';
    return `${url}${separator}v=${version}`;
  }
}
```

---

## Networking Optimization

### Data Transfer Costs

```typescript
// networking-costs.ts
interface DataTransferCost {
  source: string;
  destination: string;
  costPerGB: number;
  monthlyTransferGB: number;
  monthlyCost: number;
}

const awsTransferCosts: DataTransferCost[] = [
  { source: 'EC2', destination: 'Internet', costPerGB: 0.09, monthlyTransferGB: 1000, monthlyCost: 90 },
  { source: 'EC2', destination: 'CloudFront', costPerGB: 0.00, monthlyTransferGB: 1000, monthlyCost: 0 },
  { source: 'S3', destination: 'Internet', costPerGB: 0.09, monthlyTransferGB: 500, monthlyCost: 45 },
  { source: 'S3', destination: 'CloudFront', costPerGB: 0.00, monthlyTransferGB: 500, monthlyCost: 0 },
  { source: 'us-east-1', destination: 'us-west-2', costPerGB: 0.02, monthlyTransferGB: 200, monthlyCost: 4 },
  { source: 'us-east-1', destination: 'eu-west-1', costPerGB: 0.02, monthlyTransferGB: 200, monthlyCost: 4 },
  { source: 'EC2', destination: 'NAT Gateway', costPerGB: 0.045, monthlyTransferGB: 100, monthlyCost: 4.50 },
];

function optimizeNetworkingCosts(config: NetworkConfig): SavingsEstimate {
  const savings: SavingsEstimate = { annualSavings: 0, actions: [] };

  // 1. Use CloudFront for all internet-bound traffic
  savings.actions.push({
    description: 'Route traffic through CloudFront',
    savings: 90 * 12,
    effort: 'low',
  });
  savings.annualSavings += 90 * 12;

  // 2. Use VPC Endpoints instead of NAT Gateway for AWS services
  if (config.usesAwsServices) {
    savings.actions.push({
      description: 'Replace NAT Gateway with VPC Endpoints for S3/DynamoDB',
      savings: 4.50 * 12,
      effort: 'medium',
    });
    savings.annualSavings += 4.50 * 12;
  }

  // 3. Keep traffic within AZ when possible
  savings.actions.push({
    description: 'Use AZ-aware load balancing',
    savings: config.crossAzTrafficGB * 0.01 * 12,
    effort: 'medium',
  });

  return savings;
}
```

### NAT Gateway Alternatives

```yaml
# vpc-endpoints.yaml
# Option 1: VPC Endpoints for AWS services (free)
Resources:
  S3VpcEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub "com.amazonaws.${AWS::Region}.s3"
      VpcEndpointType: Gateway
      RouteTableIds:
        - !Ref PrivateRouteTable

  DynamoDBEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub "com.amazonaws.${AWS::Region}.dynamodb"
      VpcEndpointType: Gateway
      RouteTableIds:
        - !Ref PrivateRouteTable

# Option 2: NAT Instances (cheaper, managed by you)
  NATInstance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t3.micro
      ImageId: ami-xxxx  # NAT AMI
      SourceDestCheck: false
      Tags:
        - Key: Name
          Value: nat-instance

# Option 3: VPC Lattice for internal communication
  ServiceNetwork:
    Type: AWS::VpcLattice::ServiceNetwork
    Properties:
      Name: internal-services
      AuthType: AWS_IAM
```

---

## Caching Optimization

### Redis Cache Hit Ratio

```typescript
// redis-metrics.ts
interface RedisMetrics {
  keyspaceHits: number;
  keyspaceMisses: number;
  cacheHitRatio: number;
  evictedKeys: number;
  memoryUsed: number;
  memoryMax: number;
  connectedClients: number;
}

async function analyzeRedisPerformance(redis: Redis): Promise<OptimizationResult> {
  const info = await redis.info('stats');
  const hits = parseInt(info.match(/keyspace_hits:(\d+)/)?.[1] || '0');
  const misses = parseInt(info.match(/keyspace_misses:(\d+)/)?.[1] || '0');
  const hitRatio = hits / (hits + misses);

  const recommendations: string[] = [];

  if (hitRatio < 0.80) {
    recommendations.push(
      'Cache hit ratio below 80%: Increase TTL, review cache keys, implement prefetching'
    );
  }

  const evicted = parseInt(info.match(/evicted_keys:(\d+)/)?.[1] || '0');
  if (evicted > 100) {
    recommendations.push(
      `High eviction rate (${evicted}): Increase memory or implement LRU eviction policy`
    );
  }

  return { hitRatio, recommendations };
}
```

### Cache Strategies

```typescript
// cache-strategies.ts
type CacheStrategy = 'cache-aside' | 'write-through' | 'write-behind' | 'read-through';

interface CacheConfig<T> {
  strategy: CacheStrategy;
  ttl: number;           // seconds
  maxMemory: number;      // MB
  evictionPolicy: 'allkeys-lru' | 'allkeys-lfu' | 'volatile-ttl';
  serializer: (value: T) => string;
  deserializer: (value: string) => T;
}

// Cache-aside (most common)
class CacheAside<T> {
  async get(key: string, loader: () => Promise<T>): Promise<T> {
    const cached = await this.redis.get(key);
    if (cached) return this.config.deserializer(cached);

    const value = await loader();
    await this.redis.setex(key, this.config.ttl, this.config.serializer(value));
    return value;
  }

  async invalidate(key: string): Promise<void> {
    await this.redis.del(key);
  }
}

// Write-through (data consistency priority)
class WriteThroughCache<T> {
  async set(key: string, value: T): Promise<void> {
    // Write to cache and DB simultaneously
    await Promise.all([
      this.redis.setex(key, this.config.ttl, this.config.serializer(value)),
      this.db.upsert(key, value),
    ]);
  }
}

// Write-behind (performance priority, eventual consistency)
class WriteBehindCache<T> {
  async set(key: string, value: T): Promise<void> {
    // Write to cache immediately, queue DB write
    await this.redis.setex(key, this.config.ttl, this.config.serializer(value));
    await this.writeQueue.push({ key, value, timestamp: Date.now() });
  }
}
```

### TTL Optimization

```typescript
// ttl-optimization.ts
interface TTLRule {
  pattern: string;
  baseTTL: number;        // seconds
  variance: number;       // random variance to prevent thundering herd
  staleWhileRevalidate: number;
}

const ttlRules: TTLRule[] = [
  { pattern: 'user:*', baseTTL: 3600, variance: 300, staleWhileRevalidate: 1800 },
  { pattern: 'product:*', baseTTL: 7200, variance: 600, staleWhileRevalidate: 3600 },
  { pattern: 'category:*', baseTTL: 1800, variance: 180, staleWhileRevalidate: 900 },
  { pattern: 'session:*', baseTTL: 900, variance: 60, staleWhileRevalidate: 0 },
  { pattern: 'rate_limit:*', baseTTL: 60, variance: 0, staleWhileRevalidate: 0 },
  { pattern: 'analytics:*', baseTTL: 300, variance: 30, staleWhileRevalidate: 150 },
];

function calculateTTL(key: string): number {
  for (const rule of ttlRules) {
    if (new RegExp(rule.pattern.replace('*', '.*')).test(key)) {
      const variance = Math.floor(Math.random() * rule.variance);
      return rule.baseTTL + variance;
    }
  }
  return 300; // Default 5 minutes
}
```

---

## Monitoring Costs

### Cloud Billing Alerts

```typescript
// billing-alerts.ts
interface BudgetConfig {
  name: string;
  amount: number;
  currency: string;
  thresholdAlerts: number[]; // % of budget
  notificationEmails: string[];
  snsTopic: string;
}

const budgets: BudgetConfig[] = [
  {
    name: 'Monthly Production Budget',
    amount: 5000,
    currency: 'USD',
    thresholdAlerts: [50, 80, 100],
    notificationEmails: ['finance@example.com', 'ops@example.com'],
    snsTopic: 'arn:aws:sns:us-east-1:account:billing-alerts',
  },
  {
    name: 'Daily Anomaly Detection',
    amount: 200, // Daily average
    currency: 'USD',
    thresholdAlerts: [150], // Alert if 150% of daily average
    notificationEmails: ['ops@example.com'],
    snsTopic: 'arn:aws:sns:us-east-1:account:anomaly-alerts',
  },
];

// AWS Budgets (Terraform)
const awsBudget = {
  name: 'production-monthly',
  budget_type: 'COST',
  limit_amount: '5000',
  limit_unit: 'USD',
  time_period_start: '2024-01-01_00:00',
  time_period_end: '2024-12-31_23:59',
  time_unit: 'MONTHLY',
  notification: [
    {
      comparison_operator: 'GREATER_THAN',
      threshold: 80,
      threshold_type: 'PERCENTAGE',
      notification_type: 'ACTUAL',
      subscriber_email_addresses: ['ops@example.com'],
    },
  ],
};
```

### Cost Allocation Tags

```yaml
# tagging-strategy.yaml
mandatory_tags:
  - key: Environment
    values: [production, staging, development]
  - key: Team
    values: [platform, product, data, security]
  - key: Service
    values: [api, web, worker, database, cache]
  - key: CostCenter
    values: [engineering, marketing, operations]
  - key: Owner
    values: [email of resource owner]

optional_tags:
  - key: Project
  - key: Release
  - key: DataClassification
  - key: AutoShutdown

# AWS Tag Policy (enforced)
# Terraform
tag_policy:
  policy: |
    {
      "tags": {
        "Environment": {
          "enforced_for": ["ec2:instance", "s3:bucket", "rds:db"],
          "allowed_values": ["production", "staging", "development"]
        },
        "Team": {
          "enforced_for": ["*"]
        }
      }
    }
```

### FinOps Practices

```typescript
// finops-practices.ts
interface FinOpsPractice {
  practice: string;
  frequency: 'daily' | 'weekly' | 'monthly';
  owner: string;
  automation: boolean;
}

const finOpsPractices: FinOpsPractice[] = [
  { practice: 'Review daily cost anomalies', frequency: 'daily', owner: 'platform', automation: true },
  { practice: 'Right-size resources based on utilization', frequency: 'weekly', owner: 'sre', automation: true },
  { practice: 'Review reserved instance coverage', frequency: 'monthly', owner: 'finance', automation: false },
  { practice: 'Identify unused resources (orphaned EBS, idle ELBs)', frequency: 'weekly', owner: 'platform', automation: true },
  { practice: 'Optimize database queries based on slow query log', frequency: 'weekly', owner: 'data', automation: true },
  { practice: 'Review and optimize data transfer costs', frequency: 'monthly', owner: 'network', automation: false },
  { practice: 'Evaluate spot instance suitability for workloads', frequency: 'monthly', owner: 'sre', automation: true },
];
```

---

## Third-Party API Costs

### Rate Limiting & Batching

```typescript
// api-cost-optimization.ts
interface APICostConfig {
  provider: string;
  costPerRequest: number;
  freeTier: number;
  rateLimit: number; // requests/minute
  supportsBatching: boolean;
  batchSize: number;
}

const apiConfigs: APICostConfig[] = [
  { provider: 'OpenAI', costPerRequest: 0.002, freeTier: 0, rateLimit: 60, supportsBatching: false, batchSize: 1 },
  { provider: 'SendGrid', costPerRequest: 0.0001, freeTier: 100, rateLimit: 1000, supportsBatching: true, batchSize: 1000 },
  { provider: 'Twilio', costPerRequest: 0.0075, freeTier: 0, rateLimit: 100, supportsBatching: false, batchSize: 1 },
  { provider: 'Stripe', costPerRequest: 0, freeTier: Infinity, rateLimit: 100, supportsBatching: true, batchSize: 100 },
];

class BatchedAPIClient {
  private queue: Request[] = [];
  private timer: NodeJS.Timeout | null = null;
  private readonly batchSize: number;
  private readonly flushInterval: number;

  constructor(batchSize: number = 100, flushInterval: number = 1000) {
    this.batchSize = batchSize;
    this.flushInterval = flushInterval;
  }

  async request(req: Request): Promise<Response> {
    return new Promise((resolve, reject) => {
      this.queue.push({ ...req, resolve, reject });
      if (this.queue.length >= this.batchSize) {
        this.flush();
      } else if (!this.timer) {
        this.timer = setTimeout(() => this.flush(), this.flushInterval);
      }
    });
  }

  private async flush(): Promise<void> {
    if (this.queue.length === 0) return;

    const batch = this.queue.splice(0, this.batchSize);
    this.timer = null;

    try {
      // Single batch request instead of N individual requests
      const response = await this.sendBatch(batch);
      batch.forEach((req, i) => req.resolve(response[i]));
    } catch (error) {
      batch.forEach(req => req.reject(error));
    }
  }
}

// Caching third-party responses
class CachedAPIClient {
  private cache: Map<string, { data: any; expires: number }> = new Map();
  private readonly ttl: number;

  constructor(ttl: number = 300000) { // 5 minutes default
    this.ttl = ttl;
  }

  async request(key: string, fetcher: () => Promise<any>): Promise<any> {
    const cached = this.cache.get(key);
    if (cached && Date.now() < cached.expires) {
      return cached.data;
    }

    const data = await fetcher();
    this.cache.set(key, { data, expires: Date.now() + this.ttl });
    return data;
  }
}
```

---

## Development Environments

### Local Docker Setup

```yaml
# docker-compose.dev.yaml
version: "3.8"

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/dev
      - REDIS_URL=redis://redis:6379
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
    ports:
      - "3000:3000"
    depends_on:
      - db
      - redis
      - localstack

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: dev
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  localstack:
    image: localstack/localstack:latest
    environment:
      - SERVICES=s3,sqs,dynamodb,ses
      - DEFAULT_REGION=us-east-1
    volumes:
      - localstack:/var/lib/localstack
    ports:
      - "4566:4566"

volumes:
  pgdata:
  localstack:
```

### Seed Data Strategy

```typescript
// seed-data.ts
interface SeedConfig {
  environment: string;
  scale: 'minimal' | 'standard' | 'full';
  anonymize: boolean;
  includeFixtures: boolean;
}

async function seedDatabase(config: SeedConfig): Promise<void> {
  const factories = {
    minimal: { users: 10, orders: 50, products: 20 },
    standard: { users: 100, orders: 500, products: 100 },
    full: { users: 1000, orders: 5000, products: 500 },
  };

  const counts = factories[config.scale];

  // Generate deterministic data
  await seedUsers(counts.users);
  await seedProducts(counts.products);
  await seedOrders(counts.orders);

  if (config.includeFixtures) {
    await seedTestAccounts(); // Specific test scenarios
  }
}

// Production-like anonymized data
async function anonymizeProductionData(): Promise<void> {
  // Export subset of production data
  // Anonymize PII (names, emails, addresses)
  // Replace with fake data using faker.js
  // Import into dev database
}
```

---

## Cost Modeling

### TCO Calculation

```typescript
// tco-calculator.ts
interface TCOCalculation {
  compute: number;
  storage: number;
  database: number;
  networking: number;
  cdn: number;
  thirdParty: number;
  labor: number;
  overhead: number;
}

class TCOCalculator {
  calculateMonthlyTCO(inputs: TCOInputs): TCOCalculation {
    const compute = this.calculateCompute(inputs);
    const storage = this.calculateStorage(inputs);
    const database = this.calculateDatabase(inputs);
    const networking = this.calculateNetworking(inputs);
    const cdn = this.calculateCDN(inputs);
    const thirdParty = this.calculateThirdParty(inputs);
    const labor = this.calculateLabor(inputs);
    const overhead = this.calculateOverhead(inputs);

    return {
      compute,
      storage,
      database,
      networking,
      cdn,
      thirdParty,
      labor,
      overhead,
    };
  }

  calculatePerRequestCost(tco: TCOCalculation, requestsPerMonth: number): number {
    const total = Object.values(tco).reduce((a, b) => a + b, 0);
    return total / requestsPerMonth;
  }

  projectScaling(tco: TCOCalculation, growthRate: number, months: number): number[] {
    const projections: number[] = [];
    let currentTCO = Object.values(tco).reduce((a, b) => a + b, 0);

    for (let i = 0; i < months; i++) {
      projections.push(currentTCO);
      currentTCO *= (1 + growthRate);
    }

    return projections;
  }

  calculateROI(currentTCO: number, optimizedTCO: number, investment: number): number {
    const annualSavings = (currentTCO - optimizedTCO) * 12;
    return (annualSavings - investment) / investment;
  }
}
```

### Scaling Projections

```typescript
// scaling-projections.ts
interface ScalingScenario {
  name: string;
  userGrowth: number;      // monthly growth rate
  requestGrowth: number;
  dataGrowth: number;
  optimizationFactor: number; // % of cost saved through optimization
}

const scenarios: ScalingScenario[] = [
  {
    name: 'Conservative',
    userGrowth: 0.05,
    requestGrowth: 0.05,
    dataGrowth: 0.03,
    optimizationFactor: 0.10,
  },
  {
    name: 'Expected',
    userGrowth: 0.15,
    requestGrowth: 0.15,
    dataGrowth: 0.10,
    optimizationFactor: 0.15,
  },
  {
    name: 'Aggressive',
    userGrowth: 0.30,
    requestGrowth: 0.30,
    dataGrowth: 0.20,
    optimizationFactor: 0.20,
  },
];

function projectCosts(baseCost: number, scenario: ScalingScenario, months: number): number[] {
  const costs: number[] = [baseCost];

  for (let i = 1; i < months; i++) {
    const growthFactor = (1 + scenario.requestGrowth) * (1 + scenario.dataGrowth * 0.5);
    const optimizedGrowth = growthFactor * (1 - scenario.optimizationFactor);
    costs.push(costs[i - 1] * optimizedGrowth);
  }

  return costs;
}
```

---

## Code Examples

### Cost-Aware Batching

See [Third-Party API Costs](#third-party-api-costs) section for the BatchedAPIClient implementation.

### Caching Pattern

```typescript
// cost-aware-caching.ts
class CostAwareCache<T> {
  constructor(
    private redis: Redis,
    private computeCost: number,     // cost per computation
    private cacheCost: number,       // cost per cache hit
    private cacheMissCost: number,   // cost per cache miss (fetch + store)
  ) {}

  async get(key: string, ttl: number, fetcher: () => Promise<T>): Promise<T> {
    const cached = await this.redis.get(key);

    if (cached) {
      // Cache hit: cheap
      return JSON.parse(cached);
    }

    // Cache miss: expensive
    const value = await fetcher();
    await this.redis.setex(key, ttl, JSON.stringify(value));
    return value;
  }

  // Only cache if computation cost > cache cost
  shouldCache(computationTimeMs: number): boolean {
    const computationCost = (computationTimeMs / 1000) * this.computeCost;
    return computationCost > this.cacheMissCost;
  }
}
```

### Connection Pooling

```typescript
// connection-pooling.ts
import { Pool } from 'pg';

const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  // Connection pool sizing
  max: 20,                // Maximum connections in pool
  min: 5,                 // Minimum connections to maintain
  idleTimeoutMillis: 10000, // Close idle connections after 10s
  connectionTimeoutMillis: 5000, // Fail if can't connect in 5s
  // Cost optimization: reuse connections
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,
});

// Monitor pool efficiency
pool.on('connect', () => console.log('New connection established'));
pool.on('acquire', () => console.log('Connection acquired from pool'));
pool.on('remove', () => console.log('Connection removed from pool'));

// Health check
async function checkPoolHealth(): Promise<{ total: number; idle: number; waiting: number }> {
  return {
    total: pool.totalCount,
    idle: pool.idleCount,
    waiting: pool.waitingCount,
  };
}
```

### Resource Cleanup

```typescript
// resource-cleanup.ts
class ResourceManager implements AsyncDisposable {
  private resources: Set<{ dispose: () => Promise<void>; name: string }> = new Set();

  async add<T extends { close(): Promise<void> }>(name: string, resource: T): Promise<T> {
    this.resources.add({
      name,
      dispose: () => resource.close(),
    });
    return resource;
  }

  async [Symbol.asyncDispose](): Promise<void> {
    for (const resource of this.resources) {
      try {
        await resource.dispose();
        console.log(`Cleaned up: ${resource.name}`);
      } catch (error) {
        console.error(`Failed to cleanup ${resource.name}:`, error);
      }
    }
  }
}

// Usage
async function handleRequest() {
  await using manager = new ResourceManager();
  const db = await manager.add('database', await createConnection());
  const cache = await manager.add('redis', await createRedisClient());

  // Resources automatically cleaned up on exit
  return processRequest(db, cache);
}
```

---

## Summary

| Area | Key Optimization | Potential Savings |
|------|-----------------|-------------------|
| **Compute** | Reserved instances + Spot for burst | 40-70% |
| **Database** | Read replicas + query optimization | 20-50% |
| **Serverless** | Provisioned concurrency + memory tuning | 15-30% |
| **Storage** | Lifecycle policies + tiering | 50-80% |
| **CDN** | Cache hit ratio optimization | 30-60% |
| **Networking** | VPC endpoints + CloudFront | 20-40% |
| **Caching** | Redis cache hit ratio > 85% | 10-40% |
| **APIs** | Batching + caching + rate limiting | 20-50% |
| **Dev Environments** | Local Docker + seed data | 10-20% |

Cost optimization is an ongoing discipline, not a one-time project. Implement tagging, set budgets, automate right-sizing, and review monthly. The goal is to spend efficiently, not to spend minimally — align cost with business value.
