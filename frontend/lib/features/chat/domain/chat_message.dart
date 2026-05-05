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

  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
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
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      receiverId: (json['receiverId'] ?? '').toString(),
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

DateTime _parseDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
}
