const client = require('prom-client');

const registry = new client.Registry();

client.collectDefaultMetrics({
  register: registry,
  prefix: 'mw_',
  labels: {
    service: 'api',
    environment: process.env.NODE_ENV || 'development',
    version: process.env.APP_VERSION || '1.0.0'
  }
});

registry.setDefaultLabels({
  service: 'api',
  environment: process.env.NODE_ENV || 'development',
  version: process.env.APP_VERSION || '1.0.0'
});

module.exports = registry;