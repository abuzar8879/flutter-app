const AppError = require('../../utils/app-error');
const usersRepository = require('../users/users.repository');
const statusesRepository = require('./statuses.repository');

async function createStatus(userId, payload) {
  const text = String(payload?.text ?? '').trim();
  if (!text) {
    throw new AppError('Status text is required.', 400);
  }

  const user = await usersRepository.findUserById(String(userId));
  if (!user) {
    throw new AppError('User not found.', 404);
  }

  return statusesRepository.createStatus(user, text);
}

async function listStatuses() {
  return statusesRepository.findActiveStatuses();
}

module.exports = {
  createStatus,
  listStatuses,
};
