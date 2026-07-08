const {
  httpRequestsTotal,
  httpRequestDurationSeconds,
  httpRequestsInFlight,
  httpErrorsTotal
} = require('../metrics');

function classifyError(statusCode) {
  if (statusCode === 401) return 'authentication';

  if (statusCode === 403) return 'authorization';

  if (statusCode === 408) return 'timeout';

  if (statusCode >= 400 && statusCode < 500) {
    return 'validation';
  }

  if (statusCode >= 500) {
    return 'internal';
  }

  return 'unknown';
}

function metricsMiddleware(req, res, next) {

  if (req.path === '/metrics') {
    return next();
  }

  httpRequestsInFlight.inc();

  const endTimer = httpRequestDurationSeconds.startTimer();

  res.on('finish', () => {
    try {
      const method = req.method;

      const route = req.route?.path || 'not_found';

      const statusCode = String(res.statusCode);

      const labels = {
        method,
        route,
        status_code: statusCode
      };

      httpRequestsTotal.inc(labels);

      endTimer(labels);

      if (res.statusCode >= 400) {
        httpErrorsTotal.inc({
          ...labels,
          error_type: classifyError(res.statusCode)
        });
      }
    } finally {
      httpRequestsInFlight.dec();
    }
  });

  next();
}

module.exports = metricsMiddleware;