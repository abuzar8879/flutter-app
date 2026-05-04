const express = require('express');

const { authenticate } = require('../../middlewares/authenticate');
const authController = require('./auth.controller');

const router = express.Router();

router.post('/signup', authController.signup);
router.post('/login', authController.login);
router.get('/me', authenticate, authController.me);

module.exports = router;
