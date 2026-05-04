import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../domain/chat_message.dart';
import '../domain/conversation.dart';
import '../domain/conversation_summary.dart';

class ChatRepository {
  const ChatRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Conversation> getOrCreateConversation({
    required String token,
    required int friendId,
  }) async {
    final json = await _apiClient.postJson(
      '/api/chats/conversations',
      token: token,
      body: {'friendId': friendId},
    );
    return Conversation.fromJson(json['conversation'] as Map<String, dynamic>);
  }

  Future<List<ConversationSummary>> fetchConversations({
    required String token,
    int limit = 30,
    int offset = 0,
  }) async {
    final json = await _apiClient.getJson(
      '/api/chats/conversations?limit=$limit&offset=$offset',
      token: token,
    );
    final list = json['conversations'] as List<dynamic>? ?? [];
    return list
        .map(
          (item) => ConversationSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<ChatMessage>> fetchMessages({
    required String token,
    required int conversationId,
    int limit = 50,
    int? beforeId,
  }) async {
    final beforeQuery = beforeId == null ? '' : '&beforeId=$beforeId';
    final json = await _apiClient.getJson(
      '/api/chats/conversations/$conversationId/messages?limit=$limit$beforeQuery',
      token: token,
    );
    final list = json['messages'] as List<dynamic>? ?? [];
    return list
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markConversationRead({
    required String token,
    required int conversationId,
  }) async {
    await _apiClient.patchJson(
      '/api/chats/conversations/$conversationId/read',
      token: token,
    );
  }

  Future<ChatMessage> sendTextMessage({
    required String token,
    required int receiverId,
    required String content,
  }) async {
    final json = await _apiClient.postJson(
      '/api/chats/messages',
      token: token,
      body: {'receiverId': receiverId, 'content': content},
    );
    return ChatMessage.fromJson(json['message'] as Map<String, dynamic>);
  }

  Future<String> uploadImage({
    required String token,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final json = await _apiClient.postMultipartBytes(
      '/api/chats/images',
      token: token,
      fieldName: 'image',
      fileName: fileName,
      bytes: bytes,
    );
    return json['imagePath'] as String? ?? '';
  }

  Future<ChatMessage> sendImageMessage({
    required String token,
    required int receiverId,
    required String imagePath,
  }) async {
    final json = await _apiClient.postJson(
      '/api/chats/messages',
      token: token,
      body: {'receiverId': receiverId, 'type': 'image', 'imagePath': imagePath},
    );
    return ChatMessage.fromJson(json['message'] as Map<String, dynamic>);
  }

  Future<ChatMessage> sendEncryptedMessage({
    required String token,
    required int receiverId,
    required String content,
  }) async {
    final json = await _apiClient.postJson(
      '/api/chats/messages',
      token: token,
      body: {'receiverId': receiverId, 'type': 'encrypted', 'content': content},
    );
    return ChatMessage.fromJson(json['message'] as Map<String, dynamic>);
  }
}
