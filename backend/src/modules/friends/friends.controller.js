const friendsService = require('./friends.service');

async function sendRequest(request, response, next) {
  try {
    const senderId = request.user.sub;
    const { receiverId } = request.body;

    if (!receiverId) {
      return response.status(400).json({ message: 'receiverId is required.' });
    }

    const result = await friendsService.sendRequest(senderId, Number(receiverId));
    return response.status(201).json({ request: result });
  } catch (error) {
    return next(error);
  }
}

async function respondToRequest(request, response, next) {
  try {
    const receiverId = request.user.sub;
    const { id } = request.params;
    const { action } = request.body;

    if (!action) {
      return response.status(400).json({ message: 'action is required (accepted | rejected).' });
    }

    const result = await friendsService.respondToRequest(Number(id), receiverId, action);
    return response.status(200).json({ request: result });
  } catch (error) {
    return next(error);
  }
}

async function getPendingRequests(request, response, next) {
  try {
    const requests = await friendsService.getPendingRequests(request.user.sub);
    return response.status(200).json({ requests });
  } catch (error) {
    return next(error);
  }
}

async function getMyFriends(request, response, next) {
  try {
    const friends = await friendsService.getMyFriends(request.user.sub);
    return response.status(200).json({ friends });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  sendRequest,
  respondToRequest,
  getPendingRequests,
  getMyFriends,
};
