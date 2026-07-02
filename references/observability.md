# Observability and Monitoring Reference

## Table of Contents
1. [Three Pillars of Observability](#three-pillars-of-observability)
2. [Distributed Tracing](#distributed-tracing)
3. [APM Tools](#apm-tools)
4. [Metrics with Prometheus & Grafana](#metrics-with-prometheus--grafana)
5. [Structured Logging](#structured-logging)
6. [Alerting](#alerting)
7. [Error Tracking](#error-tracking)
8. [Health Checks](#health-checks)
9. [Dashboard Design](#dashboard-design)
10. [Performance Profiling](#performance-profiling)
11. [Synthetic Monitoring](#synthetic-monitoring)
12. [Code Examples](#code-examples)

---

## Three Pillars of Observability

Observability is the ability to understand a system's internal state from its external outputs. It rests on three pillars:

| Pillar | Answers | Examples | Tools |
|--------|---------|----------|-------|
| **Metrics** | WHAT is happening? | CPU usage, request rate, error rate | Prometheus, Datadog, CloudWatch |
| **Logs** | WHY is it happening? | Error messages, stack traces, events | ELK, Loki, Splunk, CloudWatch Logs |
| **Traces** | WHERE is it happening? | Request path, latency per service | Jaeger, Zipkin, OpenTelemetry |

**Correlation:** Bind all three with a `trace_id` and `span_id` — a single identifier carried through the entire request lifecycle.

```
┌─────────────────────────────────────────────────────────────┐
│  Request: POST /api/orders                                  │
│  trace_id: 4f6d9c2e8a1b4f6d9c2e8a1b                       │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐            │
│  │ API GW   │───▶│ Orders   │───▶│ Payment  │            │
│  │  45ms    │    │  120ms   │    │  200ms   │            │
│  └──────────┘    └──────────┘    └──────────┘            │
│                                                             │
│  Log: "Payment failed: card_declined"  ← WHY               │
│  Metric: payment_errors_total +1       ← WHAT              │
│  Trace: 200ms in Payment service       ← WHERE             │
└─────────────────────────────────────────────────────────────┘
```

---

## Distributed Tracing

### OpenTelemetry Setup

```typescript
// telemetry.ts
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

const resource = new Resource({
  [SemanticResourceAttributes.SERVICE_NAME]: 'order-service',
  [SemanticResourceAttributes.SERVICE_VERSION]: '1.2.3',
  [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV,
  [SemanticResourceAttributes.HOST_NAME]: require('os').hostname(),
});

const traceExporter = new OTLPTraceExporter({
  url: 'http://otel-collector:4318/v1/traces',
});

const metricExporter = new OTLPMetricExporter({
  url: 'http://otel-collector:4318/v1/metrics',
});

const sdk = new NodeSDK({
  resource,
  traceExporter,
  metricReader: new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: 60000,
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': { enabled: false }, // Too noisy
      '@opentelemetry/instrumentation-net': { enabled: true },
    }),
  ],
});

sdk.start();

// Graceful shutdown
process.on('SIGTERM', () => sdk.shutdown());
```

### Manual Span Creation

```typescript
// tracing-utils.ts
import { trace, context, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('order-service', '1.0.0');

export async function createOrderWithTracing(userId: string, orderData: any): Promise<Order> {
  return tracer.startActiveSpan('createOrder', async (span) => {
    try {
      span.setAttribute('user.id', userId);
      span.setAttribute('order.item_count', orderData.items.length);

      // Validate order
      const validationSpan = tracer.startSpan('validateOrder');
      const validation = await validateOrder(orderData);
      validationSpan.setAttribute('validation.valid', validation.valid);
      validationSpan.end();

      // Calculate pricing
      const pricing = await tracer.startActiveSpan('calculatePricing', async (pricingSpan) => {
        const result = await calculatePricing(orderData);
        pricingSpan.setAttribute('pricing.total', result.total);
        pricingSpan.setAttribute('pricing.currency', result.currency);
        return result;
      });

      // Process payment
      const payment = await tracer.startActiveSpan('processPayment', async (paymentSpan) => {
        paymentSpan.setAttribute('payment.amount', pricing.total);
        try {
          const result = await processPayment(userId, pricing.total);
          paymentSpan.setStatus({ code: SpanStatusCode.OK });
          return result;
        } catch (error) {
          paymentSpan.setStatus({
            code: SpanStatusCode.ERROR,
            message: error.message,
          });
          paymentSpan.recordException(error);
          throw error;
        }
      });

      // Save order
      const order = await saveOrder(userId, orderData, pricing, payment);
      span.setAttribute('order.id', order.id);
      span.setStatus({ code: SpanStatusCode.OK });

      return order;
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message,
      });
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  });
}

// Propagate trace context to outgoing requests
export function addTraceContext(headers: Record<string, string>): Record<string, string> {
  const carrier = {};
  trace.getSpanContext(context.active())?.traceId &&
    propagation.inject(context.active(), carrier, defaultTextMapSetter);
  return { ...headers, ...carrier };
}
```

### Trace Context Propagation (HTTP)

```typescript
// trace-context-middleware.ts
import { trace, propagation, context } from '@opentelemetry/api';

export function traceContextMiddleware(req: Request, res: Response, next: NextFunction) {
  const extractedContext = propagation.extract(context.active(), req.headers);
  context.with(extractedContext, () => {
    const span = trace.getActiveSpan();
    if (span) {
      span.setAttribute('http.method', req.method);
      span.setAttribute('http.route', req.route?.path || req.path);
      span.setAttribute('http.target', req.originalUrl);
      span.setAttribute('http.user_agent', req.headers['user-agent'] || '');
    }

    // Ensure response has trace headers for client correlation
    const spanContext = trace.getSpan(context.active())?.spanContext();
    if (spanContext) {
      res.setHeader('X-Trace-Id', spanContext.traceId);
      res.setHeader('X-Span-Id', spanContext.spanId);
    }

    next();
  });
}
```

---

## APM Tools

### Comparison Matrix

| Feature | New Relic | Datadog | Dynatrace | AppDynamics |
|---------|-----------|---------|-----------|-------------|
| **Pricing** | Per host + data ingestion | Per host + per million spans | Per host (simpler) | Per CPU core |
| **Auto-Instrumentation** | Excellent | Excellent | Best-in-class | Good |
| **AI/ML Insights** | Good (Lookout) | Good (Watchdog) | Excellent (Davis) | Fair |
| **Custom Dashboards** | Good | Excellent | Good | Fair |
| **Alerting** | Good | Excellent | Good | Good |
| **Log Management** | Good | Excellent | Good | Fair |
| **Infrastructure Monitoring** | Good | Excellent | Good | Good |
| **User Experience (RUM)** | Good | Excellent | Good | Good |
| **On-Prem Option** | Yes | No | Yes | Yes |
| **OpenTelemetry Support** | Good | Excellent | Good | Fair |

### Selection Criteria

```typescript
// apm-selection-guide.ts
interface APMSelectionCriteria {
  budget: 'low' | 'medium' | 'high' | 'enterprise';
  environment: 'cloud_only' | 'hybrid' | 'on_prem';
  techStack: string[];
  teamSize: number;
  needs: {
    autoInstrumentation: boolean;
    aiInsights: boolean;
    customMetrics: boolean;
    logCorrelation: boolean;
    syntheticMonitoring: boolean;
    securityMonitoring: boolean;
  };
}

function recommendAPM(criteria: APMSelectionCriteria): string {
  if (criteria.needs.aiInsights && criteria.budget === 'high') {
    return 'Dynatrace'; // Best AI-powered root cause
  }
  if (criteria.needs.logCorrelation && criteria.needs.customMetrics) {
    return 'Datadog'; // Best unified platform
  }
  if (criteria.budget === 'low' && criteria.environment === 'cloud_only') {
    return 'New Relic'; // Free tier available, good startup pricing
  }
  if (criteria.environment === 'on_prem') {
    return 'Dynatrace or AppDynamics'; // Both offer on-prem
  }
  return 'Datadog'; // Safe default for most
}
```

---

## Metrics with Prometheus & Grafana

### Prometheus Metrics Setup

```typescript
// metrics.ts
import { PrometheusExporter, MeterProvider } from '@opentelemetry/sdk-metrics';
import { metrics } from '@opentelemetry/api';

const prometheusExporter = new PrometheusExporter({ port: 9090 }, () => {
  console.log('Prometheus metrics available at http://localhost:9090/metrics');
});

const meterProvider = new MeterProvider({
  readers: [prometheusExporter],
});

metrics.setGlobalMeterProvider(meterProvider);
const meter = metrics.getMeter('order-service', '1.0.0');

// Counter: monotonically increasing values
const requestCounter = meter.createCounter('http_requests_total', {
  description: 'Total number of HTTP requests',
  unit: '1',
});

// Histogram: request duration distribution
const requestDuration = meter.createHistogram('http_request_duration_seconds', {
  description: 'HTTP request duration in seconds',
  unit: 's',
  advice: {
    explicitBucketBoundaries: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  },
});

// UpDownCounter: values that can go up or down
const activeConnections = meter.createUpDownCounter('http_active_connections', {
  description: 'Number of active HTTP connections',
  unit: '1',
});

// ObservableGauge: periodically observed value
const memoryUsage = meter.createObservableGauge('process_memory_usage_bytes', {
  description: 'Process memory usage in bytes',
  unit: 'bytes',
});

memoryUsage.addCallback((observableResult) => {
  const usage = process.memoryUsage();
  observableResult.observe(usage.heapUsed, { type: 'heap' });
  observableResult.observe(usage.rss, { type: 'rss' });
  observableResult.observe(usage.external, { type: 'external' });
});

// Middleware to record metrics
export function metricsMiddleware(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();
  activeConnections.add(1, { route: req.route?.path || 'unknown' });

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const labels = {
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode.toString(),
    };

    requestCounter.add(1, labels);
    requestDuration.record(duration, labels);
    activeConnections.add(-1, { route: req.route?.path || 'unknown' });
  });

  next();
}
```

### SLIs, SLOs, and SLAs

```typescript
// slo-definitions.ts
interface ServiceLevelIndicator {
  name: string;
  description: string;
  metric: string;
  goodEvent: string;
  badEvent: string;
  aggregation: 'sum' | 'avg' | 'rate' | 'percentile';
}

interface ServiceLevelObjective {
  name: string;
  sli: ServiceLevelIndicator;
  target: number;           // e.g., 0.999 (99.9%)
  window: string;           // e.g., '30d'
  errorBudget: number;       // 1 - target, e.g., 0.001
  severity: 'critical' | 'high' | 'medium' | 'low';
}

const slos: ServiceLevelObjective[] = [
  {
    name: 'API Availability',
    sli: {
      name: 'api_availability',
      description: 'Ratio of successful requests to total requests',
      metric: 'http_requests_total',
      goodEvent: 'status_code !~ "5.."',
      badEvent: 'status_code =~ "5.."',
      aggregation: 'rate',
    },
    target: 0.9995, // 99.95%
    window: '30d',
    errorBudget: 0.0005,
    severity: 'critical',
  },
  {
    name: 'API Latency (p99)',
    sli: {
      name: 'api_latency_p99',
      description: '99th percentile of request latency',
      metric: 'http_request_duration_seconds',
      goodEvent: 'le=0.5',
      badEvent: 'le=+Inf',
      aggregation: 'percentile',
    },
    target: 0.99, // 99% of requests under 500ms
    window: '30d',
    errorBudget: 0.01,
    severity: 'high',
  },
  {
    name: 'Payment Success Rate',
    sli: {
      name: 'payment_success',
      description: 'Ratio of successful payments to total attempts',
      metric: 'payment_attempts_total',
      goodEvent: 'result="success"',
      badEvent: 'result="failure"',
      aggregation: 'rate',
    },
    target: 0.999,
    window: '7d',
    errorBudget: 0.001,
    severity: 'critical',
  },
];

// Error budget calculation
function calculateErrorBudget(slo: ServiceLevelObjective, totalEvents: number): number {
  return totalEvents * slo.errorBudget;
}
```

### Grafana Dashboard (JSON Model)

```json
{
  "dashboard": {
    "title": "Order Service - SLO Dashboard",
    "tags": ["slo", "order-service"],
    "panels": [
      {
        "title": "Availability (30d)",
        "type": "stat",
        "targets": [{
          "expr": "sum(rate(http_requests_total{status_code!~\"5..\"}[30d])) / sum(rate(http_requests_total[30d]))",
          "legendFormat": "Availability"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percentunit",
            "thresholds": {
              "steps": [
                { "value": 0.99, "color": "red" },
                { "value": 0.999, "color": "yellow" },
                { "value": 0.9995, "color": "green" }
              ]
            }
          }
        }
      },
      {
        "title": "Latency Heatmap",
        "type": "heatmap",
        "targets": [{
          "expr": "sum(rate(http_request_duration_seconds_bucket[5m])) by (le)",
          "format": "heatmap"
        }]
      },
      {
        "title": "Error Budget Burn Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status_code=~\"5..\"}[1h])) / sum(rate(http_requests_total[1h]))",
            "legendFormat": "1h burn rate"
          },
          {
            "expr": "sum(rate(http_requests_total{status_code=~\"5..\"}[6h])) / sum(rate(http_requests_total[6h]))",
            "legendFormat": "6h burn rate"
          }
        ]
      }
    ]
  }
}
```

---

## Structured Logging

### Pino Configuration

```typescript
// logger.ts
import pino from 'pino';
import { randomUUID } from 'crypto';

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label.toUpperCase() }),
    bindings: (bindings) => ({
      pid: bindings.pid,
      host: bindings.hostname,
    }),
    log: (object) => {
      // Redact sensitive fields
      if (object.password) object.password = '[REDACTED]';
      if (object.token) object.token = '[REDACTED]';
      if (object['x-api-key']) object['x-api-key'] = '[REDACTED]';
      return object;
    },
  },
  base: {
    service: 'order-service',
    version: process.env.SERVICE_VERSION || 'unknown',
    environment: process.env.NODE_ENV || 'development',
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  // Transport for pretty-printing in dev, JSON in prod
  transport: process.env.NODE_ENV !== 'production'
    ? { target: 'pino-pretty', options: { colorize: true } }
    : undefined,
});

// Request-scoped logger with correlation ID
export function getRequestLogger(req: Request): pino.Logger {
  const correlationId = req.headers['x-correlation-id'] || randomUUID();
  return logger.child({
    correlationId,
    traceId: req.headers['x-trace-id'],
    spanId: req.headers['x-span-id'],
    requestId: req.id,
    userId: req.user?.id,
  });
}

export default logger;
```

### Log Levels and Usage

```typescript
// logging-patterns.ts
import logger from './logger';

class OrderService {
  private log = logger.child({ component: 'OrderService' });

  async createOrder(userId: string, data: CreateOrderDto): Promise<Order> {
    this.log.info({ userId, itemCount: data.items.length }, 'Creating order');

    try {
      const order = await this.db.order.create({ data: { userId, ...data } });
      this.log.info({ orderId: order.id }, 'Order created successfully');
      return order;
    } catch (error) {
      this.log.error({ error: error.message, userId, stack: error.stack }, 'Failed to create order');
      throw error;
    }
  }

  async processPayment(orderId: string, amount: number): Promise<PaymentResult> {
    this.log.debug({ orderId, amount }, 'Processing payment');

    const payment = await this.paymentProvider.charge({ orderId, amount });

    if (payment.status === 'declined') {
      this.log.warn({ orderId, reason: payment.declineReason }, 'Payment declined');
    } else {
      this.log.info({ orderId, transactionId: payment.id }, 'Payment processed');
    }

    return payment;
  }
}
```

### Log Aggregation with Loki

```yaml
# loki-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /tmp/loki/index
  filesystem:
    directory: /tmp/loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

```yaml
# promtail-config.yaml (log shipper)
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: order-service
    static_configs:
      - targets:
          - localhost
        labels:
          job: order-service
          __path__: /var/log/order-service/*.log
    pipeline_stages:
      - json:
          expressions:
            level: level
            message: msg
            correlationId: correlationId
            traceId: traceId
      - labels:
          level:
          correlationId:
```

---

## Alerting

### PagerDuty Integration

```typescript
// alerting.ts
import axios from 'axios';

interface Alert {
  severity: 'critical' | 'warning' | 'info';
  summary: string;
  description: string;
  source: string;
  triggeredAt: Date;
  labels: Record<string, string>;
  runbookUrl: string;
  dashboardUrl: string;
}

class AlertManager {
  private pagerDutyKey: string;
  private slackWebhook: string;
  private opsgenieKey: string;

  async sendAlert(alert: Alert): Promise<void> {
    // Parallel notification to multiple channels
    await Promise.all([
      this.sendPagerDuty(alert),
      this.sendSlack(alert),
      this.sendOpsgenie(alert),
    ]);
  }

  private async sendPagerDuty(alert: Alert): Promise<void> {
    const severityMap = {
      critical: 'critical',
      warning: 'warning',
      info: 'info',
    };

    await axios.post('https://events.pagerduty.com/v2/enqueue', {
      routing_key: this.pagerDutyKey,
      event_action: 'trigger',
      dedup_key: `${alert.source}-${alert.labels.alertname}`,
      payload: {
        summary: alert.summary,
        severity: severityMap[alert.severity],
        source: alert.source,
        custom_details: {
          description: alert.description,
          ...alert.labels,
          runbook: alert.runbookUrl,
          dashboard: alert.dashboardUrl,
        },
      },
    });
  }

  private async sendSlack(alert: Alert): Promise<void> {
    const colorMap = {
      critical: '#FF0000',
      warning: '#FFCC00',
      info: '#36A64F',
    };

    await axios.post(this.slackWebhook, {
      attachments: [{
        color: colorMap[alert.severity],
        title: alert.summary,
        text: alert.description,
        fields: Object.entries(alert.labels).map(([key, value]) => ({
          title: key,
          value: String(value),
          short: true,
        })),
        actions: [
          { type: 'button', text: 'Runbook', url: alert.runbookUrl },
          { type: 'button', text: 'Dashboard', url: alert.dashboardUrl },
        ],
        footer: alert.source,
        ts: Math.floor(alert.triggeredAt.getTime() / 1000),
      }],
    });
  }
}
```

### Alert Routing Rules

```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alerts@example.com'

route:
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default'
  routes:
    - match:
        severity: critical
        team: platform
      receiver: 'platform-critical'
      group_wait: 0s
      continue: true
    - match:
        severity: warning
        team: platform
      receiver: 'platform-warning'
    - match:
        severity: critical
        team: product
      receiver: 'product-critical'
      continue: true
    - match:
        alertname: 'HighLatency'
      receiver: 'sre-oncall'
      group_wait: 2m

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']

receivers:
  - name: 'default'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/...'
        channel: '#alerts'
  - name: 'platform-critical'
    pagerduty_configs:
      - service_key: '<platform-key>'
    slack_configs:
      - channel: '#platform-critical'
        send_resolved: true
  - name: 'sre-oncall'
    opsgenie_configs:
      - api_key: '<opsgenie-key>'
        priority: P1
        teams: ['SRE']
```

### On-Call Rotation

```yaml
# oncall-schedule.yaml (example using PagerDuty or Opsgenie)
schedule:
  name: "Platform Engineering On-Call"
  timezone: "America/New_York"
  rotations:
    - name: "Primary"
      participants:
        - alice@example.com
        - bob@example.com
        - charlie@example.com
      rotation:
        type: "weekly"
        start_date: "2024-01-01"
        handoff_time: "09:00"
    - name: "Secondary"
      participants:
        - dave@example.com
        - eve@example.com
      rotation:
        type: "weekly"
        start_date: "2024-01-01"
        handoff_time: "09:00"
        # Secondary follows primary with 1 week offset

escalation_policy:
  name: "Platform Critical"
  rules:
    - notify: "Primary on-call"
      after: 0s
    - notify: "Secondary on-call"
      after: 5m
    - notify: "Engineering Manager"
      after: 15m
    - notify: "CTO"
      after: 30m
```

---

## Error Tracking

### Sentry Setup

```typescript
// sentry.ts
import * as Sentry from '@sentry/node';
import { ProfilingIntegration } from '@sentry/profiling-node';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.SERVICE_VERSION,
  integrations: [
    new Sentry.Integrations.Http({ tracing: true }),
    new Sentry.Integrations.Express({ app }),
    new Sentry.Integrations.Postgres(),
    new Sentry.Integrations.Redis(),
    new ProfilingIntegration(),
  ],
  tracesSampleRate: 0.1,        // 10% of transactions for performance
  profilesSampleRate: 0.1,      // 10% of profiles
  beforeSend(event) {
    // Sanitize sensitive data before sending
    if (event.request?.headers?.['x-api-key']) {
      event.request.headers['x-api-key'] = '[REDACTED]';
    }
    if (event.request?.data?.password) {
      event.request.data.password = '[REDACTED]';
    }
    return event;
  },
  ignoreErrors: [
    'NetworkError',
    'AbortError',
    'ResizeObserver loop limit exceeded',
  ],
});

// Express error handler
app.use(Sentry.Handlers.errorHandler());
```

### Source Maps Upload

```bash
# Build step: upload source maps to Sentry
npx @sentry/cli sourcemaps upload \
  --release $(git rev-parse --short HEAD) \
  --url-prefix '~/dist' \
  ./dist

# In CI/CD
- name: Upload source maps
  run: |
    export SENTRY_RELEASE=$(git rev-parse --short HEAD)
    npx @sentry/cli sourcemaps upload \
      --release $SENTRY_RELEASE \
      --url-prefix '~/dist' \
      ./dist
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
    SENTRY_ORG: my-org
    SENTRY_PROJECT: my-project
```

### Release Tracking

```typescript
// release-tracking.ts
async function notifySentryOfRelease(version: string, commits: Commit[]): Promise<void> {
  await Sentry.init({
    dsn: process.env.SENTRY_DSN,
    release: version,
  });

  // Associate commits with release for better context
  await Sentry.releases.setCommits(version, {
    repo: 'my-org/my-repo',
    commit: version,
    previousCommit: commits[commits.length - 1]?.sha,
    authors: commits.map(c => c.author),
  });

  // Mark deployment
  await Sentry.releases.newDeploy(version, {
    environment: process.env.NODE_ENV,
    name: `Deploy v${version}`,
  });
}
```

---

## Health Checks

### Kubernetes Probes

```typescript
// health-checks.ts
import express from 'express';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

const app = express();
const prisma = new PrismaClient();
const redis = new Redis({ host: 'redis' });

// Liveness: Is the process running?
app.get('/health/live', (req, res) => {
  res.status(200).json({ status: 'alive', timestamp: new Date().toISOString() });
});

// Readiness: Is the app ready to serve traffic?
app.get('/health/ready', async (req, res) => {
  const checks = await Promise.allSettled([
    checkDatabase(),
    checkRedis(),
    checkExternalAPI(),
  ]);

  const results = {
    database: checks[0].status === 'fulfilled' ? 'ok' : 'failed',
    redis: checks[1].status === 'fulfilled' ? 'ok' : 'failed',
    externalAPI: checks[2].status === 'fulfilled' ? 'ok' : 'failed',
  };

  const allReady = Object.values(results).every(r => r === 'ok');
  res.status(allReady ? 200 : 503).json({ status: allReady ? 'ready' : 'not_ready', checks: results });
});

// Startup: Has the app finished initializing?
app.get('/health/startup', async (req, res) => {
  // Check if migrations have run, caches are warmed, etc.
  const migrationsComplete = await checkMigrations();
  const cachesWarmed = await checkCaches();

  if (migrationsComplete && cachesWarmed) {
    res.status(200).json({ status: 'started' });
  } else {
    res.status(503).json({ status: 'starting', migrationsComplete, cachesWarmed });
  }
});

async function checkDatabase(): Promise<void> {
  await prisma.$queryRaw`SELECT 1`;
}

async function checkRedis(): Promise<void> {
  await redis.ping();
}

async function checkExternalAPI(): Promise<void> {
  const response = await fetch('https://api.partner.com/health', { timeout: 5000 });
  if (!response.ok) throw new Error('External API unhealthy');
}

async function checkMigrations(): Promise<boolean> {
  const pending = await prisma.$queryRaw`
    SELECT COUNT(*) FROM _prisma_migrations WHERE finished_at IS NULL
  `;
  return Number(pending[0].count) === 0;
}

async function checkCaches(): Promise<boolean> {
  // Implementation-specific
  return true;
}
```

```yaml
# kubernetes-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  template:
