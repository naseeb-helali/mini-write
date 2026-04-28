const Redis = require('ioredis');


const redisConfig = {
    host: process.env.REDIS_HOST || 'mw-redis',
    port: parseInt(process.env.REDIS_PORT) || 6379,

    // Professional Retry Strategy:
    // It will keep trying to reconnect forever with an increasing delay (max 2 seconds)
    retryStrategy: (times) => {
        const delay = Math.min(times * 50, 2000);
        return delay;
    },

    // CRITICAL for BullMQ:
    // This allows the connection to wait for blocking commands without timing out.
    maxRetriesPerRequest: null,

    // Enable keepAlive to prevent unexpected connection drops by the OS
    keepAlive: 10000,
};

const redisConnection = new Redis(redisConfig);

// Monitoring Connection Events
redisConnection.on('connect', () => {
    console.log('📡 [Worker-Redis] Connection attempt initiated...');
});

redisConnection.on('ready', () => {
    console.log('✅ [Worker-Redis] Ready and listening for jobs.');
});

redisConnection.on('error', (err) => {
    console.error('❌ [Worker-Redis] Critical Error:', err.message);
});

redisConnection.on('reconnecting', () => {
    console.warn('⚠️ [Worker-Redis] Connection lost. Attempting to reconnect...');
});

module.exports = redisConnection;
