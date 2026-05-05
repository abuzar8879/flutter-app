import '../../users/domain/app_user.dart';
import 'group_message.dart';

class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.updatedAt,
    required this.unreadCount,
    required this.memberCount,
    this.lastMessage,
  });

  final String id;
  final String name;
  final String createdBy;
  final String updatedAt;
  final int unreadCount;
  final int memberCount;
  final GroupMessage? lastMessage;

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    final lastMessageJson = json['lastMessage'];
    return GroupSummary(
      id: _readId(json['id']),
      name: json['name'] as String? ?? '',
      createdBy: _readId(json['createdBy']),
      updatedAt: json['updatedAt'] as String? ?? '',
      unreadCount: json['unreadCount'] is num ? (json['unreadCount'] as num).toInt() : 0,
      memberCount: json['memberCount'] is num ? (json['memberCount'] as num).toInt() : 0,
      lastMessage: lastMessageJson is Map<String, dynamic>
          ? GroupMessage.fromJson(lastMessageJson)
          : null,
    );
  }

  String get displayName => name.trim().isNotEmpty ? name.trim() : 'Group';
}

class GroupInvite {
  const GroupInvite({
    required this.groupId,
    required this.groupName,
    required this.invitedAt,
    required this.invitedBy,
  });

  final String groupId;
  final String groupName;
  final String invitedAt;
  final AppUser? invitedBy;

  factory GroupInvite.fromJson(Map<String, dynamic> json) {
    final group = json['group'] as Map<String, dynamic>? ?? const {};
    return GroupInvite(
      groupId: _readId(group['id']),
      groupName: group['name'] as String? ?? '',
      invitedAt: json['invitedAt'] as String? ?? '',
      invitedBy: json['invitedBy'] is Map<String, dynamic>
          ? AppUser.fromJson(json['invitedBy'] as Map<String, dynamic>)
          : null,
    );
  }
}

String _readId(Object? value) {
  if (value == null) return '';
  return value.toString();
}

