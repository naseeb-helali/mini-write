module.exports = {
  defaultLabels: {
    service: 'worker',
    environment: process.env.NODE_ENV || 'development',
    version: process.env.APP_VERSION || '1.0.0'
  }
};