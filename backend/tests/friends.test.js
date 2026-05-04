const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { ensureDatabaseSchema } = require('../src/db/schema');

const runId = Date.now();
const createdUserIds = [];

async function signup(name, emailPrefix) {
  const response = await request(app).post('/api/auth/signup').send({
    name,
    email: `${emailPrefix}_${runId}@example.com`,
    password: 'secret123',
  });

  assert.equal(response.statusCode, 201);
  createdUserIds.push(response.body.user.id);
  return {
    token: response.body.token,
    user: response.body.user,
  };
}

test.before(async () => {
  await ensureDatabaseSchema();
});

test.after(async () => {
  for (const userId of createdUserIds.reverse()) {
    await pool.query('DELETE FROM users WHERE id = $1', [userId]);
  }
});

test('friend requests can be sent, listed, accepted, and shown as friends', async () => {
  const alice = await signup('Alice Friend', 'alice_friend');
  const bob = await signup('Bob Friend', 'bob_friend');

  const sendResponse = await request(app)
    .post('/api/friends/requests')
    .set('Authorization', `Bearer ${alice.token}`)
    .send({ receiverId: bob.user.id });

  assert.equal(sendResponse.statusCode, 201);
  assert.equal(sendResponse.body.request.status, 'pending');
  assert.equal(sendResponse.body.request.senderId, alice.user.id);
  assert.equal(sendResponse.body.request.receiverId, bob.user.id);

  const pendingResponse = await request(app)
    .get('/api/friends/requests/pending')
    .set('Authorization', `Bearer ${bob.token}`);

  assert.equal(pendingResponse.statusCode, 200);
  assert.equal(pendingResponse.body.requests.length, 1);
  assert.equal(pendingResponse.body.requests[0].sender.id, alice.user.id);

  const acceptResponse = await request(app)
    .patch(`/api/friends/requests/${sendResponse.body.request.id}`)
    .set('Authorization', `Bearer ${bob.token}`)
    .send({ action: 'accepted' });

  assert.equal(acceptResponse.statusCode, 200);
  assert.equal(acceptResponse.body.request.status, 'accepted');

  const friendsResponse = await request(app)
    .get('/api/friends')
    .set('Authorization', `Bearer ${alice.token}`);

  assert.equal(friendsResponse.statusCode, 200);
  assert.equal(friendsResponse.body.friends.length, 1);
  assert.equal(friendsResponse.body.friends[0].id, bob.user.id);
});

test('duplicate pending requests are blocked and reverse pending requests auto-accept', async () => {
  const carol = await signup('Carol Friend', 'carol_friend');
  const dan = await signup('Dan Friend', 'dan_friend');

  const firstResponse = await request(app)
    .post('/api/friends/requests')
    .set('Authorization', `Bearer ${carol.token}`)
    .send({ receiverId: dan.user.id });

  assert.equal(firstResponse.statusCode, 201);

  const duplicateResponse = await request(app)
    .post('/api/friends/requests')
    .set('Authorization', `Bearer ${carol.token}`)
    .send({ receiverId: dan.user.id });

  assert.equal(duplicateResponse.statusCode, 409);

  const reverseResponse = await request(app)
    .post('/api/friends/requests')
    .set('Authorization', `Bearer ${dan.token}`)
    .send({ receiverId: carol.user.id });

  assert.equal(reverseResponse.statusCode, 201);
  assert.equal(reverseResponse.body.request.status, 'accepted');
});

test('rejected requests can be sent again later', async () => {
  const erin = await signup('Erin Friend', 'erin_friend');
  const finn = await signup('Finn Friend', 'finn_friend');

  const sendResponse = await request(app)
    .post('/api/friends/requests')
    .set('Authorization', `Bearer ${erin.token}`)
    .send({ receiverId: finn.user.id });

  assert.equal(sendResponse.statusCode, 201);

  const rejectResponse = await request(app)
    .patch(`/api/friends/requests/${sendResponse.body.request.id}`)
    .set('Authorization', `Bearer ${finn.token}`)
    .send({ action: 'rejected' });

  assert.equal(rejectResponse.statusCode, 200);
  assert.equal(rejectResponse.body.request.status, 'rejected');

  const retryResponse = await request(app)
    .post('/api/friends/requests')
    .set('Authorization', `Bearer ${erin.token}`)
    .send({ receiverId: finn.user.id });

  assert.equal(retryResponse.statusCode, 201);
  assert.equal(retryResponse.body.request.status, 'pending');
});
