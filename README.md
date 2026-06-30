# MO-Backend

> Production-grade backend engineering skill for the Moonshot AI ecosystem.

## What is MO-Backend?

MO-Backend is a comprehensive skill that provides architectural guidance, technology stack recommendations, scaffolding scripts, and best practices for building production-ready backend systems. It covers everything from API design to deployment, security to observability.

## Key Features

- **5 Language Scaffolds**: NestJS (Node.js), FastAPI (Python), Go (Gin), Django (Python), Hono (Edge/Workers)
- **14 Reference Documents**: Deep-dive guides on architecture, security, databases, DevOps, and more
- **Utility Scripts**: Type generation, security auditing, load testing, database seeding
- **Production-Ready**: Every scaffold includes Docker, CI/CD, auth, health checks, and tests

## Quick Start

### Scaffold a New API

Choose your stack and run the corresponding script:

```bash
# Node.js — Enterprise-grade with NestJS + Prisma + PostgreSQL
bash scripts/init-nestjs-api.sh my-api

# Python — Fast, async-first with FastAPI + SQLAlchemy + PostgreSQL
bash scripts/init-fastapi-api.sh my-api

# Go — High-performance with Gin + pgx + PostgreSQL
bash scripts/init-go-api.sh my-api

# Python (Full-Stack) — Batteries-included with Django + PostgreSQL
bash scripts/init-django-api.sh my-api

# Edge — Zero-cold-start with Hono + Cloudflare Workers + D1 + R2
bash scripts/init-hono-edge.sh my-api
```

### Run the Security Checklist

Before deploying any API, verify it meets security standards:

```bash
bash scripts/security-checklist.sh https://api.example.com --auth-token "Bearer TOKEN"
```

### Load Test Your API

Verify your API can handle production traffic:

```bash
bash scripts/load-test.sh https://api.example.com 50 5m
```

### Generate Realistic Seed Data

Populate your development database with realistic data:

```bash
python scripts/seed-database.py --schema users,products,orders --count 1000 --format sql
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](references/architecture.md) | System design patterns, scalability, microservices vs monolith |
| [APIs](references/apis.md) | RESTful design, GraphQL, versioning, rate limiting, documentation |
| [Authentication](references/auth.md) | OAuth 2.0, OIDC, JWT, session management, RBAC, ABAC |
| [Databases](references/databases.md) | SQL vs NoSQL, indexing, sharding, replication, ORMs |
| [DevOps](references/devops.md) | Docker, Kubernetes, CI/CD, IaC, blue-green deployments |
| [Integrations](references/integrations.md) | Webhooks, REST APIs, GraphQL, message queues, SDKs |
| [Real-time](references/realtime.md) | WebSockets, SSE, Kafka, Redis Streams, polling |
| [Security](references/security.md) | OWASP, encryption, secrets, audit logging, zero trust |
| [Testing](references/testing.md) | Unit, integration, e2e, contract, load, chaos testing |
| [API Gateway](references/api-gateway.md) | Edge routing, BFF, rate limiting, caching, SSL |
| [Compliance](references/compliance.md) | GDPR, SOC2, HIPAA, data residency, audit trails |
| [Observability](references/observability.md) | Logging, metrics, tracing, alerting, dashboards |
| [Frontend Integration](references/frontend-integration.md) | CORS, BFF, SSR, hydration, state sync |
| [Cost Optimization](references/cost-optimization.md) | Cloud spend, caching, connection pooling, query optimization |

## Technology Stack Matrix

| Use Case | Primary | Secondary |
|----------|---------|-----------|
| Enterprise API (Node.js) | NestJS + Prisma | Express + TypeORM |
| Rapid API (Python) | FastAPI + SQLAlchemy | Django + DRF |
| High-Performance API | Go + Gin + pgx | Rust + axum |
| Full-Stack (Python) | Django + PostgreSQL | Flask + SQLAlchemy |
| Edge/Serverless | Hono + Cloudflare Workers | Express + Lambda |
| Real-time | Node.js + Socket.io | Go + WebSocket |
| Event Streaming | Kafka + Connect | Redis Streams + Bull |
| Caching | Redis | Memcached |
| Queue/Worker | BullMQ + Redis | Celery + RabbitMQ |
| Search | Elasticsearch | Typesense |
| Time-Series | TimescaleDB | InfluxDB |
| Graph Database | Neo4j | ArangoDB |
| Document Store | MongoDB | PostgreSQL JSONB |
| Object Storage | AWS S3 / MinIO | Cloudflare R2 |
| CDN | Cloudflare | AWS CloudFront |
| API Gateway | Kong | AWS API Gateway |
| Load Balancer | NGINX | Traefik |
| Service Mesh | Istio | Linkerd |
| Monitoring | Prometheus + Grafana | Datadog |
| Logging | ELK Stack | Loki + Grafana |
| Tracing | Jaeger | Zipkin |
| Secrets | HashiCorp Vault | AWS Secrets Manager |
| CI/CD | GitHub Actions | GitLab CI |
| IaC | Terraform | Pulumi |
| Containers | Docker + Kubernetes | Docker Compose |
| Serverless | Terraform + Lambda | Serverless Framework |

## Integration with MO Ecosystem

- **MO-Frontend**: BFF patterns, API contract sharing, type generation
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
