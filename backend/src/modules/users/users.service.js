const usersRepository = require('./users.repository');

async function listUsers({ excludeId, search, limit, offset }) {
  return usersRepository.findAllUsers({
    excludeId: Number(excludeId),
    search,
    limit: Math.min(Number(limit) || 50, 100),
    offset: Math.max(Number(offset) || 0, 0),
  });
}

async function updatePublicKey(userId, publicKey) {
  return usersRepository.updatePublicKey(Number(userId), publicKey.trim());
}

async function updateFcmToken(userId, fcmToken) {
  return usersRepository.updateFcmToken(Number(userId), fcmToken?.trim() ?? '');
}

module.exports = {
  listUsers,
  updatePublicKey,
  updateFcmToken,
};
