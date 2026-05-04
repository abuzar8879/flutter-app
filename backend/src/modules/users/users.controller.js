const usersService = require('./users.service');

async function listUsers(request, response, next) {
  try {
    const { search } = request.query;
    const users = await usersService.listUsers({
      excludeId: request.user.sub,
      search: search ?? '',
      limit: request.query.limit,
      offset: request.query.offset,
    });
    response.status(200).json({ users });
  } catch (error) {
    next(error);
  }
}

async function updatePublicKey(request, response, next) {
  try {
    const { publicKey } = request.body;
    if (!publicKey || typeof publicKey !== 'string') {
      return response.status(400).json({ message: 'publicKey is required.' });
    }

    const user = await usersService.updatePublicKey(request.user.sub, publicKey);
    return response.status(200).json({ user });
  } catch (error) {
    return next(error);
  }
}

async function updateFcmToken(request, response, next) {
  try {
    const { fcmToken } = request.body;
    await usersService.updateFcmToken(request.user.sub, fcmToken);
    return response.status(200).json({ ok: true });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  listUsers,
  updatePublicKey,
  updateFcmToken,
};
