const express = require('express');
const { authenticate } = require('../../middlewares/authenticate');
const groupsController = require('./groups.controller');
const { uploadGroupImage } = require('./groups.upload');

const router = express.Router();

// Groups
router.post('/', authenticate, groupsController.createGroup);
router.get('/', authenticate, groupsController.listGroups);

// Invites (for current user)
router.get('/invites', authenticate, groupsController.listInvites);
router.post('/:groupId/invites/accept', authenticate, groupsController.acceptInvite);
router.post('/:groupId/invites/reject', authenticate, groupsController.rejectInvite);

// Members (admin manages)
router.get('/:groupId/members', authenticate, groupsController.listMembers);
router.post('/:groupId/invites', authenticate, groupsController.inviteMembers);
router.delete('/:groupId/members/:userId', authenticate, groupsController.removeMember);

// Messages
router.get('/:groupId/messages', authenticate, groupsController.getMessages);
router.post('/:groupId/messages', authenticate, groupsController.sendMessage);
router.patch('/:groupId/read', authenticate, groupsController.markRead);

// Upload image
router.post(
  '/images',
  authenticate,
  uploadGroupImage.single('image'),
  groupsController.uploadImage,
);

module.exports = router;

