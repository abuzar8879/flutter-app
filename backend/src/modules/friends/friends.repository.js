const { pool } = require('../../db/pool');
const { mapUser } = require('../users/user.mapper');

function mapRequest(row) {
  return {
    id: Number(row.id),
    senderId: Number(row.sender_id),
    receiverId: Number(row.receiver_id),
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    sender: row.sender_name
      ? {
          id: Number(row.sender_id),
          name: row.sender_name,
          email: row.sender_email,
          avatarPath: row.sender_avatar_path,
        }
      : undefined,
    receiver: row.receiver_name
      ? {
          id: Number(row.receiver_id),
          name: row.receiver_name,
          email: row.receiver_email,
          avatarPath: row.receiver_avatar_path,
        }
      : undefined,
  };
}

/** Find existing request between two users (any direction) */
async function findRequestBetween(userAId, userBId) {
  const result = await pool.query(
    `
      SELECT * FROM friend_requests
      WHERE (sender_id = $1 AND receiver_id = $2)
         OR (sender_id = $2 AND receiver_id = $1)
      LIMIT 1
    `,
    [userAId, userBId],
  );
  return result.rows[0] ? mapRequest(result.rows[0]) : null;
}

/** Create a new pending friend request */
async function createRequest(senderId, receiverId) {
  const result = await pool.query(
    `
      INSERT INTO friend_requests (sender_id, receiver_id, status)
      VALUES ($1, $2, 'pending')
      RETURNING *
    `,
    [senderId, receiverId],
  );
  return mapRequest(result.rows[0]);
}

/** Update status of a request by id */
async function updateRequestStatus(requestId, receiverId, status) {
  const result = await pool.query(
    `
      UPDATE friend_requests
      SET status = $3, updated_at = NOW()
      WHERE id = $1 AND receiver_id = $2
        AND status = 'pending'
      RETURNING *
    `,
    [requestId, receiverId, status],
  );
  return result.rows[0] ? mapRequest(result.rows[0]) : null;
}

/** Get all PENDING requests received by a user (with sender info) */
async function findPendingRequestsForUser(userId) {
  const result = await pool.query(
    `
      SELECT
        fr.*,
        u.name  AS sender_name,
        u.email AS sender_email,
        u.avatar_path AS sender_avatar_path
      FROM friend_requests fr
      JOIN users u ON u.id = fr.sender_id
      WHERE fr.receiver_id = $1
        AND fr.status = 'pending'
      ORDER BY fr.created_at DESC
    `,
    [userId],
  );
  return result.rows.map(mapRequest);
}

/** Get all ACCEPTED friends of a user (returns the OTHER user's details) */
async function findAcceptedFriends(userId) {
  const result = await pool.query(
    `
      SELECT
        u.id,
        u.name,
        u.email,
        u.avatar_path,
        u.public_key,
        u.created_at,
        u.updated_at
      FROM friend_requests fr
      JOIN users u ON (
        CASE
          WHEN fr.sender_id = $1 THEN u.id = fr.receiver_id
          ELSE u.id = fr.sender_id
        END
      )
      WHERE (fr.sender_id = $1 OR fr.receiver_id = $1)
        AND fr.status = 'accepted'
      ORDER BY u.name ASC
    `,
    [userId],
  );
  return result.rows.map(mapUser);
}

/** Re-open: delete a rejected request so the sender can try again */
async function deleteRequest(senderId, receiverId) {
  await pool.query(
    `
      DELETE FROM friend_requests
      WHERE sender_id = $1 AND receiver_id = $2
        AND status = 'rejected'
    `,
    [senderId, receiverId],
  );
}

/** Check if two users are accepted friends */
async function areFriends(userAId, userBId) {
  const result = await pool.query(
    `
      SELECT 1 FROM friend_requests
      WHERE ((sender_id = $1 AND receiver_id = $2)
          OR (sender_id = $2 AND receiver_id = $1))
        AND status = 'accepted'
      LIMIT 1
    `,
    [userAId, userBId],
  );
  return result.rows.length > 0;
}

module.exports = {
  findRequestBetween,
  createRequest,
  updateRequestStatus,
  findPendingRequestsForUser,
  findAcceptedFriends,
  deleteRequest,
  areFriends,
};
