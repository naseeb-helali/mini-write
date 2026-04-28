require('dotenv').config(); // Load the variables before importing any service
const request = require('supertest');
const { app } = require('../src/index'); // Import the application that we exported in index file.

describe('Health Check & Basic Auth Logic', () => {
  
 // 1. Liveness Probe Test
  test('GET /health/live should return 200 and UP status', async () => {
    const response = await request(app).get('/health/live');
    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      status: "UP",
      message: "Service is alive"
    });
  });

// 2. Readiness Probe Test (We test the general response)
  test('GET /health/ready should return system health status', async () => {
    const response = await request(app).get('/health/ready');
// Note: A 503 error may occur if other services (DB/Redis) are offline.
// But we are testing that the structure is correct.
    expect([200, 503, 500]).toContain(response.statusCode);
    expect(response.body).toHaveProperty('status');
  });

// 3. Unit Test of Register Logic (without a real database)
  test('POST /api/v1/auth/register should fail if fields are missing', async () => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({ username: "" }); // Sending incomplete data
    expect(response.statusCode).toBe(400);
    expect(response.body.error).toBe("Missing fields");
  });
});