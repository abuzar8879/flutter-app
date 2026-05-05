const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const env = require('./config/env');
const chatsService = require('./modules/chats/chats.service');
const groupsService = require('./modules/groups/groups.service');

const onlineUsers = new Map();
let activeIo = null;

function userRoom(userId) {
  return `user:${userId}`;
}

function groupRoom(groupId) {
  return `group:${groupId}`;
}

function initializeSocket(server) {
  const io = new Server(server, {
    cors: {
      origin: env.frontendOrigin,
    },
  });
  activeIo = io;

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) {
      return next(new Error('Authentication token is required.'));
    }

    try {
      socket.user = jwt.verify(token, env.jwtSecret);
      return next();
    } catch (_error) {
      return next(new Error('Authentication token is invalid or expired.'));
    }
  });

  io.on('connection', (socket) => {
    const userId = String(socket.user.sub);
    socket.join(userRoom(userId));

    // Join group rooms for accepted memberships
    groupsService
      .listAcceptedGroupIds(userId)
      .then((groupIds) => {
        for (const groupId of groupIds) {
          socket.join(groupRoom(groupId));
        }
      })
      .catch((error) => {
        console.error('Failed to join group rooms:', error.message);
      });

    const currentCount = onlineUsers.get(userId) ?? 0;
    onlineUsers.set(userId, currentCount + 1);
    if (currentCount === 0) {
      socket.broadcast.emit('user_online', { userId });
    }
    socket.emit('online_users', { userIds: [...onlineUsers.keys()] });

    socket.on('send_message', async (payload, callback) => {
      try {
        const result = await chatsService.sendMessage(userId, payload ?? {});
        io.to(userRoom(result.message.receiverId)).emit('message_received', result);
        io.to(userRoom(result.message.senderId)).emit('message_received', result);
        if (typeof callback === 'function') {
          callback({ ok: true, ...result });
        }
      } catch (error) {
        if (typeof callback === 'function') {
          callback({ ok: false, message: error.message });
        }
      }
    });

    socket.on('typing', (payload) => {
      if (payload && payload.receiverId) {
        io.to(userRoom(String(payload.receiverId))).emit('user_typing', {
          conversationId: payload.conversationId,
          userId,
        });
      }
    });

    socket.on('stop_typing', (payload) => {
      if (payload && payload.receiverId) {
        io.to(userRoom(String(payload.receiverId))).emit('user_stop_typing', {
          conversationId: payload.conversationId,
          userId,
        });
      }
    });

    socket.on('mark_read', async (payload) => {
      if (payload && payload.conversationId && payload.senderId) {
        try {
          await chatsService.markConversationRead(userId, payload.conversationId);
          io.to(userRoom(String(payload.senderId))).emit('messages_read', {
            conversationId: payload.conversationId,
            readerId: userId,
          });
        } catch (error) {
          console.error('Failed to mark read:', error.message);
        }
      }
    });

    // -----------------------
    // Group chat events
    // -----------------------
    socket.on('send_group_message', async (payload, callback) => {
      try {
        const groupId = String(payload?.groupId ?? '');
        if (!groupId) throw new Error('groupId is required.');
        const result = await groupsService.sendMessage(userId, groupId, payload ?? {});
        const eventPayload = {
          groupId,
          ...result,
        };
        io.to(groupRoom(groupId)).emit('group_message_received', eventPayload);
        // Also emit directly to each accepted member room for reliability,
        // in case a client missed room join/rejoin.
        const members = await groupsService.getGroupMembers(userId, groupId);
        for (const member of members) {
          if (member.status !== 'accepted') continue;
          io.to(userRoom(member.userId)).emit('group_message_received', eventPayload);
        }
        if (typeof callback === 'function') {
          callback({ ok: true, groupId, ...result });
        }
      } catch (error) {
        if (typeof callback === 'function') {
          callback({ ok: false, message: error.message });
        }
      }
    });

    socket.on('group_typing', (payload) => {
      const groupId = String(payload?.groupId ?? '');
      if (!groupId) return;
      const eventPayload = { groupId, userId };
      io.to(groupRoom(groupId)).emit('group_user_typing', eventPayload);
      groupsService
        .getGroupMembers(userId, groupId)
        .then((members) => {
          for (const member of members) {
            if (member.status !== 'accepted' || member.userId === userId) continue;
            io.to(userRoom(member.userId)).emit('group_user_typing', eventPayload);
          }
        })
        .catch((error) => {
          console.error('Failed to emit group typing:', error.message);
        });
    });

    socket.on('group_stop_typing', (payload) => {
      const groupId = String(payload?.groupId ?? '');
      if (!groupId) return;
      const eventPayload = { groupId, userId };
      io.to(groupRoom(groupId)).emit('group_user_stop_typing', eventPayload);
      groupsService
        .getGroupMembers(userId, groupId)
        .then((members) => {
          for (const member of members) {
            if (member.status !== 'accepted' || member.userId === userId) continue;
            io.to(userRoom(member.userId)).emit('group_user_stop_typing', eventPayload);
          }
        })
        .catch((error) => {
          console.error('Failed to emit group stop typing:', error.message);
        });
    });

    socket.on('mark_group_read', async (payload) => {
      const groupId = String(payload?.groupId ?? '');
      const lastReadMessageId = String(payload?.lastReadMessageId ?? '');
      if (!groupId || !lastReadMessageId) return;
      try {
        await groupsService.markRead(userId, groupId, lastReadMessageId);
        const eventPayload = {
          groupId,
          readerId: userId,
          lastReadMessageId,
        };
        io.to(groupRoom(groupId)).emit('group_messages_read', eventPayload);
        const members = await groupsService.getGroupMembers(userId, groupId);
        for (const member of members) {
          if (member.status !== 'accepted' || member.userId === userId) continue;
          io.to(userRoom(member.userId)).emit('group_messages_read', eventPayload);
        }
      } catch (error) {
        console.error('Failed to mark group read:', error.message);
      }
    });

    socket.on('join_group', async (payload, callback) => {
      try {
        const groupId = String(payload?.groupId ?? '');
        if (!groupId) throw new Error('groupId is required.');
        // Will throw if not accepted member
        await groupsService.getGroupMembers(userId, groupId);
        socket.join(groupRoom(groupId));
        if (typeof callback === 'function') callback({ ok: true });
      } catch (error) {
        if (typeof callback === 'function') callback({ ok: false, message: error.message });
      }
    });

    socket.on('disconnect', () => {
      const nextCount = (onlineUsers.get(userId) ?? 1) - 1;
      if (nextCount <= 0) {
        onlineUsers.delete(userId);
        socket.broadcast.emit('user_offline', { userId });
      } else {
        onlineUsers.set(userId, nextCount);
      }
    });
  });

  return io;
}

function emitChatMessage(result) {
  if (!activeIo || !result?.message) return;
  activeIo.to(userRoom(result.message.receiverId)).emit('message_received', result);
  activeIo.to(userRoom(result.message.senderId)).emit('message_received', result);
}

module.exports = {
  emitChatMessage,
  initializeSocket,
};
