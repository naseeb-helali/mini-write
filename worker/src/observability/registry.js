const client = require('prom-client');
const { defaultLabels } = require('./labels');

const register = new client.Registry();

register.setDefaultLabels(defaultLabels);

client.collectDefaultMetrics({
  register,
  prefix: 'mw_'
});

module.exports = {
  client,
  register
};