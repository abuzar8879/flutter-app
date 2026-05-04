const { pool } = require('./pool');

async function ensureDatabaseSchema() {
  if (!pool) {
    return;
  }

  const client = await pool.connect();

  try {
    await client.query("SELECT pg_advisory_lock(hashtext('chat_app_schema_setup'))");

    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id BIGSERIAL PRIMARY KEY,
        name VARCHAR(120) NOT NULL,
        email VARCHAR(255) NOT NULL,
        password_hash TEXT NOT NULL,
        avatar_path TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    await client.query(`
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS avatar_path TEXT;
    `);

    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique_idx
      ON users (LOWER(email));
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS friend_requests (
        id BIGSERIAL PRIMARY KEY,
        sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        receiver_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status VARCHAR(20) NOT NULL DEFAULT 'pending'
          CHECK (status IN ('pending', 'accepted', 'rejected')),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT friend_requests_unique UNIQUE (sender_id, receiver_id)
      );
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS friend_requests_receiver_idx
      ON friend_requests (receiver_id);
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS friend_requests_sender_idx
      ON friend_requests (sender_id);
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS conversations (
        id BIGSERIAL PRIMARY KEY,
        user_one_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        user_two_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CHECK (user_one_id < user_two_id),
        CONSTRAINT conversations_pair_unique UNIQUE (user_one_id, user_two_id)
      );
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id BIGSERIAL PRIMARY KEY,
        conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
        sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        receiver_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type VARCHAR(20) NOT NULL DEFAULT 'text'
          CHECK (type IN ('text', 'image', 'encrypted')),
        content TEXT,
        image_path TEXT,
        read_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    await client.query(`
      ALTER TABLE messages
      ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
    `);

    await client.query(`
      ALTER TABLE messages
      DROP CONSTRAINT IF EXISTS messages_type_check;
    `);

    await client.query(`
      ALTER TABLE messages
      ADD CONSTRAINT messages_type_check
      CHECK (type IN ('text', 'image', 'encrypted'));
    `);

    await client.query(`
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS public_key TEXT;
    `);

    await client.query(`
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS fcm_token TEXT;
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS messages_conversation_created_idx
      ON messages (conversation_id, created_at);
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS conversations_user_one_idx
      ON conversations (user_one_id);
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS conversations_user_two_idx
      ON conversations (user_two_id);
    `);

    // ---------------------------
    // Group chats
    // ---------------------------
    await client.query(`
      CREATE TABLE IF NOT EXISTS groups (
        id BIGSERIAL PRIMARY KEY,
        name VARCHAR(160),
        created_by BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS group_members (
        group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        role VARCHAR(20) NOT NULL DEFAULT 'member'
          CHECK (role IN ('admin', 'member')),
        status VARCHAR(20) NOT NULL DEFAULT 'invited'
          CHECK (status IN ('invited', 'accepted')),
        invited_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
        invited_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        joined_at TIMESTAMPTZ,
        PRIMARY KEY (group_id, user_id)
      );
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS group_members_user_idx
      ON group_members (user_id);
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS group_members_group_status_idx
      ON group_members (group_id, status);
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS group_messages (
        id BIGSERIAL PRIMARY KEY,
        group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type VARCHAR(20) NOT NULL DEFAULT 'text'
          CHECK (type IN ('text', 'image', 'encrypted')),
        content TEXT,
        image_path TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS group_messages_group_created_idx
      ON group_messages (group_id, created_at, id);
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS group_reads (
        group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        last_read_message_id BIGINT,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (group_id, user_id)
      );
    `);
  } finally {
    await client.query("SELECT pg_advisory_unlock(hashtext('chat_app_schema_setup'))");
    client.release();
  }
}

module.exports = {
  ensureDatabaseSchema,
};
