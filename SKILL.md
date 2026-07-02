---
name: MO-Backend
description: Expert backend engineering for web APIs and server systems. Use when designing databases, building REST/GraphQL APIs, implementing auth (JWT/OAuth), integrating payments (Stripe), setting up real-time systems, or deploying with Docker. Triggers on backend, API, database, auth, server, microservices, PostgreSQL, Redis, webhook, CI/CD.
---

# MO-Backend — Expert Backend Engineering

Design and build production-grade web application backends. Covers architecture decisions, database design, API development, authentication, security, integrations, real-time systems, DevOps, testing, and full-stack coordination with `MO-Frontend`.

## What This Skill Covers

- Database design (PostgreSQL, MongoDB, ORM selection, migrations, optimization)
- API development (REST, GraphQL, gRPC, tRPC, WebSocket, SSE)
- Authentication & authorization (JWT, OAuth, RBAC, ABAC, MFA, BOLA prevention)
- Security (OWASP Top 10, input validation, rate limiting, SQL injection prevention)
- Integrations (Stripe payments, email queues, file storage, search, webhooks)
- Real-time systems (WebSocket, SSE, Socket.io, Redis Pub/Sub, presence)
- DevOps (Docker, CI/CD, GitOps, monitoring, logging, alerting)
- Testing (unit, integration, contract, security, performance, E2E)
- Full-stack coordination with `MO-Frontend`

## What This Skill Does NOT Cover

- **Frontend development** (React, CSS, animations, UI/UX) — use `MO-Frontend` skill
- **Mobile app development** (React Native, Flutter, native iOS/Android) — use dedicated mobile skill
- **AI/ML model training** (PyTorch, TensorFlow, model fine-tuning) — use dedicated ML skill
- **Blockchain / smart contracts** (Solidity, Web3, DeFi) — outside scope
- **Embedded systems / IoT firmware** (Arduino, Raspberry Pi, C/C++ embedded) — outside scope
- **Desktop application backends** (Electron, Tauri server logic) — outside scope
- **Game server architecture** (Unity networking, Unreal dedicated servers) — outside scope
- **Legacy system maintenance** (COBOL, mainframe, AS/400) — outside scope

## Full-Stack Integration with MO-Frontend

When building full-stack applications, coordinate with `MO-Frontend`:

| Backend Need | Frontend Coordination | See MO-Frontend |
|-------------|----------------------|-----------------|
| API design | Design for frontend consumption (BFF, GraphQL, tRPC) | `api-integration.md` |
| Auth (JWT, OAuth) | Token storage, refresh flow, interceptors | `SKILL.md` (state management section) |
| CORS config | Per-environment allowlist | `SKILL.md` (full-stack section) |
| Real-time events | SSE/WebSocket client setup | `animations.md`, `api-integration.md` |
| File uploads | Presigned URL generation | `api-integration.md` |
| Shared types | Generate TypeScript from OpenAPI/Prisma | `SKILL.md` (full-stack section) |
| Search API | Full-text search endpoints | `api-integration.md` |
| Deployment | Monorepo, shared CI/CD, env vars | `SKILL.md` (full-stack section) |

**Shared patterns:**
- Generate TypeScript types from OpenAPI spec or Prisma schema (`scripts/generate-shared-types.sh`)
- Use `httpOnly` cookies for auth tokens (not `localStorage`) — coordinated with frontend
- CORS: `localhost:3000` (dev), `*.vercel.app` (staging), `yourdomain.com` (prod)
- Deploy backend to Railway/Render/Fly.io, frontend to Vercel/Netlify — keep in same monorepo
- Next.js API routes: use for server-side logic, BFF patterns, and auth middleware
- tRPC: full-stack type safety with zero codegen — best for Next.js monorepos
- GraphQL: flexible queries for mobile apps and complex UIs — use `dataloader` for N+1
- REST: standard for public APIs, easiest caching, CDN-friendly

## Obsidian Memory Layer

