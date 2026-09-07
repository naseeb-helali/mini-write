const Redis = require('ioredis');

const redisConfig = {
  host:
    process.env.REDIS_HOST,

  port:
    parseInt(
      process.env.REDIS_PORT,
      10
    ) || 6379,

  password:
    process.env.REDIS_PASSWORD,

  retryStrategy: (times) =>
    Math.min(times * 50, 2000),

  maxRetriesPerRequest: null,

  keepAlive: 10000
};

const redisConnection =
  new Redis(redisConfig);

redisConnection.on(
  'connect',
  () =>
    console.log(
      '📡 [Worker-Redis] Connection attempt initiated...'
    )
);

redisConnection.on(
  'ready',
  () =>
    console.log(
      '✅ [Worker-Redis] Ready and listening for jobs.'
    )
);

redisConnection.on(
  'error',
  (err) =>
    console.error(
      '❌ [Worker-Redis] Critical Error:',
      err.message
    )
);

redisConnection.on(
  'reconnecting',
  () =>
    console.warn(
      '⚠️ [Worker-Redis] Connection lost. Attempting to reconnect...'
    )
);

module.exports = redisConnection;