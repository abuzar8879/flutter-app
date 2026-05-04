const { pool } = require('../../db/pool');
const { mapUser } = require('./user.mapper');

async function findAllUsers({ excludeId, search, limit = 50, offset = 0 }) {
  let query = `
    SELECT id, name, email, avatar_path, public_key, fcm_token, created_at, updated_at
    FROM users
    WHERE id != $1
  `;
  const params = [excludeId];

  if (search && search.trim()) {
    params.push(`%${search.trim().toLowerCase()}%`);
    query += ` AND (LOWER(name) LIKE $${params.length} OR LOWER(email) LIKE $${params.length})`;
  }

  params.push(limit, offset);
  query += ` ORDER BY name ASC LIMIT $${params.length - 1} OFFSET $${params.length}`;

  const result = await pool.query(query, params);
  return result.rows.map(mapUser);
}

async function findUserById(id) {
  const result = await pool.query(
    `
      SELECT id, name, email, avatar_path, public_key, fcm_token, created_at, updated_at
      FROM users
      WHERE id = $1
      LIMIT 1
    `,
    [id],
  );
  return result.rows[0] ? mapUser(result.rows[0]) : null;
}

async function updatePublicKey(userId, publicKey) {
  const result = await pool.query(
    `
      UPDATE users
      SET public_key = $2, updated_at = NOW()
      WHERE id = $1
      RETURNING id, name, email, avatar_path, public_key, fcm_token, created_at, updated_at
    `,
    [userId, publicKey],
  );
  return result.rows[0] ? mapUser(result.rows[0]) : null;
}

async function updateFcmToken(userId, fcmToken) {
  await pool.query(
    `
      UPDATE users
      SET fcm_token = $2, updated_at = NOW()
      WHERE id = $1
    `,
    [userId, fcmToken],
  );
}

module.exports = {
  findAllUsers,
  findUserById,
  updatePublicKey,
  updateFcmToken,
};
