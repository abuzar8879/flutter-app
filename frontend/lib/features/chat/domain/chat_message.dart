import '../../../core/config/app_config.dart';

enum ChatMessageType { text, image, encrypted }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.createdAt,
    this.content,
    this.imagePath,
    this.readAt,
  });

  final int id;
  final int conversationId;
  final int senderId;
  final int receiverId;
  final ChatMessageType type;
  final String createdAt;
  final String? content;
  final String? imagePath;
  final String? readAt;

  DateTime get createdAtDate => _parseDateTime(createdAt);

  String? get imageUrl => imagePath == null || imagePath!.isEmpty
      ? null
      : '${AppConfig.apiBaseUrl}$imagePath';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _readId(json['id']),
      conversationId: _readId(json['conversationId']),
      senderId: _readId(json['senderId']),
      receiverId: _readId(json['receiverId']),
      type: switch (json['type']) {
        'image' => ChatMessageType.image,
        'encrypted' => ChatMessageType.encrypted,
        _ => ChatMessageType.text,
      },
      content: json['content'] as String?,
      imagePath: json['imagePath'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      readAt: json['readAt'] as String?,
    );
  }
}

int _readId(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime _parseDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
}
