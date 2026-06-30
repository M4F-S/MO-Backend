#!/usr/bin/env bash
# =============================================================================
# load-test.sh — k6-based load testing with dynamic script generation
#
# Usage: ./load-test.sh <endpoint_url> [vus] [duration] [output_dir]
#   endpoint_url: Base URL to test (e.g., http://localhost:8080)
#   vus:          Number of virtual users (default: 10)
#   duration:     Test duration, e.g., 30s, 1m, 5m (default: 1m)
#   output_dir:   Where to write reports (default: ./load-test-results)
#
# Requirements: k6 must be installed (https://k6.io/docs/get-started/installation/)
# =============================================================================

set -euo pipefail

# ── Arguments ─────────────────────────────────────────────────────────────
ENDPOINT_URL="${1:-}"
VUS="${2:-10}"
DURATION="${3:-1m}"
OUTPUT_DIR="${4:-./load-test-results}"

if [[ -z "$ENDPOINT_URL" ]]; then
    cat << 'USAGE' >&2
Usage: $0 <endpoint_url> [vus] [duration] [output_dir]

  endpoint_url  Base URL to test (e.g., http://localhost:8080)
  vus           Number of virtual users (default: 10)
  duration      Test duration: 30s, 1m, 5m (default: 1m)
  output_dir    Directory for reports (default: ./load-test-results)

Examples:
  $0 http://localhost:8080
  $0 http://api.example.com 50 5m ./reports
USAGE
    exit 1
fi

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
step()  { echo -e "${BLUE}[STEP]${NC} $*"; }

# ── Check prerequisites ─────────────────────────────────────────────────────
if ! command -v k6 &>/dev/null; then
    error "k6 is not installed. Please install it: https://k6.io/docs/get-started/installation/"
    exit 1
fi

info "k6 version: $(k6 version 2>/dev/null | head -1)"

# ── Setup output directory ──────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_DIR="${OUTPUT_DIR}/${TIMESTAMP}"
mkdir -p "$RESULT_DIR"

info "Results will be saved to: $RESULT_DIR"

# ── Generate k6 test script dynamically ───────────────────────────────────
step "Generating k6 test script for ${ENDPOINT_URL}…"

K6_SCRIPT="${RESULT_DIR}/load-test.js"

cat > "$K6_SCRIPT" << EOF
// =============================================================================
// Auto-generated k6 load test script
// Generated: $(date -Iseconds)
// Target: ${ENDPOINT_URL}
// VUs: ${VUS}, Duration: ${DURATION}
// =============================================================================

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { htmlReport } from 'https://raw.githubusercontent.com/benc-uk/k6-reporter/2.4.0/dist/bundle.js';

// ── Custom metrics ───────────────────────────────────────────────────────────
const errorRate = new Rate('errors');
const responseTimeTrend = new Trend('response_time');
const requestCounter = new Counter('requests');

// ── Test options ───────────────────────────────────────────────────────────
export const options = {
  stages: [
    { duration: '10s', target: ${VUS} },          // Ramp up
    { duration: '${DURATION}', target: ${VUS} },   // Steady state
    { duration: '10s', target: 0 },                // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(50)<200', 'p(95)<500', 'p(99)<1000'], // ms
    http_req_failed: ['rate<0.01'],                              // <1% errors
    errors: ['rate<0.01'],
  },
};

const BASE_URL = '${ENDPOINT_URL}';

// ── Helper: perform check ──────────────────────────────────────────────────
function performCheck(res, expectedStatus) {
  const success = check(res, {
    ['status is ' + expectedStatus]: (r) => r.status === expectedStatus,
    ['response time < 1000ms']: (r) => r.timings.duration < 1000,
  });
  errorRate.add(!success);
  responseTimeTrend.add(res.timings.duration);
  requestCounter.add(1);
  return success;
}

// ── Test scenarios ───────────────────────────────────────────────────────────
export default function () {
  group('GET /health', () => {
    const res = http.get(\`\${BASE_URL}/health\`);
    performCheck(res, 200);
    sleep(0.5);
  });

  group('GET /api/users', () => {
    const res = http.get(\`\${BASE_URL}/api/users\`);
    performCheck(res, 200);
    sleep(0.5);
  });

  group('POST /api/users', () => {
    const payload = JSON.stringify({
      email: \`user_\${__VU}_\${__ITER}@test.com\`,
      username: \`user_\${__VU}_\${__ITER}\`,
      password: 'password123',
      role: 'user',
    });
    const res = http.post(\`\${BASE_URL}/api/users\`, payload, {
      headers: { 'Content-Type': 'application/json' },
    });
    performCheck(res, 201);
    sleep(0.5);
  });

  group('GET /api/products', () => {
    const res = http.get(\`\${BASE_URL}/api/products\`);
    performCheck(res, 200);
    sleep(0.5);
  });

  group('POST /api/products', () => {
    const payload = JSON.stringify({
      name: \`Product \${__VU}_\${__ITER}\`,
      description: 'Auto-generated test product',
      category: 'test',
      price: 19.99 + (__ITER % 100),
      stock: 100,
    });
    const res = http.post(\`\${BASE_URL}/api/products\`, payload, {
      headers: { 'Content-Type': 'application/json' },
    });
    performCheck(res, 201);
    sleep(0.5);
  });

  group('PUT /api/products/:id', () => {
    // Simulate update with a fixed ID pattern
    const id = '550e8400-e29b-41d4-a716-44665544000' + (__VU % 10);
    const payload = JSON.stringify({
      name: 'Updated Product',
      price: 29.99,
    });
    const res = http.put(\`\${BASE_URL}/api/products/\${id}\`, payload, {
      headers: { 'Content-Type': 'application/json' },
    });
    // 200 or 404 are acceptable for this synthetic test
    const success = check(res, {
      'status is 200 or 404': (r) => r.status === 200 || r.status === 404,
    });
    errorRate.add(!success);
    sleep(0.5);
  });

  group('DELETE /api/users/:id', () => {
    const id = '550e8400-e29b-41d4-a716-44665544000' + (__VU % 10);
    const res = http.del(\`\${BASE_URL}/api/users/\${id}\`);
    const success = check(res, {
      'status is 204 or 404': (r) => r.status === 204 || r.status === 404,
    });
    errorRate.add(!success);
    sleep(1);
  });
}

// ── HTML Report handler ────────────────────────────────────────────────────
export function handleSummary(data) {
  return {
    ['${RESULT_DIR}/report.html']: htmlReport(data, { title: 'Load Test Report: ${ENDPOINT_URL}' }),
    ['${RESULT_DIR}/summary.json']: JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

// Need to import textSummary for stdout output
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.3/index.js';
EOF

info "k6 script written to: $K6_SCRIPT"

# ── Run k6 test ─────────────────────────────────────────────────────────────
step "Running load test with ${VUS} VUs for ${DURATION}…"
k6 run --out json="${RESULT_DIR}/metrics.json" "$K6_SCRIPT"

EXIT_CODE=$?

# ── Summary ─────────────────────────────────────────────────────────────────
step "Test complete. Results saved to: ${RESULT_DIR}"
echo ""
echo "  Script:      ${K6_SCRIPT}"
echo "  HTML Report: ${RESULT_DIR}/report.html"
echo "  JSON Data:   ${RESULT_DIR}/summary.json"
echo "  Metrics:     ${RESULT_DIR}/metrics.json"
echo ""

if [[ $EXIT_CODE -eq 0 ]]; then
    info "All checks passed successfully."
else
    warn "Some thresholds may have been breached. Review the HTML report."
fi

exit $EXIT_CODE
