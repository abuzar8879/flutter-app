function mapConversation(row) {
  return {
    id: String(row.id),
    userOneId: String(row.userOneId ?? row.user_one_id),
    userTwoId: String(row.userTwoId ?? row.user_two_id),
    createdAt: row.createdAt ?? row.created_at ?? null,
    updatedAt: row.updatedAt ?? row.updated_at ?? null,
  };
}

function mapMessage(row) {
  const reactions = row.reactions && typeof row.reactions === 'object' ? row.reactions : {};
  return {
    id: String(row.id),
    conversationId: String(row.conversationId ?? row.conversation_id),
    senderId: String(row.senderId ?? row.sender_id),
    receiverId: String(row.receiverId ?? row.receiver_id),
    type: row.type,
    content: row.content,
    imagePath: row.imagePath ?? row.image_path ?? null,
    audioPath: row.audioPath ?? row.audio_path ?? null,
    replyToMessageId: row.replyToMessageId ?? row.reply_to_message_id ?? null,
    editedAt: row.editedAt ?? row.edited_at ?? null,
    deletedAt: row.deletedAt ?? row.deleted_at ?? null,
    reactions,
    readAt: row.readAt ?? row.read_at ?? null,
    createdAt: row.createdAt ?? row.created_at ?? null,
  };
}

function mapConversationSummary(row) {
  return {
    id: String(row.id),
    friend: {
      id: String(row.friend_id),
      name: row.friend_name,
      email: row.friend_email,
      avatarPath: row.friend_avatar_path,
      publicKey: row.friend_public_key,
    },
    lastMessage: row.message_id
      ? {
          id: String(row.message_id),
          conversationId: String(row.id),
          senderId: String(row.message_sender_id),
          receiverId: String(row.message_receiver_id),
          type: row.message_type,
          content: row.message_content,
          imagePath: row.message_image_path,
          audioPath: row.message_audio_path,
          replyToMessageId: row.message_reply_to_message_id,
          editedAt: row.message_edited_at,
          deletedAt: row.message_deleted_at,
          reactions: row.message_reactions ?? {},
          readAt: row.message_read_at,
          createdAt: row.message_created_at,
        }
      : null,
    unreadCount: Number(row.unread_count ?? 0),
    updatedAt: row.updated_at ?? null,
  };
}

module.exports = {
  mapConversation,
  mapConversationSummary,
  mapMessage,
};