When working on projects, persist knowledge to the Obsidian vault for cross-session recall. Coordinate with the `mo-graphify-obsidian-memory` skill.

### Vault Location
- **Per-project:** `{project-root}/obsidian/` or `~/Vaults/{project-name}/wiki/`
- **General fallback:** `~/Vaults/general/wiki/`
- Create the vault directory if it doesn't exist

### What to Store
- **Architecture decisions:** Database choice, API style, auth strategy, microservices vs monolith
- **API contracts:** OpenAPI spec, endpoint documentation, error codes, versioning strategy
- **Database schema notes:** ER diagram, index strategy, migration history, query patterns
- **Security decisions:** Auth flow, rate limiting tiers, CORS config, secrets management
- **Integration notes:** Stripe webhooks, email queues, third-party API credentials, error handling
- **Deployment notes:** Docker config, CI/CD pipeline, environment variables, rollback procedures

### Note Types & Naming

| Note Type | Naming Pattern | Content |
|-----------|---------------|---------|
| **Backend MOC** | `[[Project Name — Backend]]` | Hub note linking all backend decisions |
| **API Contract** | `[[Project Name — API Contract]]` | OpenAPI spec, endpoint mapping, error codes |
| **Database Schema** | `[[Project Name — Database Schema]]` | ER diagram, indexes, migrations, query patterns |
| **Security Config** | `[[Project Name — Security]]` | Auth flow, rate limiting, CORS, secrets |
| **ADR** | `[[Project Name — ADR-001 Topic]]` | Architecture Decision Record (DB, API style, auth) |
| **Integration Log** | `[[Project Name — Integrations]]` | Stripe, email, search, storage, webhooks |

### Linking Pattern
```markdown
<!-- In [[Project Name — Backend]] MOC -->
## Decisions
- [[Project Name — Database Schema]]
- [[Project Name — API Contract]]
- [[Project Name — Security]]

## Frontend Coordination
- [[Project Name — Frontend]]
- [[Project Name — Frontend API Contract]]
```

### Quick Operations
```python
# Create a backend MOC
create_moc(
    title="Project Name — Backend",
    description="Backend architecture and API decisions for Project Name.",
    related_notes=["Project Name — Database Schema", "Project Name — API Contract", "Project Name — Security"]
)

# Store an architecture decision
create_note(
    title="Project Name — ADR-002 Auth Strategy",
    content="Decision: Use JWT (RS256) with refresh token rotation in httpOnly cookies.\n\nRationale: Stateless API, XSS-resistant token storage, automatic expiry.\n\nStatus: accepted\n\nAlternatives considered: OAuth 2.1 (too complex for MVP), session cookies (requires sticky sessions).",
    tags=["backend", "decision", "auth", "security"],
    note_type="decision",
    links=["Project Name — Backend", "Project Name — Security"]
)
```

### Cross-Skill Linking
- Always link backend MOC to frontend MOC: `[[Project Name — Frontend]]`
- Link API contract to frontend API integration: `[[Project Name — Frontend API Contract]]`
- Tag all notes with `["backend", "project-name"]` for filtering

## 8-Step Backend Workflow

### Step 1: Define Data Model
- Identify entities, relationships, and access patterns
- Choose PostgreSQL as default; use MongoDB only for unstructured data
- Design schema with normalized tables + JSONB for flexibility
- Add indexes for query paths before they become bottlenecks
- See **databases.md** for schema design, ORM selection, migration strategies

### Step 2: Design API Contract
- Define resource-oriented REST endpoints or GraphQL schema
- Document with OpenAPI/Swagger or GraphQL SDL
- Version from day one: `/v1/` prefix, never break existing clients
- Choose pagination: cursor-based for large datasets, offset for small
- Add rate limiting headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `Retry-After`
- See **apis.md** for REST conventions, GraphQL decisions, pagination, versioning

