const { Pool } = require('pg');
const env = require('../config/env');

const pool = env.databaseUrl
  ? new Pool({
      connectionString: env.databaseUrl,
      ssl: env.databaseSsl ? { rejectUnauthorized: false } : false,
    })
  : null;

let lastConnectionError = env.databaseUrl ? 'Database has not been checked yet.' : 'DATABASE_URL is not set.';

async function verifyDatabaseConnection() {
  if (!pool) {
    return {
      configured: false,
      connected: false,
      error: lastConnectionError,
    };
  }

  try {
    await pool.query('SELECT 1');
    lastConnectionError = null;

    return {
      configured: true,
      connected: true,
      error: null,
    };
  } catch (error) {
    lastConnectionError = error.message;

    return {
      configured: true,
      connected: false,
      error: lastConnectionError,
    };
  }
}

function getDatabaseStatus() {
  return {
    configured: Boolean(pool),
    lastConnectionError,
  };
}

module.exports = {
  pool,
  verifyDatabaseConnection,
  getDatabaseStatus,
};
