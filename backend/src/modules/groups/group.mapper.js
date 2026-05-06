function mapGroup(row) {
  return {
    id: String(row.id),
    name: row.name ?? '',
    createdBy: String(row.createdBy ?? row.created_by),
    createdAt: row.createdAt ?? row.created_at ?? null,
    updatedAt: row.updatedAt ?? row.updated_at ?? null,
  };
}

function mapGroupMember(row) {
  return {
    groupId: String(row.groupId ?? row.group_id),
    userId: String(row.userId ?? row.user_id),
    role: row.role,
    status: row.status,
    invitedBy: row.invitedBy ?? row.invited_by ?? null,
    invitedAt: row.invitedAt ?? row.invited_at ?? null,
    joinedAt: row.joinedAt ?? row.joined_at ?? null,
    user: row.user_name
      ? {
          id: String(row.user_id),
          name: row.user_name,
          email: row.user_email,
          avatarPath: row.user_avatar_path,
          publicKey: row.user_public_key,
        }
      : undefined,
  };
}

function mapGroupMessage(row) {
  return {
    id: String(row.id),
    groupId: String(row.groupId ?? row.group_id),
    senderId: String(row.senderId ?? row.sender_id),
    type: row.type,
    content: row.content,
    imagePath: row.imagePath ?? row.image_path ?? null,
    deletedAt: row.deletedAt ?? row.deleted_at ?? null,
    createdAt: row.createdAt ?? row.created_at ?? null,
  };
}

function mapGroupSummary(row) {
  return {
    id: String(row.id),
    name: row.name ?? '',
    createdBy: String(row.createdBy ?? row.created_by),
    updatedAt: row.updatedAt ?? row.updated_at ?? null,
    unreadCount: Number(row.unread_count ?? 0),
    memberCount: Number(row.member_count ?? 0),
    lastMessage: row.message_id
      ? {
          id: String(row.message_id),
          groupId: String(row.id),
          senderId: String(row.message_sender_id),
        type: row.message_type,
        content: row.message_content,
        imagePath: row.message_image_path,
        deletedAt: row.message_deleted_at ?? null,
        createdAt: row.message_created_at,
      }
      : null,
  };
}

function mapGroupInvite(row) {
  return {
    group: {
      id: String(row.group_id),
      name: row.group_name ?? '',
      createdBy: String(row.group_created_by),
      createdAt: row.group_created_at,
    },
    invitedBy: row.invited_by != null
      ? {
          id: String(row.invited_by),
          name: row.invited_by_name,
          email: row.invited_by_email,
          avatarPath: row.invited_by_avatar_path,
        }
      : null,
    invitedAt: row.invited_at,
  };
}

module.exports = {
  mapGroup,
  mapGroupMember,
  mapGroupMessage,
  mapGroupSummary,
  mapGroupInvite,
};

