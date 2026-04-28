const request = require('supertest');
const { app } = require('../src/index');
const pool = require('../src/config/db'); 
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken'); // استيراد صريح للتأكد من وجود المكتبة

// 🔐 القيمة يجب أن تطابق تماماً ما يبحث عنه الـ Controller
process.env.JWT_SECRET = 'test_secret_123';
process.env.JWT_EXPIRY = '1h'; // السطر الجديد
describe('Auth Controller - Registration & Login Tests', () => {

  // تنظيف الـ Mocks قبل كل اختبار لضمان العزل التام
  beforeEach(() => {
    jest.clearAllMocks();
    // إعادة ضبط المتغير البيئي قبل كل تست للتأكد
    process.env.JWT_SECRET = 'test_secret_123';
  });

  // ==========================================
  // 1. اختبارات التسجيل (Register)
  // ==========================================

  test('Success: Register a new user', async () => {
    const mockUser = { id: 1, username: 'naseeb_dev' };
    pool.query.mockResolvedValueOnce({ rows: [mockUser] });

    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        username: 'naseeb_dev',
        password: 'password123'
      });

    expect(response.statusCode).toBe(201);
    expect(response.body.message).toBe("User created");
    expect(response.body.data.username).toBe('naseeb_dev');
  });

  test('Failure: Register with an existing username', async () => {
    const dbError = new Error('duplicate key');
    dbError.code = '23505'; 
    pool.query.mockRejectedValueOnce(dbError);

    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        username: 'existing_user',
        password: 'password123'
      });

    expect(response.statusCode).toBe(400);
    expect(response.body.error).toBe("Username already exists");
  });

  // ==========================================
  // 2. اختبار تسجيل الدخول - مع كشف الخطأ
  // ==========================================

  test('Success: Login with correct credentials', async () => {
    const password = 'password123';
    const hashedPassword = await bcrypt.hash(password, 10);

    // الـ Mock لنتائج قاعدة البيانات
    pool.query.mockResolvedValueOnce({ 
      rows: [{ id: 1, username: 'naseeb_dev', password: hashedPassword }] 
    });

    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({
        username: 'naseeb_dev',
        password: password
      });

    // إذا فشل، سيظهر لك الآن في الـ Console السبب الحقيقي (مثلاً: jwt is not defined)
    if (response.statusCode === 500) {
        console.log("CRITICAL DEBUG:", response.body);
    }

    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveProperty('token');
  });

  test('Failure: Login with wrong password', async () => {
    const hashedPassword = await bcrypt.hash('password123', 10);
    pool.query.mockResolvedValueOnce({ rows: [{ id: 1, username: 'naseeb_dev', password: hashedPassword }] });
    const response = await request(app).post('/api/v1/auth/login').send({ username: 'naseeb_dev', password: 'wrong' });
    expect(response.statusCode).toBe(401);
  });

});