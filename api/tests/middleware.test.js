const request = require('supertest');
const { app } = require('../src/index');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'test_secret_123';

describe('Auth Middleware - Access Control', () => {

  // 1. اختبار الوصول بدون توكن
  test('Access Denied: No token provided', async () => {
    const response = await request(app).get('/api/v1/auth/profile');
    
    expect(response.statusCode).toBe(401);
    expect(response.body.error).toBe("Access denied. No token provided.");
  });

  // 2. اختبار توكن غير صالح
  test('Access Denied: Invalid token', async () => {
    const response = await request(app)
      .get('/api/v1/auth/profile')
      .set('Authorization', 'Bearer invalid_token_here');

    expect(response.statusCode).toBe(400);
    expect(response.body.error).toBe("Invalid or expired token.");
  });

  // 3. اختبار الوصول بتوكن صحيح
  test('Access Granted: Valid JWT token', async () => {
    // إنشاء توكن وهمي للتست
    const validToken = jwt.sign(
      { id: 1, username: 'naseeb_dev' }, 
      process.env.JWT_SECRET, 
      { expiresIn: '1h' }
    );

    const response = await request(app)
      .get('/api/v1/auth/profile')
      .set('Authorization', `Bearer ${validToken}`);

    // ملاحظة: قد يعيد 404 أو 500 إذا كان الـ Controller يحتاج قاعدة بيانات
    // ولكن المهم هنا هو تجاوز مرحلة الـ Middleware (عدم استلام 401 أو 403)
    expect([200, 404, 500]).toContain(response.statusCode);
  });
});