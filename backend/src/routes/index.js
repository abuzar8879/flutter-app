const express = require('express');
const authRoutes = require('../modules/auth/auth.routes');
const chatsRoutes = require('../modules/chats/chats.routes');
const friendsRoutes = require('../modules/friends/friends.routes');
const groupsRoutes = require('../modules/groups/groups.routes');
const healthRoutes = require('../modules/health/health.routes');
const profileRoutes = require('../modules/profile/profile.routes');
const usersRoutes = require('../modules/users/users.routes');

const router = express.Router();

router.use('/health', healthRoutes);
router.use('/auth', authRoutes);
router.use('/chats', chatsRoutes);
router.use('/groups', groupsRoutes);
router.use('/profile', profileRoutes);
router.use('/users', usersRoutes);
router.use('/friends', friendsRoutes);

module.exports = router;
