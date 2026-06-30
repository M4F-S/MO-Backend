# API Gateway Reference

## Table of Contents
1. [Why Use an API Gateway](#why-use-an-api-gateway)
2. [Kong](#kong)
3. [Nginx](#nginx)
4. [Traefik](#traefik)
5. [AWS API Gateway](#aws-api-gateway)
6. [Cloudflare](#cloudflare)
7. [Envoy](#envoy)
8. [API Key Management](#api-key-management)
9. [Request/Response Transformation](#requestresponse-transformation)
10. [GraphQL Federation](#graphql-federation)
11. [Rate Limiting at Edge](#rate-limiting-at-edge)

---

## Why Use an API Gateway

An API Gateway acts as a single entry point for all client requests to backend services.

**Benefits:**
- **Single Entry Point:** Clients call one URL; routing happens internally
- **SSL Termination:** TLS handled at the edge; backends communicate over HTTP
- **Rate Limiting:** Protect backends from traffic spikes and abuse
- **Authentication:** Verify JWTs, API keys, or OAuth tokens before forwarding
- **Routing:** Path-based, host-based, or header-based routing to services
- **Load Balancing:** Distribute traffic across healthy instances
- **Caching:** Reduce backend load by caching responses at the edge
- **Observability:** Centralized logging, metrics, and tracing for all API traffic

---

## Kong

### Installation

```bash
# Docker
docker run -d --name kong \
  -e "KONG_DATABASE=off" \
  -e "KONG_DECLARATIVE_CONFIG=/kong/declarative/kong.yml" \
  -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
  -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
  -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
  -p 8000:8000 \
  -p 8443:8443 \
  -p 8001:8001 \
  -p 8444:8444 \
  kong:latest
```

### Declarative Configuration

```yaml
# kong.yml
_format_version: "3.0"

services:
  - name: user-service
    url: http://user-service:3000
    routes:
      - name: user-routes
        paths:
          - /api/users
        strip_path: false
    plugins:
      - name: rate-limiting
        config:
          minute: 100
          policy: local
      - name: jwt
        config:
          uri_param_names: []
          cookie_names: []
          key_claim_name: iss
          claims_to_verify:
            - exp
      - name: cors
        config:
          origins:
            - "https://app.example.com"
          methods:
            - GET
            - POST
            - PUT
            - DELETE
          headers:
            - Authorization
            - Content-Type
          max_age: 3600
          credentials: true
      - name: proxy-cache
        config:
          content_type:
            - "application/json; charset=utf-8"
          cache_ttl: 300
          strategy: memory
```

### Admin API

```bash
# Create a service
curl -X POST http://localhost:8001/services \
  --data "name=order-service" \
  --data "url=http://order-service:3000"

# Add a route
curl -X POST http://localhost:8001/services/order-service/routes \
  --data "name=order-routes" \
  --data "paths[]=/api/orders"

# Enable rate limiting
curl -X POST http://localhost:8001/services/order-service/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=60" \
  --data "config.policy=redis" \
  --data "config.redis_host=redis"
```

---

## Nginx

### Reverse Proxy + Load Balancing

```nginx
# /etc/nginx/nginx.conf
http {
    upstream backend {
        least_conn;  # Load balancing method
        server app1:3000 weight=5;
        server app2:3000 weight=5;
        server app3:3000 backup;

        keepalive 32;
    }

    server {
        listen 80;
        server_name api.example.com;

        location / {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_connect_timeout 5s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }
    }
}
```

### Rate Limiting with `limit_req`

```nginx
http {
    # Define a zone: 10MB, rate 10r/s
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $api_key zone=api_key_limit:10m rate=100r/m;

    server {
        listen 80;
        server_name api.example.com;

        location /api/ {
            # Burst of 20, nodelay for immediate processing within burst
            limit_req zone=api_limit burst=20 nodelay;
            limit_req_status 429;
            limit_req_log_level warn;

            proxy_pass http://backend;
        }

        location /api/premium/ {
            limit_req zone=api_key_limit burst=50 nodelay;
            proxy_pass http://backend;
        }
    }
}
```

### SSL + Health Checks

```nginx
server {
    listen 443 ssl http2;
    server_name api.example.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    location /api/ {
        proxy_pass http://backend;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_next_upstream_tries 2;
    }
}
```

---

## Traefik

### Docker Integration with Auto-Discovery

```yaml
# docker-compose.yml
version: "3.8"

services:
  traefik:
    image: traefik:v3.0
    command:
      - --api.dashboard=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.email=admin@example.com
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --ping=true
      - --metrics.prometheus=true
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`dashboard.example.com`)"
      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=auth@docker"
      - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$H6uskkk7$$IgXLP6ewTrSuBkTrqE8wj/"

  api:
    image: my-api:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.example.com`)"
      - "traefik.http.routers.api.entrypoints.websecure"
      - "traefik.http.routers.api.tls.certresolver=letsencrypt"
      - "traefik.http.services.api.loadbalancer.server.port=3000"
      - "traefik.http.routers.api.middlewares=api-ratelimit,api-cors"
      - "traefik.http.middlewares.api-ratelimit.ratelimit.average=100"
      - "traefik.http.middlewares.api-ratelimit.ratelimit.burst=50"
      - "traefik.http.middlewares.api-cors.headers.accesscontrolallowmethods=GET,POST,PUT,DELETE"
      - "traefik.http.middlewares.api-cors.headers.accesscontrolalloworiginlist=https://app.example.com"
      - "traefik.http.middlewares.api-cors.headers.accesscontrolallowheaders=Authorization,Content-Type"
      - "traefik.http.middlewares.api-cors.headers.accesscontrolmaxage=3600"
```

### Middleware Chain

```yaml
labels:
  - "traefik.http.middlewares.secure-headers.headers.framedeny=true"
  - "traefik.http.middlewares.secure-headers.headers.browserxssfilter=true"
  - "traefik.http.middlewares.secure-headers.headers.stsseconds=31536000"
  - "traefik.http.middlewares.secure-headers.headers.stsincludeSubdomains=true"
  - "traefik.http.middlewares.compress.compress=true"
  - "traefik.http.routers.api.middlewares=secure-headers,compress,api-ratelimit"
```

---

## AWS API Gateway

### REST API (Terraform)

```hcl
resource "aws_api_gateway_rest_api" "api" {
  name = "production-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_method" "users_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
  api_key_required = true
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"

  # Throttling
  method_settings {
    method_path = "*/*"
    throttling_burst_limit = 1000
    throttling_rate_limit  = 500
  }

  # Caching
  method_settings {
    method_path = "users/GET"
    caching_enabled = true
    cache_ttl_in_seconds = 300
    require_cache_authorization = false
  }
}

# Custom domain
resource "aws_api_gateway_domain_name" "api" {
  domain_name = "api.example.com"
  regional_certificate_arn = aws_acm_certificate_validation.api.certificate_arn
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}
```

### HTTP API (Simpler, cheaper)

```hcl
resource "aws_apigatewayv2_api" "http_api" {
  name          = "http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://app.example.com"]
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["Authorization", "Content-Type"]
    max_age       = 86400
  }
}
```

### WebSocket API

```hcl
resource "aws_apigatewayv2_api" "websocket" {
  name                       = "websocket-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.websocket_handler.invoke_arn
}
```

---

## Cloudflare

### API Shield

```hcl
# Terraform - Cloudflare API Shield
resource "cloudflare_api_shield" "api_shield" {
  zone_id = var.zone_id
}

resource "cloudflare_api_shield_schema" "api_schema" {
  zone_id = var.zone_id
  name    = "api-schema"
  kind    = "openapi"
  source  = file("openapi.yaml")
}

resource "cloudflare_api_shield_operation" "protected_operations" {
  zone_id  = var.zone_id
  method   = "GET"
  host     = "api.example.com"
  endpoint = "/api/users"
}
```

### Rate Limiting Rules

```hcl
resource "cloudflare_ruleset" "rate_limiting" {
  zone_id = var.zone_id
  name    = "rate limiting rules"
  kind    = "zone"
  phase   = "http_ratelimit"

  rules {
    action = "block"
    expression = "(http.request.uri.path contains \"/api/\")"
    description = "API rate limiting"
    action_parameters {
      response {
        status_code = 429
        content     = "Rate limit exceeded"
        content_type = "text/plain"
      }
    }
    ratelimit {
      characteristics = ["cf.colo.id", "ip.src"]
      period = 60
      requests_per_period = 100
      mitigation_timeout = 600
      counting_expression = "(http.request.uri.path contains \"/api/\")"
    }
  }
}
```

### WAF + Caching

```hcl
resource "cloudflare_ruleset" "waf" {
  zone_id = var.zone_id
  name    = "WAF rules"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules {
    action = "block"
    expression = "(http.request.uri.path contains \"/admin\") and not (ip.src in $admin_ips)"
    description = "Block admin access from non-admin IPs"
  }
}

resource "cloudflare_page_rule" "api_cache" {
  zone_id = var.zone_id
  target  = "api.example.com/api/*"
  actions {
    cache_level    = "cache_everything"
    edge_cache_ttl = 300
  }
}
```

---

## Envoy

### Service Mesh Configuration

```yaml
# envoy.yaml
static_resources:
  listeners:
    - name: main_listener
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 8080
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: ingress_http
                codec_type: AUTO
                route_config:
                  name: api_route
                  virtual_hosts:
                    - name: api
                      domains:
                        - "api.example.com"
                      routes:
                        - match:
                            prefix: "/api/users"
                          route:
                            cluster: user_service
                            timeout: 5s
                            retry_policy:
                              retry_on: "5xx,connect-failure"
                              num_retries: 3
                              per_try_timeout: 2s
                        - match:
                            prefix: "/api/orders"
                          route:
                            cluster: order_service
                http_filters:
                  - name: envoy.filters.http.router
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

  clusters:
    - name: user_service
      connect_timeout: 5s
      type: STRICT_DNS
      lb_policy: ROUND_ROBIN
      load_assignment:
        cluster_name: user_service
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: user-service
                      port_value: 3000
      health_checks:
        - timeout: 5s
          interval: 10s
          unhealthy_threshold: 2
          healthy_threshold: 2
          http_health_check:
            path: "/health"
      circuit_breakers:
        thresholds:
          - max_connections: 1000
            max_pending_requests: 500
            max_requests: 500
            max_retries: 3

    - name: order_service
      connect_timeout: 5s
      type: STRICT_DNS
      lb_policy: LEAST_REQUEST
      load_assignment:
        cluster_name: order_service
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: order-service
                      port_value: 3000

admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9901
```

### Observability with Envoy

```yaml
tracing:
  http:
    name: envoy.tracers.zipkin
    typed_config:
      "@type": type.googleapis.com/envoy.config.trace.v3.ZipkinConfig
      collector_cluster: zipkin
      collector_endpoint: "/api/v2/spans"
      collector_endpoint_version: HTTP_JSON

stats_sinks:
  - name: envoy.stat_sinks.prometheus
    typed_config:
      "@type": type.googleapis.com/envoy.config.metrics.v3.PrometheusSink
```

---

## API Key Management

### Key Generation & Rotation

```typescript
// api-key-service.ts
import { randomBytes, createHmac } from 'crypto';
import { Redis } from 'ioredis';

interface ApiKey {
  id: string;
  key: string;       // Hashed key for storage
  prefix: string;    // First 8 chars for display
  scopes: string[];
  rateLimit: number;
  expiresAt: Date;
  lastRotatedAt: Date;
}

class ApiKeyManager {
  private redis: Redis;
  private readonly KEY_PREFIX = 'apikey:';
  private readonly HASH_SECRET: string;

  constructor(redis: Redis, hashSecret: string) {
    this.redis = redis;
    this.HASH_SECRET = hashSecret;
  }

  generateKey(): { key: string; prefix: string } {
    const rawKey = randomBytes(32).toString('base64url');
    const prefix = rawKey.slice(0, 8);
    const key = `mo_${rawKey}`;  // Add prefix for identification
    return { key, prefix };
  }

  hashKey(key: string): string {
    return createHmac('sha256', this.HASH_SECRET).update(key).digest('hex');
  }

  async createKey(scopes: string[], rateLimit: number): Promise<{ id: string; plainKey: string }> {
    const id = randomBytes(16).toString('hex');
    const { key, prefix } = this.generateKey();
    const hashedKey = this.hashKey(key);

    const apiKey: ApiKey = {
      id,
      key: hashedKey,
      prefix,
      scopes,
      rateLimit,
      expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000), // 90 days
      lastRotatedAt: new Date(),
    };

    await this.redis.setex(
      `${this.KEY_PREFIX}${id}`,
      90 * 24 * 60 * 60,
      JSON.stringify(apiKey)
    );

    return { id, plainKey: key };
  }

  async validateKey(key: string): Promise<ApiKey | null> {
    const prefix = key.slice(0, 8);
    const hashedKey = this.hashKey(key);

    // Scan for matching prefix (in production, use index)
    const keys = await this.redis.keys(`${this.KEY_PREFIX}*`);
    for (const storedKey of keys) {
      const data = await this.redis.get(storedKey);
      if (!data) continue;
      const apiKey: ApiKey = JSON.parse(data);
      if (apiKey.prefix === prefix && apiKey.key === hashedKey) {
        return apiKey;
      }
    }
    return null;
  }

  async rotateKey(id: string): Promise<{ newKey: string } | null> {
    const existing = await this.redis.get(`${this.KEY_PREFIX}${id}`);
    if (!existing) return null;

    const apiKey: ApiKey = JSON.parse(existing);
    const { key, prefix } = this.generateKey();
    apiKey.key = this.hashKey(key);
    apiKey.prefix = prefix;
    apiKey.lastRotatedAt = new Date();

    await this.redis.setex(
      `${this.KEY_PREFIX}${id}`,
      90 * 24 * 60 * 60,
      JSON.stringify(apiKey)
    );

    return { newKey: key };
  }

  async recordUsage(keyId: string, endpoint: string): Promise<void> {
    const timestamp = Date.now();
    await this.redis.zadd(`apikey:usage:${keyId}`, timestamp, `${endpoint}:${timestamp}`);
    await this.redis.expire(`apikey:usage:${keyId}`, 30 * 24 * 60 * 60); // 30 days
  }
}
```

---

## Request/Response Transformation

### Header Manipulation (Nginx)

```nginx
server {
    location /api/ {
        # Remove sensitive headers from upstream
        proxy_hide_header X-Powered-By;
        proxy_hide_header Server;

        # Add custom headers
        add_header X-Request-ID $request_id always;
        add_header X-Cache-Status $upstream_cache_status always;

        # Set headers for backend
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Client-Version $http_x_client_version;

        proxy_pass http://backend;
    }
}
```

### Body Transformation (Kong)

```bash
# Enable request transformer
curl -X POST http://localhost:8001/services/my-service/plugins \
  --data "name=request-transformer" \
  --data "config.add.headers=X-Source:API-Gateway" \
  --data "config.add.querystring=version:v1" \
  --data "config.remove.headers=X-Internal-Token" \
  --data "config.replace.body=$(body)" \
  --data "config.rename.body=user:customer"
```

### Protocol Conversion (Envoy)

```yaml
# gRPC to HTTP JSON transcoding
http_filters:
  - name: envoy.filters.http.grpc_json_transcoder
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.http.grpc_json_transcoder.v3.GrpcJsonTranscoder
      proto_descriptor: /etc/envoy/proto.pb
      services:
        - user.UserService
        - order.OrderService
      print_options:
        add_whitespace: true
        always_print_primitive_fields: true
        always_print_enums_as_ints: false
      match_incoming_request_route: false
  - name: envoy.filters.http.router
```

---

## GraphQL Federation

### Apollo Gateway

```typescript
// gateway.ts
import { ApolloGateway, IntrospectAndCompose } from '@apollo/gateway';
import { ApolloServer } from 'apollo-server';

const gateway = new ApolloGateway({
  supergraphSdl: new IntrospectAndCompose({
    subgraphs: [
      { name: 'users', url: 'http://user-service:4001/graphql' },
      { name: 'orders', url: 'http://order-service:4002/graphql' },
      { name: 'products', url: 'http://product-service:4003/graphql' },
    ],
  }),
  // Caching at gateway level
  buildService({ name, url }) {
    return new RemoteGraphQLDataSource({
      url,
      willSendRequest({ request, context }) {
        request.http.headers.set('x-user-id', context.userId);
      },
    });
  },
});

const server = new ApolloServer({
  gateway,
  subscriptions: false,
  context: ({ req }) => {
    return { userId: req.headers['x-user-id'] };
  },
});

server.listen({ port: 4000 }).then(({ url }) => {
  console.log(`Gateway ready at ${url}`);
});
```

### Schema Stitching (Alternative)

```typescript
// stitched-gateway.ts
import { stitchSchemas } from '@graphql-tools/stitch';
import { delegateToSchema } from '@graphql-tools/delegate';

const userSchema = await loadSchema('http://user-service:4001/graphql');
const orderSchema = await loadSchema('http://order-service:4002/graphql');

const gatewaySchema = stitchSchemas({
  subschemas: [
    { schema: userSchema, batch: true },
    { schema: orderSchema, batch: true },
  ],
  typeDefs: `
    extend type User {
      orders: [Order]
    }
  `,
  resolvers: {
    User: {
      orders: {
        selectionSet: '{ id }',
        resolve(user, _args, context, info) {
          return delegateToSchema({
            schema: orderSchema,
            operation: 'query',
            fieldName: 'ordersByUserId',
            args: { userId: user.id },
            context,
            info,
          });
        },
      },
    },
  },
});
```

### Entity Resolution

```graphql
# User subgraph
extend type User @key(fields: "id") {
  id: ID!
  name: String!
  email: String!
}

# Order subgraph
extend type Order @key(fields: "id") {
  id: ID!
  user: User! @provides(fields: "id")
  total: Float!
}

# In Order service resolver
const resolvers = {
  Order: {
    user(order) {
      return { __typename: 'User', id: order.userId };
    },
  },
};
```

---

## Rate Limiting at Edge

### Token Bucket (Redis Lua)

```lua
-- rate_limiter.lua
-- KEYS[1]: rate limit key
-- KEYS[2]: lock key
-- ARGV[1]: capacity (max tokens)
-- ARGV[2]: refill rate (tokens per second)
-- ARGV[3]: now (timestamp in ms)
-- ARGV[4]: cost (default 1)

local bucket = redis.call('HMGET', KEYS[1], 'tokens', 'last_refill')
local capacity = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local cost = tonumber(ARGV[4]) or 1

local tokens = capacity
local last_refill = now

if bucket[1] then
    tokens = tonumber(bucket[1])
    last_refill = tonumber(bucket[2])
    local elapsed = (now - last_refill) / 1000.0
    tokens = math.min(capacity, tokens + elapsed * refill_rate)
end

if tokens >= cost then
    tokens = tokens - cost
    redis.call('HMSET', KEYS[1], 'tokens', tokens, 'last_refill', now)
    redis.call('EXPIRE', KEYS[1], math.ceil(capacity / refill_rate) + 1)
    return {1, tokens}
else
    redis.call('HMSET', KEYS[1], 'tokens', tokens, 'last_refill', now)
    redis.call('EXPIRE', KEYS[1], math.ceil(capacity / refill_rate) + 1)
    return {0, tokens}
end
```

```typescript
// Redis rate limiter implementation
import Redis from 'ioredis';
import { readFileSync } from 'fs';

class TokenBucketLimiter {
  private redis: Redis;
  private scriptSha: string;

  constructor(redis: Redis) {
    this.redis = redis;
  }

  async init(): Promise<void> {
    const script = readFileSync('./rate_limiter.lua', 'utf-8');
    this.scriptSha = await this.redis.script('LOAD', script);
  }

  async check(key: string, capacity: number, refillRate: number, cost: number = 1): Promise<{ allowed: boolean; remaining: number }> {
    const now = Date.now();
    const result = await this.redis.evalsha(
      this.scriptSha,
      1,
      `ratelimit:${key}`,
      capacity,
      refillRate,
      now,
      cost
    ) as [number, number];

    return {
      allowed: result[0] === 1,
      remaining: result[1],
    };
  }
}
```

### Sliding Window Counter

```typescript
// sliding-window.ts
class SlidingWindowLimiter {
  private redis: Redis;
  private windowSize: number; // seconds

  constructor(redis: Redis, windowSize: number = 60) {
    this.redis = redis;
    this.windowSize = windowSize;
  }

  async isAllowed(key: string, limit: number): Promise<{ allowed: boolean; remaining: number; resetAt: number }> {
    const now = Date.now();
    const windowStart = now - (this.windowSize * 1000);
    const redisKey = `sliding:${key}`;

    const pipeline = this.redis.pipeline();
    // Remove entries outside the window
    pipeline.zremrangebyscore(redisKey, 0, windowStart);
    // Count entries in current window
    pipeline.zcard(redisKey);
    // Add current request
    pipeline.zadd(redisKey, now, `${now}:${Math.random()}`);
    // Set expiry
    pipeline.pexpire(redisKey, this.windowSize * 1000);

    const results = await pipeline.exec();
    const currentCount = results[1][1] as number;

    const allowed = currentCount < limit;
    const remaining = Math.max(0, limit - currentCount - 1);
    const resetAt = now + (this.windowSize * 1000);

    return { allowed, remaining, resetAt };
  }
}
```

### Per-Key Rate Limits (Kong-style)

```yaml
# Per-consumer, per-endpoint limits
services:
  - name: api
    plugins:
      - name: rate-limiting-advanced
        config:
          limit:
            - 100
            - 200
          window_size:
            - 60
            - 3600
          identifier: consumer
          strategy: redis
          redis:
            host: redis
            port: 6379
            timeout: 2000
          # Different limits per endpoint
          config:
            - path: /api/expensive
              limit: 10
              window_size: 60
            - path: /api/cheap
              limit: 1000
              window_size: 60
```

---

## Summary

| Gateway        | Best For                          | Key Strengths                              |
|----------------|-----------------------------------|--------------------------------------------|
| Kong           | Enterprise, plugin ecosystem        | Rich plugins, declarative config, Lua      |
| Nginx          | High-performance, simple setups     | Proven, fast, extensive module system      |
| Traefik        | Cloud-native, Docker/K8s           | Auto-discovery, modern, Let's Encrypt      |
| AWS API Gateway| Serverless, AWS ecosystem            | Deep AWS integration, throttling, caching  |
| Cloudflare     | Edge security, DDoS protection      | Global edge, API Shield, WAF               |
| Envoy          | Service mesh, microservices           | Advanced load balancing, observability     |

Choose based on your infrastructure, team expertise, and specific requirements for rate limiting, auth, and observability.
