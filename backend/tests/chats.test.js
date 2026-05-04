const fs = require('fs');
const http = require('http');
const path = require('path');
const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { io: createSocketClient } = require('socket.io-client');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { ensureDatabaseSchema } = require('../src/db/schema');
const { initializeSocket } = require('../src/socket');

const runId = Date.now();
const createdUserIds = [];
let uploadedImagePath = null;

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

async function becomeFriends(sender, receiver) {
  const sendResponse = await request(app)
    .post('/api/friends/requests')
    .set('Authorization', `Bearer ${sender.token}`)
    .send({ receiverId: receiver.user.id });

  assert.equal(sendResponse.statusCode, 201);

  const acceptResponse = await request(app)
    .patch(`/api/friends/requests/${sendResponse.body.request.id}`)
    .set('Authorization', `Bearer ${receiver.token}`)
    .send({ action: 'accepted' });

  assert.equal(acceptResponse.statusCode, 200);
}

test.before(async () => {
  await ensureDatabaseSchema();
});

test.after(async () => {
  if (uploadedImagePath) {
    const filePath = path.join(process.cwd(), uploadedImagePath.replace(/^\//, '').replace(/\//g, path.sep));
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  }

  for (const userId of createdUserIds.reverse()) {
    await pool.query('DELETE FROM users WHERE id = $1', [userId]);
  }
});

test('friends can create a conversation, send text, and load history', async () => {
  const alice = await signup('Chat Alice', 'chat_alice');
  const bob = await signup('Chat Bob', 'chat_bob');
  await becomeFriends(alice, bob);

  const conversationResponse = await request(app)
    .post('/api/chats/conversations')
    .set('Authorization', `Bearer ${alice.token}`)
    .send({ friendId: bob.user.id });

  assert.equal(conversationResponse.statusCode, 200);
  assert.equal(typeof conversationResponse.body.conversation.id, 'number');

  const sendResponse = await request(app)
    .post('/api/chats/messages')
    .set('Authorization', `Bearer ${alice.token}`)
    .send({ receiverId: bob.user.id, content: 'Hello Bob' });

  assert.equal(sendResponse.statusCode, 201);
  assert.equal(sendResponse.body.message.type, 'text');
  assert.equal(sendResponse.body.message.content, 'Hello Bob');

  const messagesResponse = await request(app)
    .get(`/api/chats/conversations/${conversationResponse.body.conversation.id}/messages`)
    .set('Authorization', `Bearer ${bob.token}`);

  assert.equal(messagesResponse.statusCode, 200);
  assert.equal(messagesResponse.body.messages.length, 1);
  assert.equal(messagesResponse.body.messages[0].content, 'Hello Bob');
});

test('conversation list shows latest message and unread counts, then read clears count', async () => {
  const iris = await signup('Chat Iris', 'chat_iris');
  const jude = await signup('Chat Jude', 'chat_jude');
  await becomeFriends(iris, jude);

  const sendResponse = await request(app)
    .post('/api/chats/messages')
    .set('Authorization', `Bearer ${iris.token}`)
    .send({ receiverId: jude.user.id, content: 'Unread hello' });

  assert.equal(sendResponse.statusCode, 201);

  const listResponse = await request(app)
    .get('/api/chats/conversations')
    .set('Authorization', `Bearer ${jude.token}`);

  assert.equal(listResponse.statusCode, 200);
  assert.equal(listResponse.body.conversations[0].lastMessage.content, 'Unread hello');
  assert.equal(listResponse.body.conversations[0].unreadCount, 1);

  const readResponse = await request(app)
    .patch(`/api/chats/conversations/${listResponse.body.conversations[0].id}/read`)
    .set('Authorization', `Bearer ${jude.token}`);

  assert.equal(readResponse.statusCode, 200);

  const afterReadResponse = await request(app)
    .get('/api/chats/conversations')
    .set('Authorization', `Bearer ${jude.token}`);

  assert.equal(afterReadResponse.body.conversations[0].unreadCount, 0);
});

test('encrypted messages are stored as opaque encrypted payloads', async () => {
  const kara = await signup('Chat Kara', 'chat_kara');
  const luis = await signup('Chat Luis', 'chat_luis');
  await becomeFriends(kara, luis);

  const sendResponse = await request(app)
    .post('/api/chats/messages')
    .set('Authorization', `Bearer ${kara.token}`)
    .send({
      receiverId: luis.user.id,
      type: 'encrypted',
      content: '{"nonce":"n","cipherText":"c","mac":"m"}',
    });

  assert.equal(sendResponse.statusCode, 201);
  assert.equal(sendResponse.body.message.type, 'encrypted');
  assert.equal(sendResponse.body.message.content.includes('cipherText'), true);
});

test('non-friends cannot create conversations or send messages', async () => {
  const casey = await signup('Chat Casey', 'chat_casey');
  const drew = await signup('Chat Drew', 'chat_drew');

  const conversationResponse = await request(app)
    .post('/api/chats/conversations')
    .set('Authorization', `Bearer ${casey.token}`)
    .send({ friendId: drew.user.id });

  assert.equal(conversationResponse.statusCode, 403);

  const sendResponse = await request(app)
    .post('/api/chats/messages')
    .set('Authorization', `Bearer ${casey.token}`)
    .send({ receiverId: drew.user.id, content: 'Blocked' });

  assert.equal(sendResponse.statusCode, 403);
});

test('friends can upload a chat image and send it as an image message', async () => {
  const erin = await signup('Chat Erin', 'chat_erin');
  const finn = await signup('Chat Finn', 'chat_finn');
  await becomeFriends(erin, finn);

  const uploadResponse = await request(app)
    .post('/api/chats/images')
    .set('Authorization', `Bearer ${erin.token}`)
    .attach('image', Buffer.from([137, 80, 78, 71]), {
      filename: 'chat.png',
      contentType: 'image/png',
    });

  assert.equal(uploadResponse.statusCode, 201);
  assert.match(uploadResponse.body.imagePath, /^\/uploads\/chat\//);
  uploadedImagePath = uploadResponse.body.imagePath;

  const sendResponse = await request(app)
    .post('/api/chats/messages')
    .set('Authorization', `Bearer ${erin.token}`)
    .send({
      receiverId: finn.user.id,
      type: 'image',
      imagePath: uploadedImagePath,
    });

  assert.equal(sendResponse.statusCode, 201);
  assert.equal(sendResponse.body.message.type, 'image');
  assert.equal(sendResponse.body.message.imagePath, uploadedImagePath);
});

test('Socket.IO stores and emits real-time messages between friends', async () => {
  const gina = await signup('Chat Gina', 'chat_gina');
  const hank = await signup('Chat Hank', 'chat_hank');
  await becomeFriends(gina, hank);

  const server = http.createServer(app);
  initializeSocket(server);

  await new Promise((resolve) => server.listen(0, resolve));
  const { port } = server.address();
  const url = `http://localhost:${port}`;

  const ginaSocket = createSocketClient(url, {
    auth: { token: gina.token },
    transports: ['websocket'],
  });
  const hankSocket = createSocketClient(url, {
    auth: { token: hank.token },
    transports: ['websocket'],
  });

  try {
    await Promise.all([
      new Promise((resolve, reject) => {
        ginaSocket.on('connect', resolve);
        ginaSocket.on('connect_error', reject);
      }),
      new Promise((resolve, reject) => {
        hankSocket.on('connect', resolve);
        hankSocket.on('connect_error', reject);
      }),
    ]);

    const receivedPromise = new Promise((resolve) => {
      hankSocket.on('message_received', resolve);
    });

    const ack = await new Promise((resolve) => {
      ginaSocket.emit(
        'send_message',
        { receiverId: hank.user.id, content: 'Live hello' },
        resolve,
      );
    });

    assert.equal(ack.ok, true);
    assert.equal(ack.message.content, 'Live hello');

    const received = await receivedPromise;
    assert.equal(received.message.content, 'Live hello');
    assert.equal(received.message.receiverId, hank.user.id);
  } finally {
    ginaSocket.close();
    hankSocket.close();
    await new Promise((resolve) => server.close(resolve));
  }
});
