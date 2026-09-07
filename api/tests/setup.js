// Environment required for tests

process.env.STORAGE_PROVIDER = 'minio';
process.env.STORAGE_INPUT_BUCKET = 'user-documents';

process.env.MINIO_ENDPOINT = 'localhost';
process.env.MINIO_PORT = '9000';

process.env.MINIO_ROOT_USER = 'test_user';
process.env.MINIO_ROOT_PASSWORD = 'test_password';

process.env.JWT_SECRET = 'test_secret';
process.env.JWT_EXPIRY = '1h';

process.env.POSTGRES_HOST = 'localhost';

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
  const mockMinioClient = {
    putObject: jest.fn().mockResolvedValue({ etag: '123' }),
    getObject: jest.fn(),
    statObject: jest.fn().mockResolvedValue({ size: 100 })
  };

  return {
    Client: jest.fn().mockImplementation(() => mockMinioClient),
    __mockMinioClient: mockMinioClient
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