// K6 Load Testing Script for Demo App
// Validates platform performance under various load conditions

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const requestDuration = new Trend('request_duration');
const successfulRequests = new Counter('successful_requests');
const failedRequests = new Counter('failed_requests');

// Test configuration
export const options = {
  stages: [
    // Ramp-up: Gradually increase load
    { duration: '2m', target: 10 },   // Ramp to 10 users over 2 minutes
    { duration: '5m', target: 50 },   // Ramp to 50 users over 5 minutes
    { duration: '10m', target: 100 }, // Ramp to 100 users over 10 minutes

    // Sustained load
    { duration: '10m', target: 100 }, // Hold 100 users for 10 minutes

    // Spike test
    { duration: '1m', target: 200 },  // Spike to 200 users
    { duration: '3m', target: 200 },  // Hold spike

    // Ramp-down
    { duration: '2m', target: 50 },   // Cool down to 50 users
    { duration: '2m', target: 0 },    // Ramp down to 0
  ],

  thresholds: {
    // Performance SLOs
    'http_req_duration': ['p(95)<500', 'p(99)<1000'], // 95th percentile < 500ms, 99th < 1s
    'http_req_failed': ['rate<0.01'],                  // Error rate < 1%
    'errors': ['rate<0.01'],                           // Custom error rate < 1%
    'http_req_duration{scenario:health}': ['p(95)<100'], // Health endpoint < 100ms
    'http_req_duration{scenario:metrics}': ['p(95)<200'], // Metrics endpoint < 200ms
  },

  // External metrics integration
  ext: {
    loadimpact: {
      projectID: 3651270,
      name: 'Demo App Load Test',
    },
  },
};

// Base URL (can be overridden via environment variable)
const BASE_URL = __ENV.BASE_URL || 'http://demo-app.demo.svc.cluster.local:8080';

// Scenario: Test health endpoint
export function healthCheck() {
  const tags = { scenario: 'health' };

  const res = http.get(`${BASE_URL}/health`, { tags });

  const success = check(res, {
    'health check status is 200': (r) => r.status === 200,
    'health check returns JSON': (r) => r.headers['Content-Type'].includes('application/json'),
    'health check has status field': (r) => JSON.parse(r.body).status === 'ok',
  });

  errorRate.add(!success);
  requestDuration.add(res.timings.duration, tags);

  if (success) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
  }

  sleep(1);
}

// Scenario: Test metrics endpoint
export function metricsCheck() {
  const tags = { scenario: 'metrics' };

  const res = http.get(`${BASE_URL}/metrics`, { tags });

  const success = check(res, {
    'metrics endpoint status is 200': (r) => r.status === 200,
    'metrics returns Prometheus format': (r) => r.body.includes('# HELP'),
    'metrics includes http_requests_total': (r) => r.body.includes('http_requests_total'),
  });

  errorRate.add(!success);
  requestDuration.add(res.timings.duration, tags);

  if (success) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
  }

  sleep(2);
}

// Scenario: Test API endpoints
export function apiLoadTest() {
  const tags = { scenario: 'api' };

  // Test GET request
  const getRes = http.get(`${BASE_URL}/`, { tags });

  const getSuccess = check(getRes, {
    'GET / status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  errorRate.add(!getSuccess);
  requestDuration.add(getRes.timings.duration, tags);

  if (getSuccess) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
  }

  // Test distributed tracing headers
  const traceHeaders = {
    'x-request-id': `k6-${__VU}-${__ITER}`,
    'x-b3-traceid': generateTraceId(),
    'x-b3-spanid': generateSpanId(),
    'x-b3-sampled': '1',
  };

  const tracedRes = http.get(`${BASE_URL}/`, {
    headers: traceHeaders,
    tags: { ...tags, traced: 'true' },
  });

  check(tracedRes, {
    'traced request includes trace headers': (r) => r.headers['X-Request-Id'] !== undefined,
  });

  sleep(1);
}

// Scenario: Stress test - sustained high load
export function stressTest() {
  const tags = { scenario: 'stress' };

  const batch = http.batch([
    ['GET', `${BASE_URL}/`, null, { tags }],
    ['GET', `${BASE_URL}/health`, null, { tags }],
    ['GET', `${BASE_URL}/metrics`, null, { tags }],
  ]);

  batch.forEach((res) => {
    const success = check(res, {
      'batch request status is 200': (r) => r.status === 200,
    });

    errorRate.add(!success);
    requestDuration.add(res.timings.duration, tags);

    if (success) {
      successfulRequests.add(1);
    } else {
      failedRequests.add(1);
    }
  });

  sleep(0.5);
}

// Default test function
export default function () {
  // Randomly execute different scenarios
  const scenario = Math.random();

  if (scenario < 0.4) {
    healthCheck();
  } else if (scenario < 0.6) {
    metricsCheck();
  } else if (scenario < 0.9) {
    apiLoadTest();
  } else {
    stressTest();
  }
}

// Teardown function - runs once at the end
export function teardown(data) {
  console.log('Load test completed');
  console.log(`Successful requests: ${successfulRequests.count}`);
  console.log(`Failed requests: ${failedRequests.count}`);
}

// Helper: Generate random trace ID
function generateTraceId() {
  return Math.random().toString(36).substring(2, 18);
}

// Helper: Generate random span ID
function generateSpanId() {
  return Math.random().toString(36).substring(2, 10);
}
