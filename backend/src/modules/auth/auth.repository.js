const { mapUser } = require('../users/user.mapper');
const {
  ensureStringId,
  normalizeEmail,
  nowIso,
  getValue,
  setValue,
  pushChild,
} = require('../../db/rtdb');

async function createUser({ name, email, passwordHash }) {
  const emailLower = normalizeEmail(email);
  if (!emailLower) throw new Error('Email is required.');

  // Enforce uniqueness via index node
  const existing = await getValue(`/emailToUserId/${encodeURIComponent(emailLower)}`);
  if (existing) {
    const error = new Error('Email already exists.');
    error.code = 'EMAIL_EXISTS';
    throw error;
  }

  const { key: userId } = await pushChild('/users', {});
  ensureStringId(userId, 'userId');

  const timestamp = nowIso();
  const user = {
    id: userId,
    name,
    email: emailLower,
    emailLower,
    passwordHash,
    avatarPath: null,
    publicKey: null,
    fcmToken: null,
    createdAt: timestamp,
    updatedAt: timestamp,
  };

  await setValue(`/users/${userId}`, user);
  await setValue(`/emailToUserId/${encodeURIComponent(emailLower)}`, userId);

  return mapUser(user);
}

async function findUserByEmail(email) {
  const emailLower = normalizeEmail(email);
  if (!emailLower) return null;

  const userId = await getValue(`/emailToUserId/${encodeURIComponent(emailLower)}`);
  if (!userId) return null;

  const user = await getValue(`/users/${userId}`);
  if (!user) return null;

  return {
    id: user.id,
    name: user.name,
    email: user.email,
    password_hash: user.passwordHash,
    avatar_path: user.avatarPath,
    public_key: user.publicKey,
    created_at: user.createdAt,
    updated_at: user.updatedAt,
  };
}

async function findUserById(id) {
  const userId = ensureStringId(String(id), 'userId');
  const user = await getValue(`/users/${userId}`);
  return user ? mapUser(user) : null;
}

module.exports = {
  createUser,
  findUserByEmail,
  findUserById,
};
