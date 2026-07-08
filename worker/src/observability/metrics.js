const client = require('prom-client');

const { register } = require('./registry');
const { defaultLabels } = require('./labels');

const commonLabels = Object.keys(defaultLabels);

/*
|--------------------------------------------------------------------------
| Job Lifecycle Metrics
|--------------------------------------------------------------------------
*/

const jobsProcessedTotal = new client.Counter({
  name: 'mw_worker_jobs_processed_total',
  help: 'Total number of processed jobs',
  labelNames: ['job_type', 'status', ...commonLabels],
  registers: [register]
});

const jobFailuresTotal = new client.Counter({
  name: 'mw_worker_job_failures_total',
  help: 'Total number of failed jobs',
  labelNames: ['job_type', 'error_type', ...commonLabels],
  registers: [register]
});

const jobsRetriedTotal = new client.Counter({
  name: 'mw_worker_jobs_retried_total',
  help: 'Total number of retried jobs',
  labelNames: ['job_type', ...commonLabels],
  registers: [register]
});

/*
|--------------------------------------------------------------------------
| Queue Metrics
|--------------------------------------------------------------------------
*/

const queueDepth = new client.Gauge({
  name: 'mw_worker_queue_depth',
  help: 'Current number of waiting jobs',
  labelNames: ['queue_name', ...commonLabels],
  registers: [register]
});

const jobsActive = new client.Gauge({
  name: 'mw_worker_jobs_active',
  help: 'Current number of active jobs',
  labelNames: ['queue_name', ...commonLabels],
  registers: [register]
});

const queuePaused = new client.Gauge({
  name: 'mw_worker_queue_paused',
  help: 'Queue paused status (0=running, 1=paused)',
  labelNames: ['queue_name', ...commonLabels],
  registers: [register]
});

/*
|--------------------------------------------------------------------------
| Performance Metrics
|--------------------------------------------------------------------------
*/

const jobDuration = new client.Histogram({
  name: 'mw_worker_job_duration_seconds',
  help: 'Job processing duration in seconds',
  labelNames: ['job_type', 'status', ...commonLabels],
  buckets: [
    0.1,
    0.5,
    1,
    2.5,
    5,
    10,
    30,
    60,
    120,
    300
  ],
  registers: [register]
});

const fileSize = new client.Histogram({
  name: 'mw_worker_file_size_bytes',
  help: 'Processed file size in bytes',
  labelNames: ['job_type', ...commonLabels],
  buckets: [
    102400,
    512000,
    1048576,
    5242880,
    10485760,
    52428800
  ],
  registers: [register]
});

/*
|--------------------------------------------------------------------------
| Storage Metrics
|--------------------------------------------------------------------------
*/

const storageOperationsTotal = new client.Counter({
  name: 'mw_worker_storage_operations_total',
  help: 'Total object storage operations',
  labelNames: ['operation', 'status', ...commonLabels],
  registers: [register]
});

const storageDuration = new client.Histogram({
  name: 'mw_worker_storage_duration_seconds',
  help: 'Object storage operation duration',
  labelNames: ['operation', ...commonLabels],
  buckets: [
    0.01,
    0.05,
    0.1,
    0.25,
    0.5,
    1,
    2.5,
    5
  ],
  registers: [register]
});

/*
|--------------------------------------------------------------------------
| Database Metrics
|--------------------------------------------------------------------------
*/

const databaseOperationsTotal = new client.Counter({
  name: 'mw_worker_database_operations_total',
  help: 'Total database operations',
  labelNames: ['operation', 'status', ...commonLabels],
  registers: [register]
});

const databaseDuration = new client.Histogram({
  name: 'mw_worker_database_duration_seconds',
  help: 'Database operation duration',
  labelNames: ['operation', ...commonLabels],
  buckets: [
    0.005,
    0.01,
    0.025,
    0.05,
    0.1,
    0.25,
    0.5,
    1
  ],
  registers: [register]
});

/*
|--------------------------------------------------------------------------
| Runtime Protection Metrics
|--------------------------------------------------------------------------
*/

const memoryPressureTotal = new client.Counter({
  name: 'mw_worker_memory_pressure_total',
  help: 'Memory pressure events',
  labelNames: [...commonLabels],
  registers: [register]
});

const eventLoopLag = new client.Gauge({
  name: 'mw_worker_event_loop_lag_seconds',
  help: 'Current event loop lag',
  labelNames: [...commonLabels],
  registers: [register]
});

module.exports = {
  jobsProcessedTotal,
  jobFailuresTotal,
  jobsRetriedTotal,

  queueDepth,
  jobsActive,
  queuePaused,

  jobDuration,
  fileSize,

  storageOperationsTotal,
  storageDuration,

  databaseOperationsTotal,
  databaseDuration,

  memoryPressureTotal,
  eventLoopLag
};