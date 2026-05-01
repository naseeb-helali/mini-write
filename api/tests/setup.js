// منع الانهيار بسبب غياب المتغيرات البيئية
process.env.MINIO_ENDPOINT = 'localhost';
process.env.MINIO_PORT = '9000';
process.env.JWT_SECRET = 'test_secret';
process.env.POSTGRES_HOST = 'localhost';
// أضف هذا السطر مع بقية المتغيرات في ملف setup.js
process.env.JWT_EXPIRES_IN = '1h';

// 2. Mock مكتبة PostgreSQL (pg)
jest.mock('pg', () => {
  const mPool = {
    connect: jest.fn(),
    query: jest.fn().mockResolvedValue({ rows: [], rowCount: 0 }),
    on: jest.fn(),
    end: jest.fn(),
  };
  return { Pool: jest.fn(() => mPool) };
});

// 3. Mock مكتبة Redis (ioredis)
jest.mock('ioredis', () => {
  return jest.fn().mockImplementation(() => ({
    get: jest.fn().mockResolvedValue(null),
    set: jest.fn().mockResolvedValue('OK'),
    on: jest.fn(),
  }));
});

// 4. Mock مكتبة MinIO (Storage)
jest.mock('minio', () => {
  return {
    Client: jest.fn().mockImplementation(() => ({
      bucketExists: jest.fn().mockResolvedValue(true),
      makeBucket: jest.fn().mockResolvedValue(true),
      putObject: jest.fn().mockResolvedValue({ etag: '123' }),
      statObject: jest.fn().mockResolvedValue({ size: 100 }),
    }))
  };
});

// 5. Mock مكتبة BullMQ (Queues)
jest.mock('bullmq', () => ({
  Queue: jest.fn().mockImplementation(() => ({
    add: jest.fn().mockResolvedValue({ id: 'job_123' }),
  })),
  Worker: jest.fn().mockImplementation(() => ({
    on: jest.fn(),
  })),
}));