const usersRepository = require('./users.repository');

async function listUsers({ excludeId, search, limit, offset }) {
  return usersRepository.findAllUsers({
    excludeId: String(excludeId),
    search,
    limit: Math.min(Number(limit) || 50, 100),
    offset: Math.max(Number(offset) || 0, 0),
  });
}

async function updatePublicKey(userId, publicKey) {
  return usersRepository.updatePublicKey(String(userId), publicKey.trim());
}

async function updateFcmToken(userId, fcmToken) {
  return usersRepository.updateFcmToken(String(userId), fcmToken?.trim() ?? '');
}

module.exports = {
  listUsers,
  updatePublicKey,
  updateFcmToken,
};
