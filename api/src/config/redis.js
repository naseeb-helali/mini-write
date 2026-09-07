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
    Math.min(times * 50, 2000)
};

const redis = new Redis(redisConfig);

redis.on(
  'connect',
  () =>
    console.log(
      '✅ [Redis] Connection established successfully.'
    )
);

redis.on(
  'error',
  (err) =>
    console.error(
      '❌ [Redis] Connection error:',
      err.message
    )
);

module.exports = redis;