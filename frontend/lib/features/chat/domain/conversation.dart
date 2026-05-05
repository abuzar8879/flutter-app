class Conversation {
  const Conversation({
    required this.id,
    required this.userOneId,
    required this.userTwoId,
  });

  final String id;
  final String userOneId;
  final String userTwoId;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: (json['id'] ?? '').toString(),
      userOneId: (json['userOneId'] ?? '').toString(),
      userTwoId: (json['userTwoId'] ?? '').toString(),
    );
  }
}
