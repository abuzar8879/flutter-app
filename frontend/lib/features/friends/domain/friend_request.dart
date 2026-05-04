import '../../users/domain/app_user.dart';

enum FriendRequestStatus { pending, accepted, rejected }

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.sender,
  });

  final int id;
  final int senderId;
  final int receiverId;
  final FriendRequestStatus status;
  final String createdAt;
  final AppUser? sender;

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String? ?? 'pending';
    final status = switch (rawStatus) {
      'accepted' => FriendRequestStatus.accepted,
      'rejected' => FriendRequestStatus.rejected,
      _ => FriendRequestStatus.pending,
    };

    AppUser? sender;
    final senderJson = json['sender'];
    if (senderJson is Map<String, dynamic>) {
      sender = AppUser.fromJson(senderJson);
    }

    return FriendRequest(
      id: _readId(json['id']),
      senderId: _readId(json['senderId']),
      receiverId: _readId(json['receiverId']),
      status: status,
      createdAt: json['createdAt'] as String? ?? '',
      sender: sender,
    );
  }
}

int _readId(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
