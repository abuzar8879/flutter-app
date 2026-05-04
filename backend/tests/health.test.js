const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const app = require('../src/app');

test('GET /api/health returns the Phase 1 health payload', async () => {
  const response = await request(app).get('/api/health');

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.message, 'Chat backend is running.');
  assert.equal(typeof response.body.timestamp, 'string');
  assert.equal(typeof response.body.database.connected, 'boolean');
});
