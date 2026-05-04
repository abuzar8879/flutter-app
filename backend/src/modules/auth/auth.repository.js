const { pool } = require('../../db/pool');
const { mapUser } = require('../users/user.mapper');

async function createUser({ name, email, passwordHash }) {
  const result = await pool.query(
    `
      INSERT INTO users (name, email, password_hash)
      VALUES ($1, $2, $3)
      RETURNING id, name, email, avatar_path, public_key, created_at, updated_at
    `,
    [name, email.toLowerCase(), passwordHash],
  );

  return mapUser(result.rows[0]);
}

async function findUserByEmail(email) {
  const result = await pool.query(
    `
      SELECT id, name, email, password_hash, avatar_path, public_key, created_at, updated_at
      FROM users
      WHERE LOWER(email) = LOWER($1)
      LIMIT 1
    `,
    [email],
  );

  return result.rows[0] ?? null;
}

async function findUserById(id) {
  const result = await pool.query(
    `
      SELECT id, name, email, avatar_path, public_key, created_at, updated_at
      FROM users
      WHERE id = $1
      LIMIT 1
    `,
    [id],
  );

  return result.rows[0] ? mapUser(result.rows[0]) : null;
}

module.exports = {
  createUser,
  findUserByEmail,
  findUserById,
};
