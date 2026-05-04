const {
  mapGroup,
  mapGroupInvite,
  mapGroupMember,
  mapGroupMessage,
  mapGroupSummary,
} = require('./group.mapper');
const { ensureStringId, nowIso, getValue, setValue, updateValue, removeValue, pushChild } = require('../../db/rtdb');

async function createGroup({ name, createdBy }) {
  const creatorId = ensureStringId(String(createdBy), 'createdBy');
  const timestamp = nowIso();
  const { key: groupId } = await pushChild('/groups', {});
  const group = {
    id: groupId,
    name: name ?? '',
    createdBy: creatorId,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
  await setValue(`/groups/${groupId}`, group);
  return mapGroup(group);
}

async function addMember({
  groupId,
  userId,
  role = 'member',
  status = 'invited',
  invitedBy = null,
}) {
  const gid = ensureStringId(String(groupId), 'groupId');
  const uid = ensureStringId(String(userId), 'userId');
  const timestamp = nowIso();
  const member = {
    groupId: gid,
    userId: uid,
    role,
    status,
    invitedBy: invitedBy != null ? String(invitedBy) : null,
    invitedAt: timestamp,
    joinedAt: status === 'accepted' ? timestamp : null,
  };
  await setValue(`/groupMembers/${gid}/${uid}`, member);
  return mapGroupMember(member);
}

async function getMembership(groupId, userId) {
  const gid = ensureStringId(String(groupId), 'groupId');
  const uid = ensureStringId(String(userId), 'userId');
  const member = await getValue(`/groupMembers/${gid}/${uid}`);
  return member ? mapGroupMember(member) : null;
}

async function acceptInvite({ groupId, userId }) {
  const gid = ensureStringId(String(groupId), 'groupId');
  const uid = ensureStringId(String(userId), 'userId');
  const member = await getValue(`/groupMembers/${gid}/${uid}`);
  if (!member || member.status !== 'invited') return null;
  const timestamp = nowIso();
  await updateValue(`/groupMembers/${gid}/${uid}`, { status: 'accepted', joinedAt: timestamp });
  const updated = await getValue(`/groupMembers/${gid}/${uid}`);
  return updated ? mapGroupMember(updated) : null;
}

async function rejectInvite({ groupId, userId }) {
  const gid = ensureStringId(String(groupId), 'groupId');
  const uid = ensureStringId(String(userId), 'userId');
  const member = await getValue(`/groupMembers/${gid}/${uid}`);
  if (!member || member.status !== 'invited') return null;
  await removeValue(`/groupMembers/${gid}/${uid}`);
  return mapGroupMember(member);
}

async function removeMember({ groupId, userId }) {
  const gid = ensureStringId(String(groupId), 'groupId');
  const uid = ensureStringId(String(userId), 'userId');
  const member = await getValue(`/groupMembers/${gid}/${uid}`);
  if (!member) return null;
  await removeValue(`/groupMembers/${gid}/${uid}`);
  return mapGroupMember(member);
}

async function listInvitesForUser(userId) {
  const uid = ensureStringId(String(userId), 'userId');
  const membersByGroup = (await getValue('/groupMembers')) ?? {};
  const groups = (await getValue('/groups')) ?? {};
  const users = (await getValue('/users')) ?? {};

  const invites = [];
  for (const [gid, members] of Object.entries(membersByGroup)) {
    const m = members?.[uid];
    if (!m || m.status !== 'invited') continue;
    const g = groups[gid];
    const inviter = m.invitedBy ? users[m.invitedBy] : null;
    invites.push(
      mapGroupInvite({
        group_id: gid,
        invited_by: m.invitedBy,
        invited_at: m.invitedAt,
        group_name: g?.name,
        group_created_by: g?.createdBy,
        group_created_at: g?.createdAt,
        invited_by_name: inviter?.name,
        invited_by_email: inviter?.email,
        invited_by_avatar_path: inviter?.avatarPath ?? null,
      }),
    );
  }
  invites.sort((a, b) => String(b.invitedAt ?? '').localeCompare(String(a.invitedAt ?? '')));
  return invites;
}

async function listAcceptedGroupIdsForUser(userId) {
  const uid = ensureStringId(String(userId), 'userId');
  const membersByGroup = (await getValue('/groupMembers')) ?? {};
  return Object.entries(membersByGroup)
    .filter(([_gid, members]) => members?.[uid]?.status === 'accepted')
    .map(([gid]) => gid);
}

async function listGroupsForUser(userId, { limit = 30, offset = 0 } = {}) {
  const uid = ensureStringId(String(userId), 'userId');
  const groupIds = await listAcceptedGroupIdsForUser(uid);
  const groups = (await getValue('/groups')) ?? {};
  const groupMembers = (await getValue('/groupMembers')) ?? {};
  const reads = (await getValue('/groupReads')) ?? {};

  const summaries = [];
  for (const gid of groupIds) {
    const g = groups[gid];
    if (!g) continue;
    const msgs = (await getValue(`/groupMessages/${gid}`)) ?? {};
    const msgList = Object.values(msgs).filter(Boolean);
    msgList.sort((a, b) => String(b.createdAt ?? '').localeCompare(String(a.createdAt ?? '')));
    const last = msgList[0] ?? null;
    const lastRead = reads?.[gid]?.[uid]?.lastReadMessageId ?? null;
    const unreadCount = msgList.filter((m) => String(m.senderId) !== uid && (!lastRead || String(m.id) > String(lastRead))).length;
    const memberCount = Object.values(groupMembers?.[gid] ?? {}).filter((m) => m && m.status === 'accepted').length;

    summaries.push(
      mapGroupSummary({
        id: gid,
        name: g.name,
        created_by: g.createdBy,
        updated_at: g.updatedAt,
        unread_count: unreadCount,
        member_count: memberCount,
        message_id: last?.id ?? null,
        message_sender_id: last?.senderId ?? null,
        message_type: last?.type ?? null,
        message_content: last?.content ?? null,
        message_image_path: last?.imagePath ?? null,
        message_created_at: last?.createdAt ?? null,
      }),
    );
  }

  summaries.sort((a, b) => String(b.updatedAt ?? '').localeCompare(String(a.updatedAt ?? '')));
  return summaries.slice(offset, offset + limit);
}

async function listMembers(groupId) {
  const gid = ensureStringId(String(groupId), 'groupId');
  const members = (await getValue(`/groupMembers/${gid}`)) ?? {};
  const users = (await getValue('/users')) ?? {};
  const list = Object.values(members)
    .filter(Boolean)
    .map((m) => {
      const u = users[m.userId];
      return mapGroupMember({
        ...m,
        user_id: m.userId,
        user_name: u?.name,
        user_email: u?.email,
        user_avatar_path: u?.avatarPath ?? null,
        user_public_key: u?.publicKey ?? null,
      });
    });

  list.sort((a, b) => {
    const roleA = a.role === 'admin' ? 0 : 1;
    const roleB = b.role === 'admin' ? 0 : 1;
    if (roleA !== roleB) return roleA - roleB;
    return String(a.user?.name ?? '').localeCompare(String(b.user?.name ?? ''));
  });

  return list;
}

async function findGroupById(groupId) {
  const gid = ensureStringId(String(groupId), 'groupId');
  const group = await getValue(`/groups/${gid}`);
  return group ? mapGroup(group) : null;
}

async function createGroupMessage({ groupId, senderId, type, content, imagePath }) {
  const gid = ensureStringId(String(groupId), 'groupId');
  const sid = ensureStringId(String(senderId), 'senderId');
  const timestamp = nowIso();
  const { key: messageId } = await pushChild(`/groupMessages/${gid}`, {});
  const message = {
    id: messageId,
    groupId: gid,
    senderId: sid,
    type,
    content: content ?? null,
    imagePath: imagePath ?? null,
    createdAt: timestamp,
  };
  await setValue(`/groupMessages/${gid}/${messageId}`, message);
  await updateValue(`/groups/${gid}`, { updatedAt: timestamp });
  return mapGroupMessage(message);
}

async function listGroupMessages(groupId, { limit = 50, beforeId } = {}) {
  const gid = ensureStringId(String(groupId), 'groupId');
  const all = (await getValue(`/groupMessages/${gid}`)) ?? {};
  const messages = Object.values(all)
    .filter(Boolean)
    .sort((a, b) => String(a.createdAt ?? '').localeCompare(String(b.createdAt ?? '')))
    .map(mapGroupMessage);

  if (beforeId) {
    const idx = messages.findIndex((m) => m.id === String(beforeId));
    const slice = idx > 0 ? messages.slice(0, idx) : messages;
    return slice.slice(Math.max(slice.length - limit, 0));
  }

  return messages.slice(Math.max(messages.length - limit, 0));
}

async function markGroupRead({ groupId, userId, lastReadMessageId }) {
  const gid = ensureStringId(String(groupId), 'groupId');
  const uid = ensureStringId(String(userId), 'userId');
  const msgId = ensureStringId(String(lastReadMessageId), 'lastReadMessageId');
  const existing = await getValue(`/groupReads/${gid}/${uid}`);
  const next = !existing?.lastReadMessageId || String(msgId) > String(existing.lastReadMessageId) ? msgId : existing.lastReadMessageId;
  await setValue(`/groupReads/${gid}/${uid}`, { lastReadMessageId: next, updatedAt: nowIso() });
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

