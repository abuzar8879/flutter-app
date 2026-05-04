import '../../users/domain/app_user.dart';

class GroupMember {
  const GroupMember({
    required this.groupId,
    required this.userId,
    required this.role,
    required this.status,
    this.user,
  });

  final int groupId;
  final int userId;
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

int _readId(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

