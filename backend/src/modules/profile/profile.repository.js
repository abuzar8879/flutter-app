const { mapUser } = require('../users/user.mapper');
const { ensureStringId, getValue, updateValue } = require('../../db/rtdb');

async function findProfileByUserId(userId) {
  const id = ensureStringId(String(userId), 'userId');
  const user = await getValue(`/users/${id}`);
  return user ? mapUser(user) : null;
}

async function updateProfile(userId, { name }) {
  const id = ensureStringId(String(userId), 'userId');
  await updateValue(`/users/${id}`, { name, updatedAt: new Date().toISOString() });
  const updated = await getValue(`/users/${id}`);
  return updated ? mapUser(updated) : null;
}

async function updateProfileImage(userId, avatarPath) {
  const id = ensureStringId(String(userId), 'userId');
  await updateValue(`/users/${id}`, { avatarPath, updatedAt: new Date().toISOString() });
  const updated = await getValue(`/users/${id}`);
  return updated ? mapUser(updated) : null;
}

module.exports = {
  findProfileByUserId,
  updateProfile,
  updateProfileImage,
};
