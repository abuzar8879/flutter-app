const AppError = require('../../utils/app-error');
const usersRepository = require('../users/users.repository');
const friendsRepository = require('./friends.repository');

async function sendRequest(senderId, receiverId) {
  senderId = Number(senderId);
  receiverId = Number(receiverId);

  if (senderId === receiverId) {
    throw new AppError('You cannot send a friend request to yourself.', 400);
  }

  // Receiver must exist
  const receiver = await usersRepository.findUserById(receiverId);
  if (!receiver) {
    throw new AppError('User not found.', 404);
  }

  const existing = await friendsRepository.findRequestBetween(senderId, receiverId);

  if (existing) {
    if (existing.status === 'accepted') {
      throw new AppError('You are already friends.', 409);
    }

    if (existing.status === 'pending') {
      // If the OTHER person already sent a request, auto-accept it
      if (existing.senderId === receiverId) {
        return friendsRepository.updateRequestStatus(existing.id, senderId, 'accepted');
      }
      throw new AppError('Friend request already sent.', 409);
    }

    // Rejected: delete old row so a new one can be created
    if (existing.status === 'rejected') {
      await friendsRepository.deleteRequest(existing.senderId, existing.receiverId);
    }
  }

  return friendsRepository.createRequest(senderId, receiverId);
}

async function respondToRequest(requestId, receiverId, action) {
  receiverId = Number(receiverId);

  if (!['accepted', 'rejected'].includes(action)) {
    throw new AppError('Action must be accepted or rejected.', 400);
  }

  const updated = await friendsRepository.updateRequestStatus(requestId, receiverId, action);
  if (!updated) {
    throw new AppError('Friend request not found or you are not the receiver.', 404);
  }

  return updated;
}

async function getPendingRequests(userId) {
  return friendsRepository.findPendingRequestsForUser(Number(userId));
}

async function getMyFriends(userId) {
  return friendsRepository.findAcceptedFriends(Number(userId));
}

module.exports = {
  sendRequest,
  respondToRequest,
  getPendingRequests,
  getMyFriends,
};
