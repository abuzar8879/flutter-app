const authService = require('./auth.service');

async function signup(request, response, next) {
  try {
    const result = await authService.signup(request.body);
    response.status(201).json(result);
  } catch (error) {
    next(error);
  }
}

async function login(request, response, next) {
  try {
    const result = await authService.login(request.body);
    response.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

async function me(request, response, next) {
  try {
    const user = await authService.getCurrentUser(request.user.sub);
    response.status(200).json({ user });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  signup,
  login,
  me,
};
