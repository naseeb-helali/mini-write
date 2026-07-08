const SERVICE_NAME = 'worker';

const ENVIRONMENT =
  process.env.NODE_ENV || 'development';

function writeLog(level, payload) {
  const logEntry = {
    timestamp: new Date().toISOString(),

    level,

    service: SERVICE_NAME,

    environment: ENVIRONMENT,

    ...payload
  };

  console.log(
    JSON.stringify(logEntry)
  );
}

function info(payload) {
  writeLog('info', payload);
}

function warn(payload) {
  writeLog('warn', payload);
}

function error(payload) {
  writeLog('error', payload);
}

module.exports = {
  info,
  warn,
  error
};