### Step 3: Implement Authentication
- Use JWT for stateless APIs; OAuth 2.1 + OIDC for third-party/SSO
- Short-lived access tokens (5–15 min) + refresh token rotation
- Store refresh tokens in `httpOnly`, `Secure`, `SameSite=Strict` cookies
- Implement RBAC at route level; ABAC for complex rules
- Coordinate with frontend: `httpOnly` cookies, not `localStorage`
- See **auth.md** for JWT, OAuth, RBAC, session patterns, BOLA prevention

### Step 4: Build Core API Routes
- Validate all input with Zod (TypeScript) or Pydantic (Python) — `.strict()` mode
- Use parameterized queries or ORM — never string concatenation
- Return consistent error shapes: `{ error: string, code: string, details?: any }`
- Add request ID logging and correlation IDs for tracing
- Never expose stack traces or SQL details to clients
- See **apis.md** for route patterns, error handling, middleware patterns

### Step 5: Add Caching
- Implement cache-aside pattern with Redis for read-heavy workloads
- Cache at API response level and database query level
- Invalidate on write; use pattern invalidation for list caches
- Prevent cache stampede: lock-based recomputation, probabilistic early expiration
- See **databases.md** for caching patterns, Redis setup, connection pooling

### Step 6: Integrate External Services
- Queue all side effects: email, notifications, file processing, search indexing
- Use Stripe for payments with idempotency keys and webhook signature verification
- Use S3 or R2 for file storage; Cloudflare R2 for zero-egress media delivery
- Send emails via queued workers (BullMQ/Celery + Resend/SendGrid)
- See **integrations.md** for payments, email, storage, search, webhooks

### Step 7: Add Real-Time (if needed)
- Use SSE for server→client events: notifications, AI streaming, live logs, dashboards
- Use WebSocket only for bidirectional: chat, gaming, collaborative editing
- Scale WebSocket with Redis Pub/Sub adapter for cross-server routing
- Implement presence with TTL heartbeat, message ordering with sequence numbers
- See **realtime.md** for WebSocket scaling, SSE, presence, message ordering

### Step 8: Deploy & Monitor
- Containerize with multi-stage Docker; never use `latest` tag
- Use Docker Compose for local; GitOps (ArgoCD) for production Kubernetes
- CI/CD: test → build → security scan → push → deploy with GitHub Actions
- Observability: Pino structured logging + Prometheus metrics + health checks
- Set up alerting: PagerDuty/Opsgenie for critical errors, Slack for warnings
- See **devops.md** for Docker, CI/CD, monitoring, alerting, GitOps

### Step 9: Post-Deploy & Iterate (Critical — Don't Skip)
- Monitor error rates, latency percentiles, and throughput for 48 hours post-deploy
- Have rollback plan: blue-green deployment or quick revert to previous image
- Run security checklist against production: `bash scripts/security-checklist.sh https://api.yourdomain.com`
- Monitor database connection pool, replication lag, slow query log
- Review API usage analytics: identify hot endpoints, optimize queries
- Iterate based on frontend feedback: API ergonomics, missing endpoints, performance issues

## NOT-DO Guardrails

