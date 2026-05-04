function mapConversation(row) {
  return {
    id: Number(row.id),
    userOneId: Number(row.user_one_id),
    userTwoId: Number(row.user_two_id),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapMessage(row) {
  return {
    id: Number(row.id),
    conversationId: Number(row.conversation_id),
    senderId: Number(row.sender_id),
    receiverId: Number(row.receiver_id),
    type: row.type,
    content: row.content,
    imagePath: row.image_path,
    readAt: row.read_at,
    createdAt: row.created_at,
  };
}

function mapConversationSummary(row) {
  return {
    id: Number(row.id),
    friend: {
      id: Number(row.friend_id),
      name: row.friend_name,
      email: row.friend_email,
      avatarPath: row.friend_avatar_path,
      publicKey: row.friend_public_key,
    },
    lastMessage: row.message_id
      ? {
          id: Number(row.message_id),
          conversationId: Number(row.id),
          senderId: Number(row.message_sender_id),
          receiverId: Number(row.message_receiver_id),
          type: row.message_type,
          content: row.message_content,
          imagePath: row.message_image_path,
          readAt: row.message_read_at,
          createdAt: row.message_created_at,
        }
      : null,
    unreadCount: Number(row.unread_count ?? 0),
    updatedAt: row.updated_at,
  };
}

module.exports = {
  mapConversation,
  mapConversationSummary,
  mapMessage,
};
