const Redis = require('ioredis');

// Use environment variables for flexibility
const redisConfig = {
    host: process.env.REDIS_HOST || 'mw-redis',
    port: process.env.REDIS_PORT || 6379,
    retryStrategy: (times) => {
        // Strategic retry: wait longer after each failed attempt
        return Math.min(times * 50, 2000);
    }
};

const redis = new Redis(redisConfig);

// Connection Listeners for deep monitoring
redis.on('connect', () => {
    console.log('✅ [Redis] Connection established successfully.');
});

redis.on('error', (err) => {
    console.error('❌ [Redis] Connection error:', err.message);
});

module.exports = redis;
