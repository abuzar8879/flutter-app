class StatusStory {
  const StatusStory({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  bool get isActive => DateTime.now().difference(createdAt) < statusLifetime;

  factory StatusStory.fromJson(Map<String, dynamic> json) {
    return StatusStory(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userName: json['userName'] as String? ?? 'Unknown user',
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

const statusLifetime = Duration(hours: 24);

class StatusStoryGroup {
  const StatusStoryGroup({
    required this.userId,
    required this.userName,
    required this.stories,
  });

  final String userId;
  final String userName;
  final List<StatusStory> stories;

  StatusStory get latest => stories.first;
}
