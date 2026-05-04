const { pool } = require('../../db/pool');
const {
  mapGroup,
  mapGroupInvite,
  mapGroupMember,
  mapGroupMessage,
  mapGroupSummary,
} = require('./group.mapper');

async function createGroup({ name, createdBy }) {
  const result = await pool.query(
    `
      INSERT INTO groups (name, created_by)
      VALUES ($1, $2)
      RETURNING *
    `,
    [name ?? null, createdBy],
  );

  return mapGroup(result.rows[0]);
}

async function addMember({
  groupId,
  userId,
  role = 'member',
  status = 'invited',
  invitedBy = null,
}) {
  const joinedAt = status === 'accepted' ? new Date() : null;
  const result = await pool.query(
    `
      INSERT INTO group_members (group_id, user_id, role, status, invited_by, invited_at, joined_at)
      VALUES ($1, $2, $3, $4, $5, NOW(), $6)
      ON CONFLICT (group_id, user_id)
      DO UPDATE SET
        role = EXCLUDED.role,
        status = EXCLUDED.status,
        invited_by = EXCLUDED.invited_by,
        invited_at = NOW(),
        joined_at = CASE WHEN EXCLUDED.status = 'accepted' THEN COALESCE(group_members.joined_at, NOW()) ELSE group_members.joined_at END
      RETURNING *
    `,
    [groupId, userId, role, status, invitedBy, joinedAt],
  );
  return mapGroupMember(result.rows[0]);
}

async function getMembership(groupId, userId) {
  const result = await pool.query(
    `
      SELECT *
      FROM group_members
      WHERE group_id = $1 AND user_id = $2
      LIMIT 1
    `,
    [groupId, userId],
  );
  return result.rows[0] ? mapGroupMember(result.rows[0]) : null;
}

async function acceptInvite({ groupId, userId }) {
  const result = await pool.query(
    `
      UPDATE group_members
      SET status = 'accepted', joined_at = NOW()
      WHERE group_id = $1 AND user_id = $2 AND status = 'invited'
      RETURNING *
    `,
    [groupId, userId],
  );
  return result.rows[0] ? mapGroupMember(result.rows[0]) : null;
}

async function rejectInvite({ groupId, userId }) {
  const result = await pool.query(
    `
      DELETE FROM group_members
      WHERE group_id = $1 AND user_id = $2 AND status = 'invited'
      RETURNING *
    `,
    [groupId, userId],
  );
  return result.rows[0] ? mapGroupMember(result.rows[0]) : null;
}

async function removeMember({ groupId, userId }) {
  const result = await pool.query(
    `
      DELETE FROM group_members
      WHERE group_id = $1 AND user_id = $2
      RETURNING *
    `,
    [groupId, userId],
  );
  return result.rows[0] ? mapGroupMember(result.rows[0]) : null;
}

async function listInvitesForUser(userId) {
  const result = await pool.query(
    `
      SELECT
        gm.group_id,
        gm.invited_by,
        gm.invited_at,
        g.name AS group_name,
        g.created_by AS group_created_by,
        g.created_at AS group_created_at,
        u.name AS invited_by_name,
        u.email AS invited_by_email,
        u.avatar_path AS invited_by_avatar_path
      FROM group_members gm
      JOIN groups g ON g.id = gm.group_id
      LEFT JOIN users u ON u.id = gm.invited_by
      WHERE gm.user_id = $1
        AND gm.status = 'invited'
      ORDER BY gm.invited_at DESC
    `,
    [userId],
  );
  return result.rows.map(mapGroupInvite);
}

async function listAcceptedGroupIdsForUser(userId) {
  const result = await pool.query(
    `
      SELECT group_id
      FROM group_members
      WHERE user_id = $1 AND status = 'accepted'
    `,
    [userId],
  );
  return result.rows.map((r) => Number(r.group_id));
}

