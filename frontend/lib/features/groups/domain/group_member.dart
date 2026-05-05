import '../../users/domain/app_user.dart';

class GroupMember {
  const GroupMember({
    required this.groupId,
    required this.userId,
    required this.role,
    required this.status,
    this.user,
  });

  final String groupId;
  final String userId;
  final String role; // admin | member
  final String status; // invited | accepted
  final AppUser? user;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      groupId: _readId(json['groupId']),
      userId: _readId(json['userId']),
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'invited',
      user: json['user'] is Map<String, dynamic>
          ? AppUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

String _readId(Object? value) {
  if (value == null) return '';
  return value.toString();
}

