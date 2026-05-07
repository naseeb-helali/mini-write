const { processIdCard } = require('../src/processors/imageProcessor');
const pool = require('../src/config/db');
const minioClient = require('../src/config/storage');
const { Readable } = require('stream');

describe('Image Processor - Unit Tests', () => {

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('Success: Process image, upload to MinIO, and update DB', async () => {
    // 1. محاكاة بيانات المهمة (Job Data)
    const mockJob = {
      data: { fileName: 'user123_id.jpg', userId: 1 }
    };

    // 2. إعداد محاكاة قاعدة البيانات (Phase 1 & 3)
    // يجب محاكاة كل استدعاء لـ query بالترتيب الدقيق الموجود في الكود
    const mockClient = {
      query: jest.fn()
        // --- المرحلة الأولى: الحجز والتحقق ---
        .mockResolvedValueOnce({}) // BEGIN 
        .mockResolvedValueOnce({ rows: [{ identity_status: 'pending' }] }) // SELECT FOR UPDATE 
        .mockResolvedValueOnce({ rowCount: 1, rows: [{ id: 1 }] }) // UPDATE to processing 
        .mockResolvedValueOnce({}) // COMMIT 
        // --- المرحلة الثالثة: التحديث النهائي ---
        .mockResolvedValueOnce({}) // BEGIN 
        .mockResolvedValueOnce({ rowCount: 1 }) // UPDATE to verified
        .mockResolvedValueOnce({}), // COMMIT 
      release: jest.fn() 
    };
    
    // محاكاة pool.connect ليعيد الـ mockClient مرتين (مرة للمرحلة الأولى ومرة للثالثة)
    pool.connect.mockResolvedValue(mockClient);

    // 3. محاكاة الـ Stream القادم من MinIO (Phase 2)
    const mockStream = new Readable();
    mockStream.push('fake-image-binary-data');
    mockStream.push(null); // نهاية الـ Stream 
    minioClient.getObject.mockResolvedValue(mockStream);

    // 4. تنفيذ الدالة المراد اختبارها
    const result = await processIdCard(mockJob);

    // 5. التحقق من النتائج (Assertions) 
    expect(result).toEqual({
      success: true,
      userId: 1,
      file: 'thumb_user123_id.jpg'
    });

    // التأكد من استدعاء مراحل قاعدة البيانات الأساسية
    expect(mockClient.query).toHaveBeenCalledWith(expect.stringContaining('BEGIN'));
    expect(mockClient.query).toHaveBeenCalledWith(
        expect.stringContaining('identity_status = \'verified\''), 
        expect.arrayContaining(['thumb_user123_id.jpg', 1])
    );
    
    // التأكد من رفع الصورة المصغرة إلى الحاوية الصحيحة 
    expect(minioClient.putObject).toHaveBeenCalledWith(
      process.env.MINIO_PROCESSED_BUCKET,
      'thumb_user123_id.jpg',
      expect.any(Buffer),
      { 'Content-Type': 'image/jpeg' }
    );
  });

  test('Skipped: Should skip if identity_status is already processing or verified', async () => {
    const mockJob = { data: { fileName: 'test.jpg', userId: 1 } };

    const mockClient = {
      query: jest.fn()
        .mockResolvedValueOnce({}) // BEGIN
        .mockResolvedValueOnce({ rows: [{ identity_status: 'processing' }] }), // الحالة ليست pending!
      release: jest.fn()
    };
    pool.connect.mockResolvedValue(mockClient);

    const result = await processIdCard(mockJob);

    // التحقق من أن الـ Worker انسحب ولم يكمل المعالجة
    expect(result).toEqual({ skipped: true });
    expect(minioClient.getObject).not.toHaveBeenCalled(); // لم يحاول تحميل الصورة
    expect(mockClient.release).toHaveBeenCalled(); // تأكدنا من إغلاق الاتصال
  });

  test('Failure: Should throw error if file exceeds 5MB limit', async () => {
    const mockJob = { data: { fileName: 'huge_file.jpg', userId: 1 } };

    // محاكاة قاعدة البيانات للمرحلة الأولى بنجاح
    const mockClient = {
      query: jest.fn()
        .mockResolvedValueOnce({}) // BEGIN
        .mockResolvedValueOnce({ rows: [{ identity_status: 'pending' }] })
        .mockResolvedValueOnce({ rowCount: 1, rows: [{ id: 1 }] })
        .mockResolvedValueOnce({}), // COMMIT
      release: jest.fn()
    };
    pool.connect.mockResolvedValue(mockClient);

    // محاكاة Stream يرسل قطعة بيانات أكبر من 5MB
    const hugeStream = new Readable();
    hugeStream.push(Buffer.alloc(6 * 1024 * 1024)); // 6MB chunk
    hugeStream.push(null);
    minioClient.getObject.mockResolvedValue(hugeStream);

    // نتوقع أن الدالة سترمي خطأ "File too large"
    await expect(processIdCard(mockJob)).rejects.toThrow("File too large - potential memory risk");
  });
});