# MO-Backend

A comprehensive backend engineering skill for the MO (Moonshot) ecosystem. Provides architectural guidance, technology stack recommendations, scaffolding scripts, and best practices for building production-ready backend systems.

## Overview

This skill covers the full spectrum of backend development:

- **Architecture Patterns**: Monolith vs microservices, domain-driven design, event-driven architecture
- **Technology Stacks**: Node.js, Python, Go, Rust — with framework recommendations
- **Database Design**: SQL, NoSQL, time-series, caching strategies
- **API Design**: REST, GraphQL, gRPC, WebSocket patterns
- **Authentication & Authorization**: OAuth 2.0, OIDC, JWT, RBAC, ABAC
- **DevOps & Deployment**: Docker, Kubernetes, CI/CD, infrastructure as code
- **Observability**: Logging, metrics, tracing, alerting
- **Security**: Hardening, secrets management, compliance (GDPR, SOC2)
- **Performance**: Caching, load balancing, rate limiting, optimization
- **Real-time**: WebSockets, SSE, event streaming (Kafka, Redis Streams)

## Structure

```
MO-Backend/
├── SKILL.md                          # This file — entry point & skill manifest
├── README.md                         # Overview for GitHub visitors
├── references/                       # Deep-dive reference documents
│   ├── architecture.md                # System design & architecture patterns
│   ├── apis.md                        # API design standards
│   ├── auth.md                        # Authentication & authorization
│   ├── databases.md                   # Database selection & design
│   ├── devops.md                      # Deployment & infrastructure
│   ├── integrations.md                # Third-party integrations
│   ├── realtime.md                    # Real-time communication
│   ├── security.md                    # Security hardening
│   ├── testing.md                     # Testing strategies
│   ├── api-gateway.md                # API gateway patterns
│   ├── compliance.md                 # Regulatory compliance
│   ├── observability.md              # Monitoring & observability
│   ├── frontend-integration.md       # Frontend-backend integration
│   └── cost-optimization.md          # Cost optimization strategies
└── scripts/                           # Executable scaffolding scripts
    ├── generate-shared-types.sh      # Generate shared TypeScript types from OpenAPI
    ├── init-django-api.sh            # Scaffold Django + PostgreSQL API
    ├── init-fastapi-api.sh           # Scaffold FastAPI + PostgreSQL API
    ├── init-go-api.sh                # Scaffold Go + Gin + PostgreSQL API
    ├── init-hono-edge.sh             # Scaffold Hono + Cloudflare Workers edge API
    ├── init-nestjs-api.sh            # Scaffold NestJS + Prisma + PostgreSQL API
    ├── load-test.sh                  # k6-based load testing with dynamic script generation
    ├── security-checklist.sh         # Automated API security checks
    └── seed-database.py              # Generate realistic seed data for development
```

## Quick Start

### 1. Scaffold a new API

```bash
# NestJS (enterprise-grade Node.js)
bash ~/.kimi/skills/MO-Backend/scripts/init-nestjs-api.sh my-project

# FastAPI (Python, async-first)
bash ~/.kimi/skills/MO-Backend/scripts/init-fastapi-api.sh my-project

# Go (high-performance, type-safe)
bash ~/.kimi/skills/MO-Backend/scripts/init-go-api.sh my-project

# Django (batteries-included Python)
bash ~/.kimi/skills/MO-Backend/scripts/init-django-api.sh my-project

# Hono Edge (Cloudflare Workers, edge-deployed)
bash ~/.kimi/skills/MO-Backend/scripts/init-hono-edge.sh my-project
```

### 2. Generate shared types

```bash
# From an OpenAPI spec, generate TypeScript types for frontend and backend
bash ~/.kimi/skills/MO-Backend/scripts/generate-shared-types.sh ./api-spec.yaml ./src/types
```

### 3. Run security checklist

```bash
# Before deploying, verify security headers, rate limiting, input validation
bash ~/.kimi/skills/MO-Backend/scripts/security-checklist.sh https://api.example.com
```

### 4. Load testing

```bash
# Verify your API can handle production traffic
bash ~/.kimi/skills/MO-Backend/scripts/load-test.sh https://api.example.com 50 5m
```

### 5. Seed database

```bash
# Generate realistic test data for development
python ~/.kimi/skills/MO-Backend/scripts/seed-database.py --schema users,products,orders --count 1000 --format sql
```

## Reference Documents

For detailed guidance on specific topics:

