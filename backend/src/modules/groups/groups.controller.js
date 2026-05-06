const path = require('path');
const groupsService = require('./groups.service');
const { emitGroupMessage, emitGroupMessageUpdated } = require('../../socket');

async function createGroup(request, response, next) {
  try {
    const group = await groupsService.createGroup(request.user.sub, request.body ?? {});
    response.status(201).json({ group });
  } catch (error) {
    next(error);
  }
}

async function listGroups(request, response, next) {
  try {
    const groups = await groupsService.listGroups(request.user.sub, request.query);
    response.status(200).json({ groups });
  } catch (error) {
    next(error);
  }
}

async function listInvites(request, response, next) {
  try {
    const invites = await groupsService.listInvites(request.user.sub);
    response.status(200).json({ invites });
  } catch (error) {
    next(error);
  }
}

async function acceptInvite(request, response, next) {
  try {
    const member = await groupsService.acceptInvite(request.user.sub, request.params.groupId);
    response.status(200).json({ member });
  } catch (error) {
    next(error);
  }
}

async function rejectInvite(request, response, next) {
  try {
    const member = await groupsService.rejectInvite(request.user.sub, request.params.groupId);
    response.status(200).json({ member });
  } catch (error) {
    next(error);
  }
}

async function listMembers(request, response, next) {
  try {
    const members = await groupsService.getGroupMembers(request.user.sub, request.params.groupId);
    response.status(200).json({ members });
  } catch (error) {
    next(error);
  }
}

async function inviteMembers(request, response, next) {
  try {
    const invited = await groupsService.inviteMembers(
      request.user.sub,
      request.params.groupId,
      request.body ?? {},
    );
    response.status(201).json({ invited });
  } catch (error) {
    next(error);
  }
}

async function removeMember(request, response, next) {
  try {
    const removed = await groupsService.removeMember(
      request.user.sub,
      request.params.groupId,
      request.params.userId,
    );
    response.status(200).json({ removed });
  } catch (error) {
    next(error);
  }
}

async function getMessages(request, response, next) {
  try {
    const messages = await groupsService.getMessages(
      request.user.sub,
      request.params.groupId,
      request.query,
    );
    response.status(200).json({ messages });
  } catch (error) {
    next(error);
  }
}

async function sendMessage(request, response, next) {
  try {
    const result = await groupsService.sendMessage(
      request.user.sub,
      request.params.groupId,
      request.body ?? {},
    );
    await emitGroupMessage(
      {
        groupId: String(request.params.groupId),
        ...result,
      },
      request.user.sub,
    );
    response.status(201).json(result);
  } catch (error) {
    next(error);
  }
}

async function deleteMessage(request, response, next) {
  try {
    const result = await groupsService.deleteMessage(
      request.user.sub,
      request.params.groupId,
      request.params.messageId,
    );
    await emitGroupMessageUpdated(
      {
        groupId: String(request.params.groupId),
        ...result,
      },
      request.user.sub,
    );
    response.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

async function markRead(request, response, next) {
  try {
    const result = await groupsService.markRead(
      request.user.sub,
      request.params.groupId,
      request.body?.lastReadMessageId,
    );
    response.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

async function uploadImage(request, response) {
  const fileName = path.basename(request.file.filename);
  response.status(201).json({
    imagePath: `/uploads/group/${fileName}`,
  });
}

module.exports = {
  createGroup,
  listGroups,
  listInvites,
  acceptInvite,
  rejectInvite,
  listMembers,
  inviteMembers,
  removeMember,
  getMessages,
  sendMessage,
  deleteMessage,
  markRead,
  uploadImage,
};

