class Conversation {
  const Conversation({
    required this.id,
    required this.userOneId,
    required this.userTwoId,
  });

  final int id;
  final int userOneId;
  final int userTwoId;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: _readId(json['id']),
      userOneId: _readId(json['userOneId']),
      userTwoId: _readId(json['userTwoId']),
    );
  }
}

int _readId(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
