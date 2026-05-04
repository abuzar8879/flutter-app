const profileService = require('./profile.service');

async function getMyProfile(request, response, next) {
  try {
    const profile = await profileService.getProfile(request.user.sub);
    response.status(200).json({ profile });
  } catch (error) {
    next(error);
  }
}

async function updateMyProfile(request, response, next) {
  try {
    const profile = await profileService.updateProfile(request.user.sub, request.body);
    response.status(200).json({ profile });
  } catch (error) {
    next(error);
  }
}

async function uploadMyProfileImage(request, response, next) {
  try {
    const profile = await profileService.updateProfileImage(request.user.sub, request.file);
    response.status(200).json({ profile });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getMyProfile,
  updateMyProfile,
  uploadMyProfileImage,
};
