const AppError = require('../../utils/app-error');
const friendsRepository = require('../friends/friends.repository');
const usersRepository = require('../users/users.repository');
const groupsRepository = require('./groups.repository');

async function createGroup(creatorId, { name, inviteeIds }) {
  creatorId = String(creatorId);
  const normalizedInvitees = Array.isArray(inviteeIds)
    ? [...new Set(inviteeIds.map(String))].filter((id) => id && id !== creatorId)
    : [];

  const group = await groupsRepository.createGroup({ name, createdBy: creatorId });

  // Creator becomes admin and accepted
  await groupsRepository.addMember({
    groupId: group.id,
    userId: creatorId,
    role: 'admin',
    status: 'accepted',
    invitedBy: creatorId,
  });

  for (const finalId of normalizedInvitees) {
    // Must exist
    const user = await usersRepository.findUserById(finalId);
    if (!user) continue;

    // Must be friends
    const ok = await friendsRepository.areFriends(creatorId, finalId);
    if (!ok) continue;

    await groupsRepository.addMember({
      groupId: group.id,
      userId: finalId,
      role: 'member',
      status: 'invited',
      invitedBy: creatorId,
    });
  }

  return group;
}

async function listGroups(userId, query = {}) {
  userId = String(userId);
  const limit = Math.min(Number(query.limit) || 30, 100);
  const offset = Math.max(Number(query.offset) || 0, 0);
  return groupsRepository.listGroupsForUser(userId, { limit, offset });
}

async function listInvites(userId) {
  return groupsRepository.listInvitesForUser(String(userId));
}

async function acceptInvite(userId, groupId) {
  userId = String(userId);
  groupId = String(groupId);
  const updated = await groupsRepository.acceptInvite({ groupId, userId });
  if (!updated) throw new AppError('Invite not found.', 404);
  return updated;
}

async function rejectInvite(userId, groupId) {
  userId = String(userId);
  groupId = String(groupId);
  const removed = await groupsRepository.rejectInvite({ groupId, userId });
  if (!removed) throw new AppError('Invite not found.', 404);
  return removed;
}

async function _requireAcceptedMember(groupId, userId) {
  const membership = await groupsRepository.getMembership(String(groupId), String(userId));
  if (!membership || membership.status !== 'accepted') {
    throw new AppError('You are not a member of this group.', 403);
  }
  return membership;
}

async function _requireAdmin(groupId, userId) {
  const membership = await _requireAcceptedMember(groupId, userId);
  if (membership.role !== 'admin') {
    throw new AppError('Only the group admin can perform this action.', 403);
  }
  return membership;
}

async function getGroupMembers(userId, groupId) {
  await _requireAcceptedMember(groupId, userId);
  return groupsRepository.listMembers(String(groupId));
}

async function inviteMembers(adminId, groupId, { inviteeIds }) {
  adminId = String(adminId);
  groupId = String(groupId);
  await _requireAdmin(groupId, adminId);

  const normalizedInvitees = Array.isArray(inviteeIds)
    ? [...new Set(inviteeIds.map(String))].filter((id) => id && id !== adminId)
    : [];

  const invited = [];
  for (const finalId of normalizedInvitees) {
    const user = await usersRepository.findUserById(finalId);
    if (!user) continue;

    const ok = await friendsRepository.areFriends(adminId, finalId);
    if (!ok) continue;

    invited.push(
      await groupsRepository.addMember({
        groupId,
        userId: finalId,
        role: 'member',
        status: 'invited',
        invitedBy: adminId,
      }),
    );
  }

  return invited;
}

async function removeMember(adminId, groupId, memberUserId) {
  adminId = String(adminId);
  groupId = String(groupId);
  memberUserId = String(memberUserId);
  await _requireAdmin(groupId, adminId);

  if (adminId === memberUserId) {
    throw new AppError('Admin cannot remove themselves.', 400);
  }

  const removed = await groupsRepository.removeMember({ groupId, userId: memberUserId });
  if (!removed) throw new AppError('Member not found.', 404);
  return removed;
}

async function getMessages(userId, groupId, query = {}) {
  userId = String(userId);
  groupId = String(groupId);
  await _requireAcceptedMember(groupId, userId);

  const limit = Math.min(Number(query.limit) || 50, 200);
  const beforeId = query.beforeId ? String(query.beforeId) : undefined;
  return groupsRepository.listGroupMessages(groupId, { limit, beforeId });
}

async function sendMessage(userId, groupId, payload = {}) {
  userId = String(userId);
  groupId = String(groupId);
  await _requireAcceptedMember(groupId, userId);

  const type = payload.type ?? 'text';
  if (!['text', 'image', 'encrypted'].includes(type)) {
    throw new AppError('Invalid message type.', 400);
  }

  const content = payload.content ?? null;
  const imagePath = payload.imagePath ?? null;

  const message = await groupsRepository.createGroupMessage({
    groupId,
    senderId: userId,
    type,
    content,
    imagePath,
  });

  return { message };
}

async function deleteMessage(userId, groupId, messageId) {
  userId = String(userId);
  groupId = String(groupId);
  messageId = String(messageId);
  await _requireAcceptedMember(groupId, userId);

  const message = await groupsRepository.findGroupMessage(groupId, messageId);
  if (!message) throw new AppError('Message not found.', 404);
  if (message.senderId !== userId) {
    throw new AppError('You can only delete your own messages.', 403);
  }
  if (message.deletedAt) return { message };

  const updatedMessage = await groupsRepository.deleteGroupMessage({
    groupId,
    messageId,
  });
  return { message: updatedMessage };
}

async function markRead(userId, groupId, lastReadMessageId) {
  userId = String(userId);
  groupId = String(groupId);
  lastReadMessageId = String(lastReadMessageId);
  if (!lastReadMessageId) {
    throw new AppError('lastReadMessageId is required.', 400);
  }

  await _requireAcceptedMember(groupId, userId);
  await groupsRepository.markGroupRead({ groupId, userId, lastReadMessageId });
  return { ok: true };
}

async function listAcceptedGroupIds(userId) {
  return groupsRepository.listAcceptedGroupIdsForUser(String(userId));
}

module.exports = {
  createGroup,
  listGroups,
  listInvites,
  acceptInvite,
  rejectInvite,
  getGroupMembers,
  inviteMembers,
  removeMember,
  getMessages,
  sendMessage,
  deleteMessage,
  markRead,
  listAcceptedGroupIds,
};

