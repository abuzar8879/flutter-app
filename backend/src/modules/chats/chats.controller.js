const path = require('path');
const chatsService = require('./chats.service');

async function createConversation(request, response, next) {
  try {
    const conversation = await chatsService.getOrCreateConversation(
      request.user.sub,
      request.body.friendId,
    );
    response.status(200).json({ conversation });
  } catch (error) {
    next(error);
  }
}

async function listConversations(request, response, next) {
  try {
    const conversations = await chatsService.listConversations(
      request.user.sub,
      request.query,
    );
    response.status(200).json({ conversations });
  } catch (error) {
    next(error);
  }
}

async function getMessages(request, response, next) {
  try {
    const messages = await chatsService.getMessages(
      request.user.sub,
      request.params.conversationId,
      request.query,
    );
    response.status(200).json({ messages });
  } catch (error) {
    next(error);
  }
}

async function markConversationRead(request, response, next) {
  try {
    const result = await chatsService.markConversationRead(
      request.user.sub,
      request.params.conversationId,
    );
    response.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

async function sendMessage(request, response, next) {
  try {
    const result = await chatsService.sendMessage(request.user.sub, request.body);
    response.status(201).json(result);
  } catch (error) {
    next(error);
  }
}

async function uploadImage(request, response) {
  const fileName = path.basename(request.file.filename);
  response.status(201).json({
    imagePath: `/uploads/chat/${fileName}`,
  });
}

module.exports = {
  createConversation,
  getMessages,
  listConversations,
  markConversationRead,
  sendMessage,
  uploadImage,
};
