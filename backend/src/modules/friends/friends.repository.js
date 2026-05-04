const { mapUser } = require('../users/user.mapper');
const { ensureStringId, getValue, setValue, updateValue, removeValue, nowIso, pushChild } = require('../../db/rtdb');

function mapRequest(row) {
  return {
    id: String(row.id),
    senderId: String(row.senderId ?? row.sender_id),
    receiverId: String(row.receiverId ?? row.receiver_id),
    status: row.status,
    createdAt: row.createdAt ?? row.created_at ?? null,
    updatedAt: row.updatedAt ?? row.updated_at ?? null,
    sender: row.sender_name
      ? {
          id: String(row.sender_id),
          name: row.sender_name,
          email: row.sender_email,
          avatarPath: row.sender_avatar_path,
        }
      : undefined,
    receiver: row.receiver_name
      ? {
          id: String(row.receiver_id),
          name: row.receiver_name,
          email: row.receiver_email,
          avatarPath: row.receiver_avatar_path,
        }
      : undefined,
  };
}

/** Find existing request between two users (any direction) */
async function findRequestBetween(userAId, userBId) {
  const a = ensureStringId(String(userAId), 'userAId');
  const b = ensureStringId(String(userBId), 'userBId');
  const all = (await getValue('/friendRequests')) ?? {};
  const found = Object.values(all).find(
    (r) =>
      r &&
      ((String(r.senderId) === a && String(r.receiverId) === b) ||
        (String(r.senderId) === b && String(r.receiverId) === a)),
  );
  return found ? mapRequest(found) : null;
}

/** Create a new pending friend request */
async function createRequest(senderId, receiverId) {
  const sender = ensureStringId(String(senderId), 'senderId');
  const receiver = ensureStringId(String(receiverId), 'receiverId');
  const timestamp = nowIso();
  const { key: requestId } = await pushChild('/friendRequests', {});
  const request = {
    id: requestId,
    senderId: sender,
    receiverId: receiver,
    status: 'pending',
    createdAt: timestamp,
    updatedAt: timestamp,
  };
  await setValue(`/friendRequests/${requestId}`, request);
  return mapRequest(request);
}

/** Update status of a request by id */
async function updateRequestStatus(requestId, receiverId, status) {
  const id = ensureStringId(String(requestId), 'requestId');
  const receiver = ensureStringId(String(receiverId), 'receiverId');
  const req = await getValue(`/friendRequests/${id}`);
  if (!req) return null;
  if (String(req.receiverId) !== receiver) return null;
  if (req.status !== 'pending') return null;

  await updateValue(`/friendRequests/${id}`, { status, updatedAt: nowIso() });
  const updated = await getValue(`/friendRequests/${id}`);
  return updated ? mapRequest(updated) : null;
}

/** Get all PENDING requests received by a user (with sender info) */
async function findPendingRequestsForUser(userId) {
  const id = ensureStringId(String(userId), 'userId');
  const all = (await getValue('/friendRequests')) ?? {};
  const users = (await getValue('/users')) ?? {};
  return Object.values(all)
    .filter((r) => r && String(r.receiverId) === id && r.status === 'pending')
    .sort((a, b) => String(b.createdAt ?? '').localeCompare(String(a.createdAt ?? '')))
    .map((r) => {
      const sender = users[r.senderId];
      return mapRequest({
        ...r,
        sender_id: r.senderId,
        sender_name: sender?.name,
        sender_email: sender?.email,
        sender_avatar_path: sender?.avatarPath ?? null,
      });
    });
}

/** Get all ACCEPTED friends of a user (returns the OTHER user's details) */
async function findAcceptedFriends(userId) {
  const id = ensureStringId(String(userId), 'userId');
  const all = (await getValue('/friendRequests')) ?? {};
  const users = (await getValue('/users')) ?? {};
  const friendUsers = Object.values(all)
    .filter((r) => r && r.status === 'accepted' && (String(r.senderId) === id || String(r.receiverId) === id))
    .map((r) => (String(r.senderId) === id ? String(r.receiverId) : String(r.senderId)))
    .map((friendId) => users[friendId])
    .filter(Boolean)
    .sort((a, b) => String(a.name ?? '').localeCompare(String(b.name ?? '')));

  return friendUsers.map(mapUser);
}

/** Re-open: delete a rejected request so the sender can try again */
async function deleteRequest(senderId, receiverId) {
  const sender = ensureStringId(String(senderId), 'senderId');
  const receiver = ensureStringId(String(receiverId), 'receiverId');
  const all = (await getValue('/friendRequests')) ?? {};
  const entry = Object.values(all).find(
    (r) => r && String(r.senderId) === sender && String(r.receiverId) === receiver && r.status === 'rejected',
  );
  if (entry?.id) {
    await removeValue(`/friendRequests/${entry.id}`);
  }
}

/** Check if two users are accepted friends */
async function areFriends(userAId, userBId) {
  const req = await findRequestBetween(userAId, userBId);
  return Boolean(req && req.status === 'accepted');
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
