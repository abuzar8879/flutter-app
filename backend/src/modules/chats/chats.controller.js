const path = require('path');
const chatsService = require('./chats.service');
const { emitChatMessage, emitChatMessageUpdated } = require('../../socket');

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
    emitChatMessage(result);
    response.status(201).json(result);
  } catch (error) {
    next(error);
  }
}

async function editMessage(request, response, next) {
  try {
    const result = await chatsService.editMessage(
      request.user.sub,
      request.params.conversationId,
      request.params.messageId,
      request.body,
    );
    emitChatMessageUpdated(result);
    response.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

async function deleteMessage(request, response, next) {
  try {
    const result = await chatsService.deleteMessage(
      request.user.sub,
      request.params.conversationId,
      request.params.messageId,
    );
    emitChatMessageUpdated(result);
    response.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

async function reactToMessage(request, response, next) {
  try {
    const result = await chatsService.reactToMessage(
      request.user.sub,
      request.params.conversationId,
      request.params.messageId,
      request.body,
    );
    emitChatMessageUpdated(result);
    response.status(200).json(result);
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

async function uploadAudio(request, response) {
  const fileName = path.basename(request.file.filename);
  response.status(201).json({
    audioPath: `/uploads/chat/${fileName}`,
  });
}

module.exports = {
  createConversation,
  getMessages,
  editMessage,
  deleteMessage,
  listConversations,
  markConversationRead,
  reactToMessage,
  sendMessage,
  uploadAudio,
  uploadImage,
};
