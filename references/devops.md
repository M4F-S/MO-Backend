# DevOps & Deployment

> Docker, Kubernetes, CI/CD pipelines, infrastructure as code, and deployment strategies for production backends.

## Table of Contents

1. [Containerization](#1-containerization)
2. [Kubernetes](#2-kubernetes)
3. [CI/CD Pipelines](#3-cicd-pipelines)
4. [Infrastructure as Code](#4-infrastructure-as-code)
5. [Deployment Strategies](#5-deployment-strategies)
6. [Secrets Management](#6-secrets-management)
7. [Environment Management](#7-environment-management)
8. [Monitoring & Alerting](#8-monitoring--alerting)
9. [Disaster Recovery](#9-disaster-recovery)
10. [Cost Optimization](#10-cost-optimization)

---

## 1. Containerization

### Dockerfile Best Practices

```dockerfile
# Multi-stage build for Node.js
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:22-alpine AS production
RUN apk add --no-cache dumb-init
ENV NODE_ENV=production
USER node
WORKDIR /app
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/package.json ./
EXPOSE 3000
CMD ["dumb-init", "node", "dist/main.js"]
```

### Docker Compose for Local Development

```yaml
version: '3.8'

services:
  api:
    build: .
    ports: ["3000:3000"]
    env_file: .env
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      db: { condition: service_healthy }
      redis: { condition: service_healthy }
    volumes:
      - .:/app
      - /app/node_modules
    command: npm run start:dev
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp
    ports: ["5432:5432"]
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  pgadmin:
    image: dpage/pgadmin4:latest
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: admin
    ports: ["5050:80"]
    depends_on: [db]

volumes:
  postgres_data:
```

### Container Security

| Practice | Implementation |
|----------|---------------|
| **Non-root user** | `USER node` in Dockerfile |
| **Minimal base image** | `alpine`, `distroless` |
| **Multi-stage builds** | Separate build and runtime |
| **No secrets in images** | Use env vars, secrets management |
| **Read-only filesystem** | `read_only: true` in compose |
| **Security scanning** | Trivy, Snyk, Clair in CI |
| **Resource limits** | CPU/memory limits in K8s |
| **Health checks** | `HEALTHCHECK` in Dockerfile |

---

## 2. Kubernetes

### Pod Spec

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: production
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: myapp/api:latest
          ports:
            - containerPort: 3000
              name: http
          env:
            - name: NODE_ENV
              value: production
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: api-secrets
                  key: database-url
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health/live
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
            capabilities:
              drop: ["ALL"]
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: api
                topologyKey: kubernetes.io/hostname
```

### Service & Ingress

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 3000
  type: ClusterIP

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/rate-limit: "100"
spec:
  tls:
    - hosts: ["api.example.com"]
      secretName: api-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
```

### Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
```

---

## 3. CI/CD Pipelines

### GitHub Actions

```yaml
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_USER: postgres, POSTGRES_PASSWORD: postgres, POSTGRES_DB: test }
        options: >-
          --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
        ports: ["5432:5432"]
      redis:
        image: redis:7-alpine
        ports: ["6379:6379"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npx prisma generate
      - run: npx prisma migrate deploy
        env: { DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test?schema=public }
      - run: npm run test
      - run: npm run test:integration
      - run: npm run build

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/trivy-action@master
        with: { image-ref: '.', format: 'table', exit-code: '1', severity: 'CRITICAL,HIGH' }
      - uses: sonarqube-quality-gate-action@master
        env: { SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }} }

  deploy:
    needs: [test, security]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with: { aws-access-key-id: ${{ secrets.AWS_KEY }}, aws-secret-access-key: ${{ secrets.AWS_SECRET }}, aws-region: us-east-1 }
      - run: aws eks update-kubeconfig --name production
      - run: kubectl set image deployment/api api=myapp/api:${{ github.sha }}
      - run: kubectl rollout status deployment/api --timeout=300s
      - run: kubectl apply -f k8s/
```

### Deployment Pipeline Stages

```
Build → Test → Security Scan → Deploy Staging → Smoke Tests → Deploy Production
```

| Stage | Gates | Rollback |
|-------|-------|----------|
| **Build** | Compiles, lint passes | Fix code |
| **Unit Test** | >80% coverage, all pass | Fix tests |
| **Integration Test** | DB, external services pass | Fix integration |
| **Security Scan** | No CRITICAL/HIGH vulnerabilities | Fix vulnerabilities |
| **Deploy Staging** | Smoke tests pass | Automatic rollback |
| **Deploy Production** | Manual approval or automated canary | Blue-green or rollback |

---

## 4. Infrastructure as Code

### Terraform Structure

```
infra/
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── rds/
│   ├── redis/
│   └── s3/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── production/
└── global/
    └── iam/
```

### Terraform Example (EKS + RDS)

```hcl
# environments/production/main.tf
terraform {
  required_version = ">= 1.5"
  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

module "vpc" {
  source = "../../modules/vpc"
  cidr   = "10.0.0.0/16"
  azs    = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "production"
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      desired_size = 3
      min_size     = 2
      max_size     = 10
      instance_types = ["t3.medium"]
    }
  }
}

module "rds" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "production-db"
  engine     = "postgres"
  version    = "16"
  instance_class = "db.t3.medium"
  allocated_storage = 100

  db_name  = "myapp"
  username = "app_user"
  password = var.db_password # From secrets manager

  vpc_security_group_ids = [module.vpc.database_security_group_id]
  subnet_ids            = module.vpc.database_subnets
}
```

---

## 5. Deployment Strategies

| Strategy | Description | Risk | Complexity | Best For |
|----------|-------------|------|------------|----------|
| **Rolling** | Gradual pod replacement | Medium | Low | Default, most common |
| **Blue-Green** | Two identical environments | Low | Medium | Critical systems, instant rollback |
| **Canary** | Route small % to new version | Low | High | High traffic, gradual rollout |
| **A/B Testing** | Route based on user attributes | Low | High | Feature testing, experimentation |
| **Shadow** | Mirror traffic, no user impact | None | High | Performance testing, validation |
| **Recreate** | Stop old, start new | High | Low | Development, non-critical |

### Blue-Green Deployment

```yaml
# K8s with Service selector switch
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    version: blue  # Switch to green for rollback
  ports:
    - port: 80
      targetPort: 3000
```

### Canary Deployment (Flagger + Istio)

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: api
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  service:
    port: 3000
    targetPort: 3000
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
      - name: request-duration
        thresholdRange:
          max: 500
    webhooks:
      - name: load-test
        url: http://flagger-loadtester.test/
        timeout: 5s
        metadata:
          cmd: "hey -z 1m -q 10 -c 2 http://api-canary:3000/"
```

---

## 6. Secrets Management

### Secrets in Kubernetes

```yaml
# External Secrets Operator (recommended)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets-manager
  target:
    name: api-secrets
    creationPolicy: Owner
  data:
    - secretKey: database-url
      remoteRef:
        key: production/api
        property: database-url
    - secretKey: jwt-secret
      remoteRef:
        key: production/api
        property: jwt-secret
```

### HashiCorp Vault

```bash
# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Store secrets
vault kv put secret/production/api \
  database-url="postgresql://..." \
  jwt-secret="..."

# App reads via sidecar or SDK
vault kv get -format=json secret/production/api
```

---

## 7. Environment Management

### Environment Promotion

```
Local → Development → Staging → Production
   ↑         ↑           ↑          ↑
  Dev       CI          QA         Ops
```

### Environment Configuration

| Environment | Purpose | Data | Scaling | Monitoring |
|-------------|---------|------|---------|------------|
| **Local** | Development | Fake/seeded | 1 instance | Console logs |
| **Development** | Feature testing | Anonymized prod | 1-2 instances | Basic logs |
| **Staging** | Pre-release | Prod snapshot | Same as prod | Full monitoring |
| **Production** | Live users | Real | Auto-scaled | Full stack |

### Configuration Management

```typescript
// config.ts — environment-aware configuration
const env = process.env.NODE_ENV || 'development';

const config = {
  development: {
    database: { host: 'localhost', poolSize: 5 },
    redis: { host: 'localhost' },
    logLevel: 'debug',
  },
  staging: {
    database: { host: 'staging.db.internal', poolSize: 10 },
    redis: { host: 'staging.redis.internal' },
    logLevel: 'info',
  },
  production: {
    database: { host: 'prod.db.internal', poolSize: 20 },
    redis: { host: 'prod.redis.internal', cluster: true },
    logLevel: 'warn',
  },
};

export default config[env];
```

---

## 8. Monitoring & Alerting

### Health Checks

```typescript
// Health check endpoint
app.get('/health', async (req, res) => {
  const checks = await Promise.all([
    checkDatabase(),
    checkRedis(),
    checkExternalAPI(),
  ]);

  const allHealthy = checks.every(c => c.healthy);
  res.status(allHealthy ? 200 : 503).json({
    status: allHealthy ? 'healthy' : 'unhealthy',
    checks: Object.fromEntries(checks.map(c => [c.name, c.status])),
    timestamp: new Date().toISOString(),
  });
});

// Kubernetes probes
app.get('/health/live', (req, res) => res.json({ status: 'alive' }));
app.get('/health/ready', async (req, res) => {
  const db = await checkDatabase();
  res.status(db.healthy ? 200 : 503).json({ status: db.healthy ? 'ready' : 'not_ready' });
});
```

### Alerting Rules (Prometheus)

```yaml
# alerts.yml
groups:
  - name: api
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on {{ $labels.service }}"

      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "95th percentile latency > 500ms"

      - alert: DatabaseConnections
        expr: pg_stat_activity_count > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Database connections > 80"
```

---

## 9. Disaster Recovery

### Backup Strategy

| Component | Frequency | Retention | Method |
|-----------|-----------|-----------|--------|
| Database | Continuous | 30 days | WAL archiving + daily snapshots |
| Database | Daily | 90 days | pg_dump logical backup |
| Database | Weekly | 1 year | Full snapshot to S3 |
| Files/Objects | Real-time | 30 days | S3 versioning |
| Configuration | On change | Forever | Git + Terraform state |

### Recovery Time Objectives (RTO)

| Tier | RTO | RPO | Implementation |
|------|-----|-----|----------------|
| **Critical** | < 5 min | < 1 min | Multi-region active-active, synchronous replication |
| **High** | < 1 hour | < 15 min | Cross-region read replica, automated failover |
| **Medium** | < 4 hours | < 1 hour | Daily backups, manual restore |
| **Low** | < 24 hours | < 24 hours | Weekly backups, manual restore |

### Multi-Region Setup

```yaml
# Primary region
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: production
  annotations:
    region: us-east-1

# Secondary region (read replicas, async)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-read
  namespace: production
  annotations:
    region: us-west-2
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: api
          env:
            - name: DATABASE_URL
              value: "postgresql://.../myapp?target_session_attrs=read-only"
```

---

## 10. Cost Optimization

### Cloud Cost Strategies

| Strategy | Savings | Implementation |
|----------|---------|----------------|
| **Spot instances** | 60-90% | K8s spot node pools, tolerant workloads |
| **Reserved instances** | 30-60% | 1-3 year commitment for baseline |
| **Savings plans** | 20-30% | Flexible commitment vs reserved |
| **Right-sizing** | 20-40% | Monitor CPU/memory, adjust requests |
| **Auto-scaling** | 10-30% | Scale to zero, HPA based on demand |
| **Graviton/ARM** | 20-40% | ARM-based instances for compatible workloads |
| **Object storage tiers** | 50-90% | S3 Intelligent-Tiering, Glacier |
| **CDN caching** | 30-50% | Cache at edge, reduce origin requests |
| **Connection pooling** | 10-20% | PgBouncer, RDS Proxy, reduce DB connections |

### Kubernetes Resource Optimization

```yaml
resources:
  requests:
    memory: "128Mi"  # Start low, adjust based on metrics
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

Use [Goldilocks](https://github.com/FairwindsOps/goldilocks) or VPA to recommend resource requests.

## References

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/)
- [Google Cloud Architecture Center](https://cloud.google.com/architecture)
- [CNCF Cloud Native Trail Map](https://landscape.cncf.io/)
