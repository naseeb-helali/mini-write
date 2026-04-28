const pool = require('../config/db');
const redisConnection = require('../config/redis');
const minioClient = require('../config/storage');

// 🔷 DB Check
const checkDatabase = async () => {
    try {
        await pool.query('SELECT 1');
        return { status: 'UP' };
    } catch (err) {
        return { status: 'DOWN', error: err.message };
    }
};

// 🔷 Redis Check
const checkRedis = async () => {
    try {
        await redisConnection.ping();
        return { status: 'UP' };
    } catch (err) {
        return { status: 'DOWN', error: err.message };
    }
};

// 🔷 MinIO Check
const checkMinIO = async () => {
    try {
        await minioClient.listBuckets();
        return { status: 'UP' };
    } catch (err) {
        return { status: 'DOWN', error: err.message };
    }
};

// 🔥 Combined Health Check
const getSystemHealth = async () => {
    const [db, redis, storage] = await Promise.all([
        checkDatabase(),
        checkRedis(),
        checkMinIO()
    ]);

    const isHealthy =
        db.status === 'UP' &&
        redis.status === 'UP' &&
        storage.status === 'UP';

    return {
        status: isHealthy ? 'UP' : 'DOWN',
        services: {
            database: db,
            redis: redis,
            storage: storage
        },
        timestamp: new Date()
    };
};

module.exports = { getSystemHealth };
