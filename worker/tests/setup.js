// 1. تعريف المتغيرات البيئية اللازمة للمعالج 
process.env.MINIO_BUCKET_NAME = 'uploads';
process.env.MINIO_PROCESSED_BUCKET = 'processed';
process.env.NODE_ENV = 'test';

// 2. محاكاة مكتبة PostgreSQL (pg) 
jest.mock('../src/config/db', () => ({
  connect: jest.fn(() => ({
    query: jest.fn(),
    release: jest.fn()
  })),
  query: jest.fn()
}));

// 3. محاكاة مكتبة MinIO [cite: 25, 30]
jest.mock('../src/config/storage', () => ({
  getObject: jest.fn(),
  putObject: jest.fn()
}));

// 4. محاكاة مكتبة Sharp (لمنع استهلاك CPU حقيقي) 
jest.mock('sharp', () => {
  return jest.fn(() => ({
    resize: jest.fn().mockReturnThis(),
    jpeg: jest.fn().mockReturnThis(),
    rotate: jest.fn().mockReturnThis(),
    toBuffer: jest.fn().mockResolvedValue(Buffer.from('fake-processed-image'))
  }));
});

// 5. محاكاة BullMQ (لمنع تشغيل الـ Worker الحقيقي) [cite: 3]
jest.mock('bullmq', () => ({
  Worker: jest.fn().mockImplementation(() => ({
    on: jest.fn(),
    close: jest.fn()
  }))
}));