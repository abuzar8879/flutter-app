const { mapUser } = require('./user.mapper');
const { ensureStringId, getValue, updateValue } = require('../../db/rtdb');

async function findAllUsers({ excludeId, search, limit = 50, offset = 0 }) {
  const excludeUserId = excludeId ? String(excludeId) : '';
  const all = (await getValue('/users')) ?? {};
  const searchTerm = search && search.trim() ? search.trim().toLowerCase() : '';

  const users = Object.values(all)
    .filter(Boolean)
    .filter((u) => !excludeUserId || String(u.id) !== excludeUserId)
    .filter((u) => {
      if (!searchTerm) return true;
      const name = String(u.name ?? '').toLowerCase();
      const email = String(u.email ?? '').toLowerCase();
      return name.includes(searchTerm) || email.includes(searchTerm);
    })
    .sort((a, b) => String(a.name ?? '').localeCompare(String(b.name ?? '')))
    .slice(offset, offset + limit);

  return users.map(mapUser);
}

async function findUserById(id) {
  const userId = ensureStringId(String(id), 'userId');
  const user = await getValue(`/users/${userId}`);
  return user ? mapUser(user) : null;
}

async function updatePublicKey(userId, publicKey) {
  const id = ensureStringId(String(userId), 'userId');
  await updateValue(`/users/${id}`, { publicKey, updatedAt: new Date().toISOString() });
  const updated = await getValue(`/users/${id}`);
  return updated ? mapUser(updated) : null;
}

async function updateFcmToken(userId, fcmToken) {
  const id = ensureStringId(String(userId), 'userId');
  await updateValue(`/users/${id}`, { fcmToken, updatedAt: new Date().toISOString() });
}

module.exports = {
  findAllUsers,
  findUserById,
  updatePublicKey,
  updateFcmToken,
};
