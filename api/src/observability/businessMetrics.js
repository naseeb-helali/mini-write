const { Counter } = require('prom-client');
const registry = require('./registry');

const labels = ['service', 'environment', 'version'];

const commonLabels = {
  service: 'api',
  environment: process.env.NODE_ENV || 'development',
  version: process.env.APP_VERSION || '1.0.0'
};

function createCounter(config) {
  const metric = new Counter({
    ...config,
    labelNames: [...labels, ...(config.labelNames || [])],
    registers: [registry]
  });

  return {
    inc(extraLabels = {}, value = 1) {
      metric.inc({
        ...commonLabels,
        ...extraLabels
      }, value);
    }
  };
}

module.exports = {
  userRegistrations: createCounter({
    name: 'mw_business_user_registrations_total',
    help: 'Total successful user registrations'
  }),

  userLogins: createCounter({
    name: 'mw_business_user_logins_total',
    help: 'Total successful user logins'
  }),

  idUploads: createCounter({
    name: 'mw_business_id_uploads_total',
    help: 'Total ID upload attempts'
  }),

  idUploadSuccess: createCounter({
    name: 'mw_business_id_upload_success_total',
    help: 'Total successful ID uploads'
  }),

  idUploadFailures: createCounter({
    name: 'mw_business_id_upload_failures_total',
    help: 'Total failed ID uploads',
    labelNames: ['reason']
  }),

  jobsEnqueued: createCounter({
    name: 'mw_business_jobs_enqueued_total',
    help: 'Total background jobs enqueued',
    labelNames: ['job_type']
  })
};