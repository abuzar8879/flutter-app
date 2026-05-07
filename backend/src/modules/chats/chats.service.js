const AppError = require('../../utils/app-error');
const friendsRepository = require('../friends/friends.repository');
const usersRepository = require('../users/users.repository');
const chatsRepository = require('./chats.repository');

const { sendPushNotification } = require('../../config/firebase');

async function getOrCreateConversation(userId, friendId) {
  userId = String(userId);
  friendId = String(friendId);

  if (userId === friendId) {
    throw new AppError('You cannot chat with yourself.', 400);
  }

  const friend = await usersRepository.findUserById(friendId);
  if (!friend) {
    throw new AppError('User not found.', 404);
  }

  const areFriends = await friendsRepository.areFriends(userId, friendId);
  if (!areFriends) {
    throw new AppError('You can only chat with accepted friends.', 403);
  }

  return chatsRepository.createConversation(userId, friendId);
}

async function getMessages(userId, conversationId, query = {}) {
  userId = String(userId);
  conversationId = String(conversationId);

  const conversation = await chatsRepository.findConversationForUser(conversationId, userId);
  if (!conversation) {
    throw new AppError('Conversation not found.', 404);
  }

  const limit = Math.min(Number(query.limit) || 50, 100);
  const beforeId = query.beforeId ? String(query.beforeId) : undefined;
  return chatsRepository.findMessagesForConversation(conversationId, { limit, beforeId });
}

async function listConversations(userId, query = {}) {
  const limit = Math.min(Number(query.limit) || 30, 100);
  const offset = Math.max(Number(query.offset) || 0, 0);
  return chatsRepository.findConversationSummaries(String(userId), { limit, offset });
}

async function markConversationRead(userId, conversationId) {
  userId = String(userId);
  conversationId = String(conversationId);

  const conversation = await chatsRepository.findConversationForUser(conversationId, userId);
  if (!conversation) {
    throw new AppError('Conversation not found.', 404);
  }

  await chatsRepository.markConversationRead(conversationId, userId);
  return { ok: true };
}

async function sendMessage(userId, payload) {
  const senderId = String(userId);
  const receiverId = String(payload.receiverId ?? '');
  const type = ['image', 'encrypted', 'voice'].includes(payload.type) ? payload.type : 'text';
  const content = typeof payload.content === 'string' ? payload.content.trim() : '';
  const imagePath = typeof payload.imagePath === 'string' ? payload.imagePath.trim() : '';
  const audioPath = typeof payload.audioPath === 'string' ? payload.audioPath.trim() : '';
  const replyToMessageId = payload.replyToMessageId ? String(payload.replyToMessageId) : null;

  if (!receiverId || receiverId === '0') {
    throw new AppError('receiverId is required.', 400);
  }

  if ((type === 'text' || type === 'encrypted') && !content) {
    throw new AppError('Message text is required.', 400);
  }

  if (type === 'image' && !imagePath.startsWith('/uploads/chat/')) {
    throw new AppError('A valid chat image path is required.', 400);
  }

  if (type === 'voice' && !audioPath.startsWith('/uploads/chat/')) {
    throw new AppError('A valid voice message path is required.', 400);
  }

  const conversation = await getOrCreateConversation(senderId, receiverId);
  if (replyToMessageId) {
    const replyTarget = await chatsRepository.findMessageForUser(conversation.id, replyToMessageId, senderId);
    if (!replyTarget || replyTarget.conversationId !== conversation.id) {
      throw new AppError('Reply target not found.', 404);
    }
  }

  const message = await chatsRepository.createMessage({
    conversationId: conversation.id,
    senderId,
    receiverId,
    type,
    content: type === 'text' || type === 'encrypted' ? content : null,
    imagePath: type === 'image' ? imagePath : null,
    audioPath: type === 'voice' ? audioPath : null,
    replyToMessageId,
  });

  const sender = await usersRepository.findUserById(senderId);
  const receiver = await usersRepository.findUserById(receiverId);

  if (receiver && receiver.fcmToken) {
    await sendPushNotification(
      receiver.fcmToken,
      sender ? sender.name : 'New Message',
      type === 'image' ? 'Sent a photo' : type === 'voice' ? 'Sent a voice message' : 'Sent a message',
      {
        targetType: 'private',
        conversationId: conversation.id.toString(),
        senderId: senderId.toString(),
        friendId: senderId.toString(),
        friendName: sender?.name ?? '',
        friendEmail: sender?.email ?? '',
        friendAvatarPath: sender?.avatarPath ?? '',
        friendPublicKey: sender?.publicKey ?? '',
        messageType: type,
      }
    );
  }

  return { conversation, message };
}

async function editMessage(userId, conversationId, messageId, payload = {}) {
  userId = String(userId);
  conversationId = String(conversationId);
  messageId = String(messageId);
  const content = typeof payload.content === 'string' ? payload.content.trim() : '';

  if (!content) {
    throw new AppError('Message text is required.', 400);
  }

  const message = await chatsRepository.findMessageForUser(conversationId, messageId, userId);
  if (!message) throw new AppError('Message not found.', 404);
  if (message.senderId !== userId) throw new AppError('You can only edit your own messages.', 403);
  if (message.deletedAt) throw new AppError('Deleted messages cannot be edited.', 400);
  if (message.type !== 'text' && message.type !== 'encrypted') {
    throw new AppError('Only text messages can be edited.', 400);
  }

  const updatedMessage = await chatsRepository.updateMessage({
    conversationId,
    messageId,
    content,
  });
  return { message: updatedMessage };
}

async function deleteMessage(userId, conversationId, messageId) {
  userId = String(userId);
  conversationId = String(conversationId);
  messageId = String(messageId);

  const message = await chatsRepository.findMessageForUser(conversationId, messageId, userId);
  if (!message) throw new AppError('Message not found.', 404);
  if (message.senderId !== userId) throw new AppError('You can only delete your own messages.', 403);
  if (message.deletedAt) return { message };

  const updatedMessage = await chatsRepository.deleteMessage({ conversationId, messageId });
  return { message: updatedMessage };
}

async function reactToMessage(userId, conversationId, messageId, payload = {}) {
  userId = String(userId);
  conversationId = String(conversationId);
  messageId = String(messageId);
  const reaction = typeof payload.reaction === 'string' ? payload.reaction.trim() : '';
  const allowed = new Set(['👍', '❤️', '😂', '😮', '😢', '🙏']);

  if (reaction && !allowed.has(reaction)) {
    throw new AppError('Unsupported reaction.', 400);
  }

  const message = await chatsRepository.findMessageForUser(conversationId, messageId, userId);
  if (!message) throw new AppError('Message not found.', 404);
  if (message.deletedAt) throw new AppError('Deleted messages cannot receive reactions.', 400);

  const updatedMessage = await chatsRepository.setReaction({
    conversationId,
    messageId,
    userId,
    reaction,
  });
  return { message: updatedMessage };
}

module.exports = {
  getMessages,
  getOrCreateConversation,
  listConversations,
  markConversationRead,
  editMessage,
  deleteMessage,
  reactToMessage,
  sendMessage,
};
