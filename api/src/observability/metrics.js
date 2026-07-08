const client = require('prom-client');
const registry = require('./registry');

// ==========================================================
// Shared Configuration
// ==========================================================

const defaultHistogramBuckets = [
  0.005,
  0.01,
  0.025,
  0.05,
  0.1,
  0.25,
  0.5,
  1,
  2.5,
  5,
  10
];

const uploadSizeBuckets = [
  100 * 1024,
  500 * 1024,
  1024 * 1024,
  5 * 1024 * 1024,
  10 * 1024 * 1024,
  25 * 1024 * 1024,
  50 * 1024 * 1024,
  100 * 1024 * 1024
];

// ==========================================================
// Traffic Metrics
// ==========================================================

const httpRequestsTotal = new client.Counter({
  name: 'mw_api_http_requests_total',
  help: 'Total number of HTTP requests.',
  labelNames: ['method', 'route', 'status_code'],
  registers: [registry]
});

// ==========================================================
// Performance Metrics
// ==========================================================

const httpRequestDurationSeconds = new client.Histogram({
  name: 'mw_api_http_request_duration_seconds',
  help: 'HTTP request duration in seconds.',
  labelNames: ['method', 'route', 'status_code'],
  buckets: defaultHistogramBuckets,
  registers: [registry]
});

const httpRequestsInFlight = new client.Gauge({
  name: 'mw_api_http_requests_in_flight',
  help: 'Current number of in-flight HTTP requests.',
  registers: [registry]
});

// ==========================================================
// Error Metrics
// ==========================================================

const httpErrorsTotal = new client.Counter({
  name: 'mw_api_http_errors_total',
  help: 'Total number of failed HTTP requests.',
  labelNames: [
    'method',
    'route',
    'status_code',
    'error_type'
  ],
  registers: [registry]
});

// ==========================================================
// Business Metrics
// ==========================================================

const authAttemptsTotal = new client.Counter({
  name: 'mw_api_auth_attempts_total',
  help: 'Total number of authentication attempts.',
  labelNames: ['result'],
  registers: [registry]
});

const uploadRequestsTotal = new client.Counter({
  name: 'mw_api_upload_requests_total',
  help: 'Total number of upload requests.',
  labelNames: ['result'],
  registers: [registry]
});

const uploadFileSizeBytes = new client.Histogram({
  name: 'mw_api_upload_file_size_bytes',
  help: 'Uploaded file size distribution in bytes.',
  buckets: uploadSizeBuckets,
  registers: [registry]
});

// ==========================================================
// Exports
// ==========================================================

module.exports = {
  httpRequestsTotal,
  httpRequestDurationSeconds,
  httpRequestsInFlight,
  httpErrorsTotal,
  authAttemptsTotal,
  uploadRequestsTotal,
  uploadFileSizeBytes
};