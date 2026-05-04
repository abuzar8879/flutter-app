const { pool } = require('../../db/pool');
const { mapConversation, mapConversationSummary, mapMessage } = require('./chat.mapper');

function normalizePair(userAId, userBId) {
  const first = Number(userAId);
  const second = Number(userBId);
  return first < second ? [first, second] : [second, first];
}

async function findConversationBetween(userAId, userBId) {
  const [userOneId, userTwoId] = normalizePair(userAId, userBId);
  const result = await pool.query(
    `
      SELECT *
      FROM conversations
      WHERE user_one_id = $1 AND user_two_id = $2
      LIMIT 1
    `,
    [userOneId, userTwoId],
  );

  return result.rows[0] ? mapConversation(result.rows[0]) : null;
}

async function createConversation(userAId, userBId) {
  const [userOneId, userTwoId] = normalizePair(userAId, userBId);
  const result = await pool.query(
    `
      INSERT INTO conversations (user_one_id, user_two_id)
      VALUES ($1, $2)
      ON CONFLICT (user_one_id, user_two_id)
      DO UPDATE SET updated_at = conversations.updated_at
      RETURNING *
    `,
    [userOneId, userTwoId],
  );

  return mapConversation(result.rows[0]);
}

async function findConversationForUser(conversationId, userId) {
  const result = await pool.query(
    `
      SELECT *
      FROM conversations
      WHERE id = $1
        AND (user_one_id = $2 OR user_two_id = $2)
      LIMIT 1
    `,
    [conversationId, userId],
  );

  return result.rows[0] ? mapConversation(result.rows[0]) : null;
}

async function createMessage({ conversationId, senderId, receiverId, type, content, imagePath }) {
  const result = await pool.query(
    `
      INSERT INTO messages (conversation_id, sender_id, receiver_id, type, content, image_path)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `,
    [conversationId, senderId, receiverId, type, content, imagePath],
  );

  await pool.query('UPDATE conversations SET updated_at = NOW() WHERE id = $1', [
    conversationId,
  ]);

  return mapMessage(result.rows[0]);
}

async function findMessagesForConversation(conversationId, { limit = 50, beforeId } = {}) {
  const params = [conversationId, limit];
  let paginationClause = '';
  if (beforeId) {
    params.push(beforeId);
    paginationClause = `AND id < $${params.length}`;
  }

  const result = await pool.query(
    `
      SELECT *
      FROM messages
      WHERE conversation_id = $1
        ${paginationClause}
      ORDER BY id DESC
      LIMIT $2
    `,
    params,
  );

  return result.rows.reverse().map(mapMessage);
}

async function findConversationSummaries(userId, { limit = 30, offset = 0 } = {}) {
  const result = await pool.query(
    `
      SELECT
        c.*,
        friend.id AS friend_id,
        friend.name AS friend_name,
        friend.email AS friend_email,
        friend.avatar_path AS friend_avatar_path,
        friend.public_key AS friend_public_key,
        last_message.id AS message_id,
        last_message.sender_id AS message_sender_id,
        last_message.receiver_id AS message_receiver_id,
        last_message.type AS message_type,
        last_message.content AS message_content,
        last_message.image_path AS message_image_path,
        last_message.read_at AS message_read_at,
        last_message.created_at AS message_created_at,
        COALESCE(unread.count, 0) AS unread_count
      FROM conversations c
      JOIN users friend ON friend.id = CASE
        WHEN c.user_one_id = $1 THEN c.user_two_id
        ELSE c.user_one_id
      END
      LEFT JOIN LATERAL (
        SELECT *
        FROM messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC, m.id DESC
        LIMIT 1
      ) last_message ON true
      LEFT JOIN LATERAL (
        SELECT COUNT(*) AS count
        FROM messages m
        WHERE m.conversation_id = c.id
          AND m.receiver_id = $1
          AND m.read_at IS NULL
      ) unread ON true
      WHERE c.user_one_id = $1 OR c.user_two_id = $1
      ORDER BY COALESCE(last_message.created_at, c.updated_at) DESC, c.id DESC
      LIMIT $2 OFFSET $3
    `,
    [userId, limit, offset],
  );

  return result.rows.map(mapConversationSummary);
}

async function markConversationRead(conversationId, userId) {
  await pool.query(
    `
      UPDATE messages
      SET read_at = NOW()
      WHERE conversation_id = $1
        AND receiver_id = $2
        AND read_at IS NULL
    `,
    [conversationId, userId],
  );
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