async function listGroupsForUser(userId, { limit = 30, offset = 0 } = {}) {
  const result = await pool.query(
    `
      SELECT
        g.*,
        last_message.id AS message_id,
        last_message.sender_id AS message_sender_id,
        last_message.type AS message_type,
        last_message.content AS message_content,
        last_message.image_path AS message_image_path,
        last_message.created_at AS message_created_at,
        COALESCE(unread.count, 0) AS unread_count,
        COALESCE(mcount.count, 0) AS member_count
      FROM groups g
      JOIN group_members me
        ON me.group_id = g.id
       AND me.user_id = $1
       AND me.status = 'accepted'
      LEFT JOIN LATERAL (
        SELECT *
        FROM group_messages gm
        WHERE gm.group_id = g.id
        ORDER BY gm.created_at DESC, gm.id DESC
        LIMIT 1
      ) last_message ON true
      LEFT JOIN LATERAL (
        SELECT COUNT(*) AS count
        FROM group_messages gm
        LEFT JOIN group_reads gr
          ON gr.group_id = g.id AND gr.user_id = $1
        WHERE gm.group_id = g.id
          AND gm.sender_id <> $1
          AND (gr.last_read_message_id IS NULL OR gm.id > gr.last_read_message_id)
      ) unread ON true
      LEFT JOIN LATERAL (
        SELECT COUNT(*) AS count
        FROM group_members gm
        WHERE gm.group_id = g.id AND gm.status = 'accepted'
      ) mcount ON true
      ORDER BY COALESCE(last_message.created_at, g.updated_at) DESC, g.id DESC
      LIMIT $2 OFFSET $3
    `,
    [userId, limit, offset],
  );

  return result.rows.map(mapGroupSummary);
}

async function listMembers(groupId) {
  const result = await pool.query(
    `
      SELECT
        gm.*,
        u.name AS user_name,
        u.email AS user_email,
        u.avatar_path AS user_avatar_path,
        u.public_key AS user_public_key
      FROM group_members gm
      JOIN users u ON u.id = gm.user_id
      WHERE gm.group_id = $1
      ORDER BY
        CASE WHEN gm.role = 'admin' THEN 0 ELSE 1 END,
        u.name ASC
    `,
    [groupId],
  );
  return result.rows.map(mapGroupMember);
}

async function findGroupById(groupId) {
  const result = await pool.query(
    `
      SELECT *
      FROM groups
      WHERE id = $1
      LIMIT 1
    `,
    [groupId],
  );
  return result.rows[0] ? mapGroup(result.rows[0]) : null;
}

async function createGroupMessage({ groupId, senderId, type, content, imagePath }) {
  const result = await pool.query(
    `
      INSERT INTO group_messages (group_id, sender_id, type, content, image_path)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
    `,
    [groupId, senderId, type, content ?? null, imagePath ?? null],
  );

  await pool.query('UPDATE groups SET updated_at = NOW() WHERE id = $1', [groupId]);
  return mapGroupMessage(result.rows[0]);
}

async function listGroupMessages(groupId, { limit = 50, beforeId } = {}) {
  const params = [groupId, limit];
  let paginationClause = '';
  if (beforeId) {
    params.push(beforeId);
    paginationClause = `AND id < $${params.length}`;
  }

  const result = await pool.query(
    `
      SELECT *
      FROM group_messages
      WHERE group_id = $1
        ${paginationClause}
      ORDER BY id DESC
      LIMIT $2
    `,
    params,
  );

  return result.rows.reverse().map(mapGroupMessage);
}

async function markGroupRead({ groupId, userId, lastReadMessageId }) {
  await pool.query(
    `
      INSERT INTO group_reads (group_id, user_id, last_read_message_id, updated_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (group_id, user_id)
      DO UPDATE SET last_read_message_id = GREATEST(group_reads.last_read_message_id, EXCLUDED.last_read_message_id),
                    updated_at = NOW()
    `,
    [groupId, userId, lastReadMessageId],
  );
}

module.exports = {
  createGroup,
  addMember,
  getMembership,
  acceptInvite,
  rejectInvite,
  removeMember,
  listInvitesForUser,
  listAcceptedGroupIdsForUser,
  listGroupsForUser,
  listMembers,
  findGroupById,
  createGroupMessage,
  listGroupMessages,
  markGroupRead,
};

