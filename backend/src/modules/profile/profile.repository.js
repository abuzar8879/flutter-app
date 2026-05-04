const { pool } = require('../../db/pool');
const { mapUser } = require('../users/user.mapper');

async function findProfileByUserId(userId) {
  const result = await pool.query(
    `
      SELECT id, name, email, avatar_path, created_at, updated_at
      FROM users
      WHERE id = $1
      LIMIT 1
    `,
    [userId],
  );

  return result.rows[0] ? mapUser(result.rows[0]) : null;
}

async function updateProfile(userId, { name }) {
  const result = await pool.query(
    `
      UPDATE users
      SET name = $2,
          updated_at = NOW()
      WHERE id = $1
      RETURNING id, name, email, avatar_path, created_at, updated_at
    `,
    [userId, name],
  );

  return result.rows[0] ? mapUser(result.rows[0]) : null;
}

async function updateProfileImage(userId, avatarPath) {
  const result = await pool.query(
    `
      UPDATE users
      SET avatar_path = $2,
          updated_at = NOW()
      WHERE id = $1
      RETURNING id, name, email, avatar_path, created_at, updated_at
    `,
    [userId, avatarPath],
  );

  return result.rows[0] ? mapUser(result.rows[0]) : null;
}

module.exports = {
  findProfileByUserId,
  updateProfile,
  updateProfileImage,
};
