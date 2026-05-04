const AppError = require('../../utils/app-error');
const profileRepository = require('./profile.repository');

async function getProfile(userId) {
  const profile = await profileRepository.findProfileByUserId(String(userId));
  if (!profile) {
    throw new AppError('User profile not found.', 404);
  }

  return profile;
}

async function updateProfile(userId, payload) {
  if (!payload.name || !payload.name.trim()) {
    throw new AppError('Name is required.', 400);
  }

  const profile = await profileRepository.updateProfile(String(userId), {
    name: payload.name.trim(),
  });

  if (!profile) {
    throw new AppError('User profile not found.', 404);
  }

  return profile;
}

async function updateProfileImage(userId, file) {
  if (!file) {
    throw new AppError('Profile image is required.', 400);
  }

  const avatarPath = `/uploads/profile/${file.filename}`;
  const profile = await profileRepository.updateProfileImage(String(userId), avatarPath);

  if (!profile) {
    throw new AppError('User profile not found.', 404);
  }

  return profile;
}

module.exports = {
  getProfile,
  updateProfile,
  updateProfileImage,
};