- **Don't use microservices** for teams < 15 or projects < 6 months old — start with modular monolith
- **Don't skip input validation** on any endpoint — even internal ones, even health checks
- **Don't store JWT secrets** in code or environment variables — use HashiCorp Vault, Doppler, or AWS Secrets Manager
- **Don't use MongoDB** for financial transactions, multi-table joins, or strict consistency requirements
- **Don't commit `.env` files** to Git — use `.env.example` with dummy values
- **Don't ignore database connection limits** — always use pooling (PgBouncer, Prisma Accelerate)
- **Don't deploy without running the security checklist** — `scripts/security-checklist.sh`
- **Don't skip API versioning** from day one — add `/v1/` to all routes, plan for deprecation
- **Don't use `SELECT *`** in production queries — specify columns explicitly to reduce bandwidth and breakage on schema changes
- **Don't trust webhook signatures** without verification — verify HMAC for every webhook
- **Don't skip rate limiting** on public endpoints — tiered: login (5/15min), read (100/1min), write (30/1min)
- **Don't expose stack traces** or SQL errors to API clients — log full details server-side, send minimal safe info
- **Don't use `eval()`** or dynamic code execution on user input — instant security vulnerability
- **Don't deserialize untrusted data** without schema validation — use Zod/Pydantic for all inputs
- **Don't run user-provided SQL** — always use parameterized queries or ORM
- **Don't skip HTTPS** in any environment — TLS 1.3 minimum, HSTS headers
- **Don't use `*` in CORS** in production with credentials — explicit allowlist only
- **Don't store passwords in plain text** — bcrypt with cost factor ≥ 12, Argon2id preferred
- **Don't skip MFA** for admin accounts, sensitive operations, or financial transactions
- **Don't ignore dependency vulnerabilities** — Trivy/Snyk/Dependabot in CI/CD pipeline
- **Don't test migrations on production first** — always test on staging with production-like data
- **Don't skip database backups** before major migrations or schema changes
- **Don't hardcode API keys** — use environment variables or vaults, rotate regularly
- **Don't ignore slow queries** — `EXPLAIN ANALYZE` and add indexes before they become bottlenecks
- **Don't use `autoIncrement` integer IDs** for public-facing APIs — use UUID v7 for security and sharding
- **Don't skip idempotency** on mutation endpoints — require `Idempotency-Key` for POST/PUT/PATCH
- **Don't ignore replication lag** — route critical reads to primary, use sticky reads for user sessions
- **Don't use synchronous external calls** in request path — queue all side effects (email, webhooks, indexing)
- **Don't skip circuit breakers** on third-party API calls — prevent cascade failures
- **Don't log PII** without redaction — mask emails, phone numbers, credit cards in logs
- **Don't skip GDPR compliance** for EU users — right to erasure, data portability, consent tracking

## Security Baseline Checklist

Every backend must implement these before shipping:

- [ ] **Input validation** — Zod/Pydantic with `.strict()`, reject unknown fields, custom validators
- [ ] **Parameterized queries** — ORM or prepared statements; never string concatenation
- [ ] **Authentication** — JWT (RS256/ES256) with 5-15 min expiry; refresh token rotation in `httpOnly` cookies
- [ ] **Authorization** — BOLA prevention: verify ownership on every resource access, never trust IDs
- [ ] **Rate limiting** — Tiered: login (5/15min), read (100/1min), write (30/1min), per-IP + per-user
- [ ] **HTTPS everywhere** — TLS 1.3 minimum; HSTS headers; never downgrade to HTTP
- [ ] **Security headers** — HSTS, X-Content-Type-Options, X-Frame-Options, CSP, Referrer-Policy
- [ ] **CORS** — Explicit allowlist per environment; never `*` in production with credentials
- [ ] **Secrets management** — Environment variables locally; HashiCorp Vault/Doppler in production
- [ ] **Logging** — Structured logs with Pino; redact auth tokens, passwords, PII, credit cards
- [ ] **Error handling** — Never expose stack traces, SQL queries, or internal hostnames to clients
- [ ] **Dependency scanning** — Trivy, Snyk, or Dependabot in CI/CD pipeline; block on HIGH/CRITICAL
- [ ] **Security testing** — Run `scripts/security-checklist.sh` before every deploy; OWASP ZAP quarterly
- [ ] **Database security** — Row-level security (RLS) for multi-tenant tables; encrypt backups at rest
- [ ] **API versioning** — `/v1/` prefix from day one; sunset policy with 6-month notice
- [ ] **Idempotency** — `Idempotency-Key` header on all mutation endpoints; deduplicate in Redis
- [ ] **Webhook security** — HMAC signature verification for every webhook; replay attack prevention
- [ ] **File upload security** — Validate MIME type, scan with ClamAV, size limits, store outside web root
- [ ] **Session security** — Short-lived sessions, concurrent session limits, device fingerprinting, forced logout
- [ ] **Compliance** — GDPR (EU users), HIPAA (health data), SOC2 (enterprise), PCI-DSS (payments)

