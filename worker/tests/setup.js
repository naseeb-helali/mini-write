// 1. تعريف المتغيرات البيئية اللازمة للمعالج 
process.env.STORAGE_PROVIDER = 'minio';

process.env.STORAGE_INPUT_BUCKET = 'uploads';

process.env.STORAGE_OUTPUT_BUCKET = 'processed';

process.env.MINIO_ENDPOINT = 'localhost';
process.env.MINIO_PORT = '9000';

process.env.MINIO_ROOT_USER = 'test_user';
process.env.MINIO_ROOT_PASSWORD = 'test_password';

process.env.NODE_ENV = 'test';

// 2. محاكاة مكتبة PostgreSQL (pg) 
jest.mock('../src/config/db', () => ({
  connect: jest.fn(() => ({
    query: jest.fn(),
    release: jest.fn()
  })),
  query: jest.fn()
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

// 5. محاكاة BullMQ (لمنع تشغيل الـ Worker الحقيقي)
jest.mock('bullmq', () => ({
  Worker: jest.fn().mockImplementation(() => ({
    on: jest.fn(),
    close: jest.fn()
  }))
}));



jest.mock('minio', () => {

  const mockMinioClient = {

    getObject:
      jest.fn(),

    putObject:
      jest.fn().mockResolvedValue({
        etag: '123'
      })

  };

  return {

    Client:
      jest.fn().mockImplementation(
        () => mockMinioClient
      ),

    __mockMinioClient:
      mockMinioClient

  };

});