const express = require('express');
const { authenticate } = require('../../middlewares/authenticate');
const usersController = require('./users.controller');

const router = express.Router();

router.get('/', authenticate, usersController.listUsers);
router.patch('/me/public-key', authenticate, usersController.updatePublicKey);
router.patch('/me/fcm-token', authenticate, usersController.updateFcmToken);

module.exports = router;
