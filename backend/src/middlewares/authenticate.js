const jwt = require('jsonwebtoken');

const env = require('../config/env');
const AppError = require('../utils/app-error');

function authenticate(request, _response, next) {
  const authHeader = request.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new AppError('Authentication token is required.', 401));
  }

  const token = authHeader.replace('Bearer ', '').trim();

  try {
    request.user = jwt.verify(token, env.jwtSecret);
    return next();
  } catch (_error) {
    return next(new AppError('Authentication token is invalid or expired.', 401));
  }
}

module.exports = {
  authenticate,
};
