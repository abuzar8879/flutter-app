function mapGroup(row) {
  return {
    id: Number(row.id),
    name: row.name ?? '',
    createdBy: Number(row.created_by),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapGroupMember(row) {
  return {
    groupId: Number(row.group_id),
    userId: Number(row.user_id),
    role: row.role,
    status: row.status,
    invitedBy: row.invited_by != null ? Number(row.invited_by) : null,
    invitedAt: row.invited_at,
    joinedAt: row.joined_at,
    user: row.user_name
      ? {
          id: Number(row.user_id),
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
    id: Number(row.id),
    groupId: Number(row.group_id),
    senderId: Number(row.sender_id),
    type: row.type,
    content: row.content,
    imagePath: row.image_path,
    createdAt: row.created_at,
  };
}

function mapGroupSummary(row) {
  return {
    id: Number(row.id),
    name: row.name ?? '',
    createdBy: Number(row.created_by),
    updatedAt: row.updated_at,
    unreadCount: Number(row.unread_count ?? 0),
    memberCount: Number(row.member_count ?? 0),
    lastMessage: row.message_id
      ? {
          id: Number(row.message_id),
          groupId: Number(row.id),
          senderId: Number(row.message_sender_id),
          type: row.message_type,
          content: row.message_content,
          imagePath: row.message_image_path,
          createdAt: row.message_created_at,
        }
      : null,
  };
}

function mapGroupInvite(row) {
  return {
    group: {
      id: Number(row.group_id),
      name: row.group_name ?? '',
      createdBy: Number(row.group_created_by),
      createdAt: row.group_created_at,
    },
    invitedBy: row.invited_by != null
      ? {
          id: Number(row.invited_by),
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

