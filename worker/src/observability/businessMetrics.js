const client = require('prom-client');

const { register } = require('./registry');
const { defaultLabels } = require('./labels');

const commonLabels = Object.keys(defaultLabels);

const businessIdCardsVerifiedTotal = new client.Counter({
  name: 'mw_business_id_cards_verified_total',
  help: 'Total successfully verified ID cards',
  labelNames: [...commonLabels],
  registers: [register]
});

const businessIdCardsSkippedTotal = new client.Counter({
  name: 'mw_business_id_cards_skipped_total',
  help: 'Total skipped ID card processing jobs',
  labelNames: ['reason', ...commonLabels],
  registers: [register]
});

const imageProcessingDuration = new client.Histogram({
  name: 'mw_worker_image_processing_duration_seconds',
  help: 'Image processing duration in seconds',
  labelNames: ['status', ...commonLabels],
  buckets: [
    0.01,
    0.05,
    0.1,
    0.25,
    0.5,
    1,
    2,
    5,
    10
  ],
  registers: [register]
});

module.exports = {
  businessIdCardsVerifiedTotal,
  businessIdCardsSkippedTotal,
  imageProcessingDuration
};