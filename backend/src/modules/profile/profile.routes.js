const express = require('express');

const { authenticate } = require('../../middlewares/authenticate');
const profileController = require('./profile.controller');
const { uploadProfileImage } = require('./profile.upload');

const router = express.Router();

router.get('/me', authenticate, profileController.getMyProfile);
router.patch('/me', authenticate, profileController.updateMyProfile);
router.post('/me/avatar', authenticate, uploadProfileImage.single('avatar'), profileController.uploadMyProfileImage);

module.exports = router;
