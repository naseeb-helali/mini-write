const pool = require('../config/db');
const storageProvider = require('../storage');
const redisConnection = require('../config/redis');

// =========================================================
// PostgreSQL Health Check
// =========================================================

const checkDatabase = async () => {
  try {
    await pool.query('SELECT 1');

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

// =========================================================
// Redis Health Check
// =========================================================

const checkRedis = async () => {
  try {
    await redisConnection.ping();

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

// =========================================================
// Object Storage Health Check
// =========================================================

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

// =========================================================
// Combined Worker Readiness
// =========================================================

const getWorkerHealth = async () => {
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
      redis,
      storage
    },

    timestamp: new Date()
  };
};

module.exports = {
  checkDatabase,
  checkRedis,
  checkStorage,
  getWorkerHealth
};