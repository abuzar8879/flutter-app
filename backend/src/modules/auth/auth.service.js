const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const env = require('../../config/env');
const AppError = require('../../utils/app-error');
const authRepository = require('./auth.repository');

function buildAuthResponse(user) {
  const token = jwt.sign(
    {
      sub: String(user.id),
      email: user.email,
      name: user.name,
    },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn },
  );

  return {
    token,
    user,
  };
}

function validateCredentials({ name, email, password }, requireName) {
  if (requireName && (!name || !name.trim())) {
    throw new AppError('Name is required.', 400);
  }

  if (!email || !email.trim()) {
    throw new AppError('Email is required.', 400);
  }

  if (!password || password.length < 6) {
    throw new AppError('Password must be at least 6 characters.', 400);
  }
}

async function signup(payload) {
  validateCredentials(payload, true);

  const existingUser = await authRepository.findUserByEmail(payload.email);
  if (existingUser) {
    throw new AppError('An account with this email already exists.', 409);
  }

  const passwordHash = await bcrypt.hash(payload.password, 10);
  const user = await authRepository.createUser({
    name: payload.name.trim(),
    email: payload.email.trim(),
    passwordHash,
  });

  return buildAuthResponse(user);
}

async function login(payload) {
  validateCredentials({ ...payload, name: 'unused' }, false);

  const user = await authRepository.findUserByEmail(payload.email);
  if (!user) {
    throw new AppError('Invalid email or password.', 401);
  }

  const passwordMatches = await bcrypt.compare(payload.password, user.password_hash);
  if (!passwordMatches) {
    throw new AppError('Invalid email or password.', 401);
  }

  return buildAuthResponse({
    id: String(user.id),
    name: user.name,
    email: user.email,
    avatarPath: user.avatar_path,
    publicKey: user.public_key,
    createdAt: user.created_at,
    updatedAt: user.updated_at,
  });
}

async function getCurrentUser(userId) {
  const user = await authRepository.findUserById(String(userId));
  if (!user) {
    throw new AppError('User not found.', 404);
  }

  return user;
}

module.exports = {
  signup,
  login,
  getCurrentUser,
};