See **security.md** for OWASP API Top 10 mapped to fixes, implementation details, and code examples.

## Testing Strategy

| Layer | Purpose | Tools | Coverage Target |
|-------|---------|-------|-----------------|
| Unit | Isolate business logic | Vitest/Jest, pytest | 80-90% line, 70-80% branch |
| Integration | API + DB together | Supertest, pytest + testcontainers | 100% of endpoints |
| Contract | API compatibility | Pact | All consumer/provider pairs |
| Security | OWASP checks | OWASP ZAP, `security-checklist.sh` | All endpoints, per release |
| Performance | System under load | k6, Artillery | Per release, per major change |
| E2E | Full user flow | Playwright, Cypress | 100% critical paths |

See **testing.md** for testing patterns, mocking strategies, and test database setup.

## Full-Stack Type Sharing

Generate TypeScript types from backend schema for frontend consumption:

```bash
# From OpenAPI spec
npx openapi-typescript https://api.yourdomain.com/openapi.json -o frontend/src/types/api.ts

# From Prisma schema
npx prisma generate --generator=typescript-types
# Or use prisma-json-schema-generator for Zod schemas

# From GraphQL schema
npx graphql-codegen --config codegen.yml
```

**tRPC for full-stack type safety (Next.js monorepo):**
```typescript
// server/trpc.ts
import { initTRPC } from '@trpc/server';
const t = initTRPC.create();
export const router = t.router;
export const publicProcedure = t.procedure;

// server/routers/user.ts
export const userRouter = router({
  getById: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(({ input }) => db.user.findById(input.id)),
});

// client component — fully typed, no codegen needed
const { data: user } = trpc.user.getById.useQuery({ id: '123' });
// TypeScript knows the exact shape of `user` and validates `id` at compile time
```

## Next.js API Routes / BFF Pattern

When using Next.js with `MO-Frontend`, use API routes for:
- Auth middleware (session validation, CSRF protection)
- Proxy to backend API (add auth headers, transform responses)
- Server-side data fetching (eliminate client waterfalls)
- File upload handling (stream to S3/R2)
- Webhook receivers (Stripe, GitHub, etc.)

```typescript
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
}).strict();

export async function POST(request: NextRequest) {
  const body = await request.json();
  const result = CreateUserSchema.safeParse(body);
  if (!result.success) {
    return NextResponse.json({ error: 'Validation failed', code: 'VALIDATION_ERROR' }, { status: 400 });
  }
  const user = await createUser(result.data);
  return NextResponse.json(user, { status: 201 });
}
```

## Monorepo Setup for Full-Stack

```
my-project/
├── apps/
│   ├── web/          # Next.js frontend (MO-Frontend)
│   │   ├── app/      # App Router
│   │   ├── components/
│   │   └── package.json
│   └── api/          # Backend API (MO-Backend)
│       ├── src/
│       ├── prisma/
│       └── package.json
├── packages/
│   ├── shared-types/ # Generated TypeScript types (shared)
│   ├── shared-ui/    # shadcn/ui components (shared)
│   └── shared-utils/ # Common utilities (shared)
├── docker-compose.yml
├── turbo.json        # Turborepo pipeline
└── pnpm-workspace.yaml
```

```json
// turbo.json
{
  "pipeline": {
    "build": { "dependsOn": ["^build"] },
    "dev": { "cache": false, "persistent": true },
    "test": { "dependsOn": ["build"] },
    "lint": {}
  }
}
```

## Tech Stack Cheat Sheet

