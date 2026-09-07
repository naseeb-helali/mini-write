const pool = require('../config/db');
const storageProvider = require('../storage');
const redisConnection = require('../config/redis');

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
const storageBucket =
  process.env.STORAGE_INPUT_BUCKET ||
  'user-documents';

const checkStorage = async () => {
  try {
    await storageProvider.checkHealth(
      storageBucket
    );

    return {
      status: 'UP'
    };
  } catch (err) {
    return {
      status: 'DOWN',
      error: err.message
    };
  }
};

// 🔥 Combined Health Check
const getSystemHealth = async () => {
    const [db, redis, storage] = await Promise.all([
        checkDatabase(),
        checkRedis(),
        checkStorage()
    ]);

    const isHealthy =
        db.status === 'UP' &&
        redis.status === 'UP' &&
        storage.status === 'UP';

    return {
        status: isHealthy ? 'UP' : 'DOWN',
        services: {
            postgres: db,
            redis: redis,
            storage: storage
        },
        timestamp: new Date()
    };
};

module.exports = { getSystemHealth };
