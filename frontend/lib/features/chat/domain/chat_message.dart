import '../../../core/config/app_config.dart';

enum ChatMessageType { text, image, encrypted, voice }

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
    this.audioPath,
    this.replyToMessageId,
    this.editedAt,
    this.deletedAt,
    this.reactions = const {},
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
  final String? audioPath;
  final String? replyToMessageId;
  final String? editedAt;
  final String? deletedAt;
  final Map<String, String> reactions;
  final String? readAt;

  DateTime get createdAtDate => _parseDateTime(createdAt);
  bool get isDeleted => deletedAt != null && deletedAt!.isNotEmpty;

  String? get imageUrl => imagePath == null || imagePath!.isEmpty
      ? null
      : '${AppConfig.apiBaseUrl}$imagePath';

  String? get audioUrl => audioPath == null || audioPath!.isEmpty
      ? null
      : '${AppConfig.apiBaseUrl}$audioPath';

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    ChatMessageType? type,
    String? createdAt,
    String? content,
    String? imagePath,
    String? audioPath,
    String? replyToMessageId,
    String? editedAt,
    String? deletedAt,
    Map<String, String>? reactions,
    String? readAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      audioPath: audioPath ?? this.audioPath,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      reactions: reactions ?? this.reactions,
      readAt: readAt ?? this.readAt,
    );
  }

  static Map<String, String> _readReactions(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, reaction) => MapEntry(key.toString(), reaction.toString()),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      receiverId: (json['receiverId'] ?? '').toString(),
      type: switch (json['type']) {
        'image' => ChatMessageType.image,
        'encrypted' => ChatMessageType.encrypted,
        'voice' => ChatMessageType.voice,
        _ => ChatMessageType.text,
      },
      content: json['content'] as String?,
      imagePath: json['imagePath'] as String?,
      audioPath: json['audioPath'] as String?,
      replyToMessageId: json['replyToMessageId']?.toString(),
      editedAt: json['editedAt'] as String?,
      deletedAt: json['deletedAt'] as String?,
      reactions: _readReactions(json['reactions']),
      createdAt: json['createdAt'] as String? ?? '',
      readAt: json['readAt'] as String?,
    );
  }
}

DateTime _parseDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
}