| Topic | Document | Purpose |
|-------|----------|---------|
| Architecture | `references/architecture.md` | System design patterns, scalability, microservices vs monolith |
| APIs | `references/apis.md` | RESTful design, GraphQL, versioning, rate limiting, documentation |
| Authentication | `references/auth.md` | OAuth 2.0, OIDC, JWT, session management, RBAC, ABAC |
| Databases | `references/databases.md` | SQL vs NoSQL, indexing, sharding, replication, ORMs |
| DevOps | `references/devops.md` | Docker, K8s, CI/CD, IaC, blue-green deployments |
| Integrations | `references/integrations.md` | Webhooks, REST APIs, GraphQL, message queues, SDKs |
| Real-time | `references/realtime.md` | WebSockets, SSE, Kafka, Redis Streams, polling |
| Security | `references/security.md` | OWASP, encryption, secrets, audit logging, zero trust |
| Testing | `references/testing.md` | Unit, integration, e2e, contract, load, chaos testing |
| API Gateway | `references/api-gateway.md` | Edge routing, BFF, rate limiting, caching, SSL |
| Compliance | `references/compliance.md` | GDPR, SOC2, HIPAA, data residency, audit trails |
| Observability | `references/observability.md` | Logging, metrics, tracing, alerting, dashboards |
| Frontend Integration | `references/frontend-integration.md` | CORS, BFF, SSR, hydration, state sync |
| Cost Optimization | `references/cost-optimization.md` | Cloud spend, caching, connection pooling, query optimization |

## Technology Stack Recommendations

| Use Case | Primary | Secondary | Notes |
|----------|---------|-----------|-------|
| Enterprise API (Node.js) | NestJS + Prisma | Express + TypeORM | NestJS for DI, modularity, testing |
| Rapid API (Python) | FastAPI + SQLAlchemy | Django + DRF | FastAPI for async, auto-docs, performance |
| High-Performance API | Go + Gin + pgx | Rust + axum | Go for simplicity, Rust for extreme safety |
| Full-Stack (Python) | Django + PostgreSQL | Flask + SQLAlchemy | Django for admin, ORM, migrations |
| Edge/Serverless | Hono + Cloudflare Workers | Express + Lambda | Hono for zero cold-start, edge caching |
| Real-time | Node.js + Socket.io | Go + WebSocket | Socket.io for fallback, rooms, broadcasting |
| Event Streaming | Kafka + Connect | Redis Streams + Bull | Kafka for durability, Redis for simplicity |
| Caching | Redis | Memcached | Redis for data structures, pub/sub, persistence |
| Queue/Worker | BullMQ + Redis | Celery + RabbitMQ | BullMQ for Node.js, Celery for Python |
| Search | Elasticsearch | Typesense | Elasticsearch for complex queries, Typesense for speed |
| Time-Series | TimescaleDB | InfluxDB | TimescaleDB on PostgreSQL, InfluxDB for IoT |
| Graph Database | Neo4j | ArangoDB | Neo4j for relationships, ArangoDB for multi-model |
| Document Store | MongoDB | PostgreSQL JSONB | MongoDB for flexibility, PostgreSQL for consistency |
| Object Storage | AWS S3 / MinIO | Cloudflare R2 | S3 for ecosystem, R2 for zero egress |
| CDN | Cloudflare | AWS CloudFront | Cloudflare for security + performance |
| API Gateway | Kong | AWS API Gateway | Kong for extensibility, AWS for integration |
| Load Balancer | NGINX | Traefik | NGINX for performance, Traefik for cloud-native |
| Service Mesh | Istio | Linkerd | Istio for features, Linkerd for simplicity |
| Monitoring | Prometheus + Grafana | Datadog | Prometheus for OSS, Datadog for managed |
| Logging | ELK Stack | Loki + Grafana | ELK for search, Loki for cost-efficiency |
| Tracing | Jaeger | Zipkin | Jaeger for OpenTelemetry, Zipkin for simplicity |
| Secrets | HashiCorp Vault | AWS Secrets Manager | Vault for multi-cloud, AWS for integration |
| CI/CD | GitHub Actions | GitLab CI | GitHub for ecosystem, GitLab for built-in features |
| IaC | Terraform | Pulumi | Terraform for maturity, Pulumi for code |
| Containers | Docker + Kubernetes | Docker Compose | K8s for scale, Compose for dev |
| Serverless | Terraform + Lambda | Serverless Framework | Terraform for IaC, Serverless for DX |

## Integration with Other MO Skills

- **MO-Frontend**: Backend-for-Frontend (BFF) patterns, API contract sharing, type generation
- **MO-DevOps**: CI/CD pipelines, Dockerfiles, K8s manifests, infrastructure provisioning
- **MO-Data**: Database migrations, ETL pipelines, analytics APIs, data lakes
- **MO-AI**: LLM integration, vector databases, embedding APIs, RAG pipelines
- **MO-Mobile**: Mobile-specific APIs, push notifications, offline sync, battery optimization

## Contributing

When adding new scaffolds or references:

1. Follow the existing structure and naming conventions
2. Include `set -euo pipefail` in all bash scripts
3. Add health check endpoints to all API scaffolds
4. Include JWT auth + BOLA protection in all API scaffolds
5. Add Docker + docker-compose for local development
6. Include CI/CD pipeline (GitHub Actions) for all scaffolds
7. Add integration tests with testcontainers where applicable
8. Document all environment variables in `.env.example`
9. Include database migration/seeding scripts
10. Add rate limiting and input validation examples

## License

MIT — Part of the Moonshot AI (MO) ecosystem.