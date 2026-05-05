const express = require('express');
const { authenticate } = require('../../middlewares/authenticate');
const chatsController = require('./chats.controller');
const { uploadChatAudio, uploadChatImage } = require('./chats.upload');

const router = express.Router();

router.post('/conversations', authenticate, chatsController.createConversation);
router.get('/conversations', authenticate, chatsController.listConversations);
router.get('/conversations/:conversationId/messages', authenticate, chatsController.getMessages);
router.patch(
  '/conversations/:conversationId/read',
  authenticate,
  chatsController.markConversationRead,
);
router.post('/messages', authenticate, chatsController.sendMessage);
router.patch(
  '/conversations/:conversationId/messages/:messageId',
  authenticate,
  chatsController.editMessage,
);
router.delete(
  '/conversations/:conversationId/messages/:messageId',
  authenticate,
  chatsController.deleteMessage,
);
router.patch(
  '/conversations/:conversationId/messages/:messageId/reaction',
  authenticate,
  chatsController.reactToMessage,
);
router.post(
  '/images',
  authenticate,
  uploadChatImage.single('image'),
  chatsController.uploadImage,
);
router.post(
  '/audio',
  authenticate,
  uploadChatAudio.single('audio'),
  chatsController.uploadAudio,
);

module.exports = router;
