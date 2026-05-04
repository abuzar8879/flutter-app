const fs = require('fs');
const path = require('path');
const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { ensureDatabaseSchema } = require('../src/db/schema');

const email = `profile_${Date.now()}@example.com`;
let authToken = '';
let userId = 0;
let uploadedAvatarPath = null;

test.before(async () => {
  await ensureDatabaseSchema();

  const signupResponse = await request(app).post('/api/auth/signup').send({
    name: 'Profile User',
    email,
    password: 'secret123',
  });

  authToken = signupResponse.body.token;
  userId = signupResponse.body.user.id;
});

test.after(async () => {
  if (uploadedAvatarPath) {
    const filePath = path.join(process.cwd(), uploadedAvatarPath.replace(/^\//, '').replace(/\//g, path.sep));
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  }

  if (userId) {
    await pool.query('DELETE FROM users WHERE id = $1', [userId]);
  }
});

test('GET /api/profile/me returns the authenticated profile', async () => {
  const response = await request(app)
    .get('/api/profile/me')
    .set('Authorization', `Bearer ${authToken}`);

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.profile.email, email);
  assert.equal(response.body.profile.name, 'Profile User');
});

test('PATCH /api/profile/me updates the profile name', async () => {
  const response = await request(app)
    .patch('/api/profile/me')
    .set('Authorization', `Bearer ${authToken}`)
    .send({ name: 'Updated Profile User' });

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.profile.name, 'Updated Profile User');
});

test('POST /api/profile/me/avatar stores a local profile image path', async () => {
  const response = await request(app)
    .post('/api/profile/me/avatar')
    .set('Authorization', `Bearer ${authToken}`)
    .attach('avatar', Buffer.from([137, 80, 78, 71]), {
      filename: 'avatar.png',
      contentType: 'image/png',
    });

  assert.equal(response.statusCode, 200);
  assert.match(response.body.profile.avatarPath, /^\/uploads\/profile\//);

  uploadedAvatarPath = response.body.profile.avatarPath;
  const filePath = path.join(process.cwd(), uploadedAvatarPath.replace(/^\//, '').replace(/\//g, path.sep));
  assert.equal(fs.existsSync(filePath), true);
});
