import '../../users/domain/app_user.dart';
import 'chat_message.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.friend,
    required this.unreadCount,
    required this.updatedAt,
    this.lastMessage,
  });

  final int id;
  final AppUser friend;
  final int unreadCount;
  final String updatedAt;
  final ChatMessage? lastMessage;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final messageJson = json['lastMessage'];
    return ConversationSummary(
      id: _readId(json['id']),
      friend: AppUser.fromJson(json['friend'] as Map<String, dynamic>),
      unreadCount: _readId(json['unreadCount']),
      updatedAt: json['updatedAt'] as String? ?? '',
      lastMessage: messageJson is Map<String, dynamic>
          ? ChatMessage.fromJson(messageJson)
          : null,
    );
  }
}

int _readId(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