```
Language:     TypeScript (NestJS/Fastify/Hono) or Python (FastAPI)
Database:     PostgreSQL (default) + Redis (caching + sessions + queues)
ORM:          Prisma (TS) or SQLAlchemy (Python)
Auth:         JWT (RS256) + bcrypt + OAuth 2.1 (for SSO)
Validation:   Zod (TS) or Pydantic (Python)
Queue:        BullMQ (TS) or Celery (Python) + Redis
Payments:     Stripe (PaymentIntent + webhooks)
Email:        Resend or SendGrid (queued via BullMQ/Celery)
Storage:      Cloudflare R2 (media) or AWS S3 (enterprise)
Search:       PostgreSQL full-text → pgvector → Elasticsearch
Real-time:    SSE (default) → Socket.io (bidirectional)
Container:    Docker + Docker Compose (local) / Kubernetes + GitOps (prod)
CI/CD:        GitHub Actions → Trivy scan → deploy
Monitoring:   Pino (logs) + Prometheus (metrics) + Grafana (dashboards) + PagerDuty (alerts)
API Gateway:  Kong / Nginx / Traefik / AWS API Gateway (at edge)
Observability: OpenTelemetry + Jaeger (tracing) + Loki (log aggregation)
```

## Quick Reference by Task

| Task | Go To | Key Pattern |
|------|-------|-------------|
| Choose database | databases.md | PostgreSQL default; MongoDB for unstructured only |
| Design API | apis.md | Resource URLs, cursor pagination, consistent errors, versioning |
| Build auth | auth.md | JWT RS256 + refresh rotation + RBAC + BOLA prevention |
| Secure API | security.md | Input validation + OWASP Top 10 + rate limiting + HTTPS |
| Add payments | integrations.md | Stripe PaymentIntent + webhook idempotency |
| Add real-time | realtime.md | SSE first; WebSocket only for bidirectional |
| Deploy | devops.md | Docker multi-stage + GitOps + Prometheus + alerting |
| Test | testing.md | Unit → Integration → E2E pyramid + security + performance |
| API Gateway | api-gateway.md | Kong/Nginx/Traefik + rate limiting at edge + SSL termination |
| Compliance | compliance.md | GDPR + HIPAA + SOC2 + data retention + audit logging |
| Observability | observability.md | Distributed tracing + APM + log aggregation + SLOs |
| Frontend integration | frontend-integration.md | CORS + BFF + shared types + Next.js API routes + auth for SPAs |
| Cost optimization | cost-optimization.md | Reserved instances + DB scaling + serverless optimization |

## Boilerplate Scripts

```bash
# NestJS + PostgreSQL + Prisma + Redis + Docker + CI/CD
bash scripts/init-nestjs-api.sh my-project

# FastAPI + PostgreSQL + SQLAlchemy + Alembic + Docker + CI/CD
bash scripts/init-fastapi-api.sh my-project

# Hono + Cloudflare Workers + D1 + R2
bash scripts/init-hono-edge.sh my-project

# Django + PostgreSQL + DRF + Docker + CI/CD
bash scripts/init-django-api.sh my-project

# Go + Gin + PostgreSQL + Docker + CI/CD
bash scripts/init-go-api.sh my-project

# Security checklist (run against any API)
bash scripts/security-checklist.sh https://api.yourdomain.com

# Generate TypeScript types from OpenAPI/Prisma for frontend
bash scripts/generate-shared-types.sh --source openapi --url https://api.yourdomain.com/openapi.json

# Seed database with realistic data
python scripts/seed-database.py --schema users,orders,products --count 1000

# Load testing with k6
bash scripts/load-test.sh --endpoint https://api.yourdomain.com --vus 100 --duration 5m
```

## Reference File Index

Load these as needed — never all at once:

