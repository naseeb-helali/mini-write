const request = require('supertest');
const { app } = require('../src/index');
const jwt = require('jsonwebtoken');
const pool = require('../src/config/db');

process.env.JWT_SECRET = 'test_secret_123';

describe('Upload ID Card - Integration Test', () => {

  let validToken;

  beforeAll(() => {
    // إنشاء توكن صالح لاستخدامه في جميع اختبارات الرفع
    validToken = jwt.sign({ id: 1, username: 'naseeb_dev' }, process.env.JWT_SECRET);
  });

  test('Success: Upload ID card and trigger background job', async () => {
    // 1. محاكاة رد قاعدة البيانات عند تحديث بيانات المستخدم بعد الرفع
    pool.query.mockResolvedValueOnce({ 
      rows: [{ id: 1, username: 'naseeb_dev', id_card_url: 'id-1.jpg' }] 
    });

    // 2. إرسال طلب الرفع مع ملف وهمي (Buffer)
    const response = await request(app)
      .post('/api/v1/auth/upload-id')
      .set('Authorization', `Bearer ${validToken}`)
      .attach('id_card', Buffer.from('fake-image-content'), 'id_card.jpg'); 

    // 3. التحقق من النتائج
    expect(response.statusCode).toBe(200);
    expect(response.body.message).toBe("ID Card uploaded. Processing started in background!");
    expect(response.body.user).toHaveProperty('id_card_url');
  });

  test('Failure: Upload without file', async () => {
    const response = await request(app)
      .post('/api/v1/auth/upload-id')
      .set('Authorization', `Bearer ${validToken}`);

    expect(response.statusCode).toBe(400);
    expect(response.body.error).toBe("No file uploaded or invalid file type.");
  });
});