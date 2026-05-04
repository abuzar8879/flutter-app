const { mapConversation, mapConversationSummary, mapMessage } = require('./chat.mapper');
const { ensureStringId, pairKey, nowIso, getValue, setValue, updateValue, pushChild } = require('../../db/rtdb');

function normalizePair(userAId, userBId) {
  const first = ensureStringId(String(userAId), 'userAId');
  const second = ensureStringId(String(userBId), 'userBId');
  return first < second ? [first, second] : [second, first];
}

async function findConversationBetween(userAId, userBId) {
  const [userOneId, userTwoId] = normalizePair(userAId, userBId);
  const key = pairKey(userOneId, userTwoId);
  const conversationId = await getValue(`/conversationByPair/${encodeURIComponent(key)}`);
  if (!conversationId) return null;
  const conversation = await getValue(`/conversations/${conversationId}`);
  return conversation ? mapConversation(conversation) : null;
}

async function createConversation(userAId, userBId) {
  const [userOneId, userTwoId] = normalizePair(userAId, userBId);
  const key = pairKey(userOneId, userTwoId);
  const existingId = await getValue(`/conversationByPair/${encodeURIComponent(key)}`);
  if (existingId) {
    const existing = await getValue(`/conversations/${existingId}`);
    return existing ? mapConversation(existing) : null;
  }

  const timestamp = nowIso();
  const { key: conversationId } = await pushChild('/conversations', {});
  const conversation = {
    id: conversationId,
    userOneId,
    userTwoId,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
  await setValue(`/conversations/${conversationId}`, conversation);
  await setValue(`/conversationByPair/${encodeURIComponent(key)}`, conversationId);
  return mapConversation(conversation);
}

async function findConversationForUser(conversationId, userId) {
  const cid = ensureStringId(String(conversationId), 'conversationId');
  const uid = ensureStringId(String(userId), 'userId');
  const convo = await getValue(`/conversations/${cid}`);
  if (!convo) return null;
  if (String(convo.userOneId) !== uid && String(convo.userTwoId) !== uid) return null;
  return mapConversation(convo);
}

async function createMessage({ conversationId, senderId, receiverId, type, content, imagePath }) {
  const cid = ensureStringId(String(conversationId), 'conversationId');
  const sid = ensureStringId(String(senderId), 'senderId');
  const rid = ensureStringId(String(receiverId), 'receiverId');
  const timestamp = nowIso();
  const { key: messageId } = await pushChild(`/messages/${cid}`, {});
  const message = {
    id: messageId,
    conversationId: cid,
    senderId: sid,
    receiverId: rid,
    type,
    content: content ?? null,
    imagePath: imagePath ?? null,
    readAt: null,
    createdAt: timestamp,
  };
  await setValue(`/messages/${cid}/${messageId}`, message);
  await updateValue(`/conversations/${cid}`, { updatedAt: timestamp });
  return mapMessage(message);
}

async function findMessagesForConversation(conversationId, { limit = 50, beforeId } = {}) {
  const cid = ensureStringId(String(conversationId), 'conversationId');
  const all = (await getValue(`/messages/${cid}`)) ?? {};
  const messages = Object.values(all)
    .filter(Boolean)
    .sort((a, b) => String(a.createdAt ?? '').localeCompare(String(b.createdAt ?? '')))
    .map(mapMessage);

  if (beforeId) {
    const idx = messages.findIndex((m) => m.id === String(beforeId));
    const slice = idx > 0 ? messages.slice(0, idx) : messages;
    return slice.slice(Math.max(slice.length - limit, 0));
  }

  return messages.slice(Math.max(messages.length - limit, 0));
}

async function findConversationSummaries(userId, { limit = 30, offset = 0 } = {}) {
  const uid = ensureStringId(String(userId), 'userId');
  const conversations = (await getValue('/conversations')) ?? {};
  const users = (await getValue('/users')) ?? {};

  const summaries = [];
  for (const convo of Object.values(conversations)) {
    if (!convo) continue;
    if (String(convo.userOneId) !== uid && String(convo.userTwoId) !== uid) continue;

    const friendId = String(convo.userOneId) === uid ? String(convo.userTwoId) : String(convo.userOneId);
    const friend = users[friendId];

    const msgs = (await getValue(`/messages/${convo.id}`)) ?? {};
    const msgList = Object.values(msgs).filter(Boolean);
    msgList.sort((a, b) => String(b.createdAt ?? '').localeCompare(String(a.createdAt ?? '')));
    const last = msgList[0] ?? null;
    const unreadCount = msgList.filter((m) => String(m.receiverId) === uid && !m.readAt).length;

    summaries.push(
      mapConversationSummary({
        id: convo.id,
        updated_at: convo.updatedAt,
        friend_id: friendId,
        friend_name: friend?.name,
        friend_email: friend?.email,
        friend_avatar_path: friend?.avatarPath ?? null,
        friend_public_key: friend?.publicKey ?? null,
        message_id: last?.id ?? null,
        message_sender_id: last?.senderId ?? null,
        message_receiver_id: last?.receiverId ?? null,
        message_type: last?.type ?? null,
        message_content: last?.content ?? null,
        message_image_path: last?.imagePath ?? null,
        message_read_at: last?.readAt ?? null,
        message_created_at: last?.createdAt ?? null,
        unread_count: unreadCount,
      }),
    );
  }

  summaries.sort((a, b) => String(b.updatedAt ?? '').localeCompare(String(a.updatedAt ?? '')));
  return summaries.slice(offset, offset + limit);
}

async function markConversationRead(conversationId, userId) {
  const cid = ensureStringId(String(conversationId), 'conversationId');
  const uid = ensureStringId(String(userId), 'userId');
  const all = (await getValue(`/messages/${cid}`)) ?? {};
  const timestamp = nowIso();
  const updates = {};
  for (const [mid, m] of Object.entries(all)) {
    if (!m) continue;
    if (String(m.receiverId) === uid && !m.readAt) {
      updates[`/messages/${cid}/${mid}/readAt`] = timestamp;
    }
  }
  const { getDatabase } = require('../../db/rtdb');
  await getDatabase().ref().update(updates);
}

module.exports = {
  createConversation,
  createMessage,
  findConversationSummaries,
  findConversationBetween,
  findConversationForUser,
  findMessagesForConversation,
  markConversationRead,
};
