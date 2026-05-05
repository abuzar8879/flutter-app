import '../../../core/config/app_config.dart';

enum GroupMessageType { text, image, encrypted }

class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.content,
    this.imagePath,
  });

  final String id;
  final String groupId;
  final String senderId;
  final GroupMessageType type;
  final String createdAt;
  final String? content;
  final String? imagePath;

  DateTime get createdAtDate => _parseDateTime(createdAt);

  String? get imageUrl => imagePath == null || imagePath!.isEmpty
      ? null
      : '${AppConfig.apiBaseUrl}$imagePath';

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      id: _readId(json['id']),
      groupId: _readId(json['groupId']),
      senderId: _readId(json['senderId']),
      type: switch (json['type']) {
        'image' => GroupMessageType.image,
        'encrypted' => GroupMessageType.encrypted,
        _ => GroupMessageType.text,
      },
      content: json['content'] as String?,
      imagePath: json['imagePath'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

String _readId(Object? value) {
  if (value == null) return '';
  return value.toString();
}

DateTime _parseDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
}