- **references/architecture.md** — Monolith, microservices, modular monolith, serverless, event-driven (CQRS, Saga, Outbox), circuit breaker, idempotent handler
- **references/databases.md** — PostgreSQL vs MongoDB, ORM comparison (Prisma, Drizzle, SQLAlchemy, Django ORM), migrations, connection pooling, read replicas, caching, query optimization, N+1 prevention
- **references/apis.md** — RESTful best practices, GraphQL vs REST vs gRPC vs tRPC, WebSocket vs SSE, pagination (cursor + offset), versioning, error handling, OpenAPI, rate limiting
- **references/auth.md** — JWT best practices (RS256/ES256), OAuth 2.1 + OIDC, RBAC, ABAC, BOLA prevention, session management, password hashing, MFA/TOTP/WebAuthn
- **references/security.md** — OWASP API Top 10 mapped to fixes, input validation (Zod/Pydantic), SQL injection prevention, tiered rate limiting, security headers, CORS, secrets management, dependency scanning, file upload security
- **references/integrations.md** — Stripe payments (PaymentIntent + webhooks), email queues (Resend, SendGrid), file storage (S3/R2), search (PostgreSQL full-text, Elasticsearch, Algolia), notifications, webhooks
- **references/realtime.md** — WebSocket scaling with Redis adapter, SSE for streaming, Socket.io patterns, presence with TTL, disconnection handling, message ordering, rate limiting
- **references/devops.md** — Docker multi-stage builds, Docker Compose, CI/CD pipelines (GitHub Actions), GitOps with ArgoCD, monitoring (Prometheus + Grafana), structured logging (Pino), OpenTelemetry, alerting
- **references/testing.md** — Testing pyramid, unit testing (Vitest, pytest), API integration testing (Supertest, testcontainers), mocking strategies (MSW, nock), contract testing, E2E testing, performance testing
- **references/api-gateway.md** — Kong, Nginx, Traefik, AWS API Gateway, rate limiting at edge, SSL termination, load balancing, API key management
- **references/compliance.md** — GDPR, HIPAA, SOC2, PCI-DSS, data retention, right to erasure, data portability, consent tracking, audit logging
- **references/observability.md** — Distributed tracing (Jaeger, Zipkin), APM (New Relic, Datadog), log aggregation (ELK, Loki), alerting (PagerDuty, Opsgenie), SLOs, error tracking (Sentry)
- **references/frontend-integration.md** — CORS configuration, BFF pattern, shared types generation, Next.js API routes, auth for SPAs (httpOnly cookies), tRPC, GraphQL for frontend
- **references/cost-optimization.md** — Reserved instances, spot instances, serverless cost optimization, database scaling strategies, CDN usage, egress optimization

## Full-Stack Project Type Matrix

| Project Type | Frontend Stack | Backend Stack | Shared |
|-------------|----------------|---------------|--------|
| SaaS Platform | Next.js + Tailwind + shadcn/ui | NestJS + PostgreSQL + Prisma + Redis + BullMQ | tRPC or OpenAPI, Zod schemas, Turborepo |
| E-commerce | Next.js + Tailwind + Stripe.js | NestJS + PostgreSQL + Prisma + Stripe + BullMQ | OpenAPI, shared cart types, webhook handling |
| Social Media | Next.js + Tailwind + Socket.io client | NestJS + PostgreSQL + Redis Pub/Sub + Socket.io | WebSocket events, real-time feed types |
| AI Platform | Next.js + Tailwind + Vercel AI SDK | FastAPI + PostgreSQL + pgvector + Redis | OpenAPI, streaming SSE, embedding types |
| High-Performance API | — | Go + PostgreSQL + Kafka + gRPC | gRPC-Web, Protocol Buffers |
| Edge/Serverless | Next.js (edge) | Hono + Cloudflare Workers + D1 + R2 | Shared Zod schemas, D1 migrations |
| Enterprise/CMS | Next.js + Tailwind | Django + PostgreSQL + Celery + Elasticsearch | REST API, Django admin, search API |
| Real-time Collaboration | Next.js + Tailwind + Socket.io | Node.js + Socket.io + Redis + PostgreSQL | WebSocket rooms, CRDT types, presence |

## Progressive Disclosure Summary

1. **Metadata (name + description)** — Always in context (~80 words each)
2. **SKILL.md body** — Loaded when skill triggers (~400 lines)
3. **References** — Loaded on demand by task (~1,000-1,700 lines each)
4. **Scripts** — Executed without loading into context (deterministic, tested)
5. **Assets** — Used directly in output (starter templates, boilerplate code)
