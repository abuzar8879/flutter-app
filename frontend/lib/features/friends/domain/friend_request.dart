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

  final String id;
  final String senderId;
  final String receiverId;
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
      id: (json['id'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      receiverId: (json['receiverId'] ?? '').toString(),
      status: status,
      createdAt: json['createdAt'] as String? ?? '',
      sender: sender,
    );
  }
}
