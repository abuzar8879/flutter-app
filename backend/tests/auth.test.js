const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { ensureDatabaseSchema } = require('../src/db/schema');

const uniqueEmail = `phase2_${Date.now()}@example.com`;
let authToken = '';
let createdUserId = 0;

test.before(async () => {
  await ensureDatabaseSchema();
});

test.after(async () => {
  if (createdUserId) {
    await pool.query('DELETE FROM users WHERE id = $1', [createdUserId]);
  }
});

test('POST /api/auth/signup creates a user and returns token', async () => {
  const response = await request(app).post('/api/auth/signup').send({
    name: 'Phase Two User',
    email: uniqueEmail,
    password: 'secret123',
  });

  assert.equal(response.statusCode, 201);
  assert.equal(response.body.user.email, uniqueEmail);
  assert.equal(typeof response.body.token, 'string');

  authToken = response.body.token;
  createdUserId = response.body.user.id;
});

test('POST /api/auth/signup rejects duplicate email', async () => {
  const response = await request(app).post('/api/auth/signup').send({
    name: 'Duplicate User',
    email: uniqueEmail,
    password: 'secret123',
  });

  assert.equal(response.statusCode, 409);
});

test('POST /api/auth/login authenticates existing user', async () => {
  const response = await request(app).post('/api/auth/login').send({
    email: uniqueEmail,
    password: 'secret123',
  });

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.user.email, uniqueEmail);
  assert.equal(typeof response.body.token, 'string');
});

test('GET /api/auth/me returns the authenticated user', async () => {
  const response = await request(app)
    .get('/api/auth/me')
    .set('Authorization', `Bearer ${authToken}`);

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.user.email, uniqueEmail);
});
