import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../domain/group_message.dart';
import '../domain/group_member.dart';
import '../domain/group_summary.dart';

class GroupsRepository {
  const GroupsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<GroupSummary> createGroup({
    required String token,
    String? name,
    required List<int> inviteeIds,
  }) async {
    final json = await _apiClient.postJson(
      '/api/groups',
      token: token,
      body: {'name': name, 'inviteeIds': inviteeIds},
    );
    return GroupSummary.fromJson(json['group'] as Map<String, dynamic>);
  }

  Future<List<GroupSummary>> listGroups({
    required String token,
    int limit = 30,
    int offset = 0,
  }) async {
    final json = await _apiClient.getJson(
      '/api/groups?limit=$limit&offset=$offset',
      token: token,
    );
    final list = json['groups'] as List<dynamic>? ?? [];
    return list
        .map((e) => GroupSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GroupInvite>> listInvites({required String token}) async {
    final json = await _apiClient.getJson('/api/groups/invites', token: token);
    final list = json['invites'] as List<dynamic>? ?? [];
    return list.map((e) => GroupInvite.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> acceptInvite({required String token, required int groupId}) async {
    await _apiClient.postJson('/api/groups/$groupId/invites/accept', token: token);
  }

  Future<void> rejectInvite({required String token, required int groupId}) async {
    await _apiClient.postJson('/api/groups/$groupId/invites/reject', token: token);
  }

  Future<List<GroupMessage>> fetchMessages({
    required String token,
    required int groupId,
    int limit = 50,
    int? beforeId,
  }) async {
    final beforeQuery = beforeId == null ? '' : '&beforeId=$beforeId';
    final json = await _apiClient.getJson(
      '/api/groups/$groupId/messages?limit=$limit$beforeQuery',
      token: token,
    );
    final list = json['messages'] as List<dynamic>? ?? [];
    return list
        .map((e) => GroupMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GroupMember>> listMembers({
    required String token,
    required int groupId,
  }) async {
    final json = await _apiClient.getJson('/api/groups/$groupId/members', token: token);
    final list = json['members'] as List<dynamic>? ?? [];
    return list.map((e) => GroupMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> inviteMembers({
    required String token,
    required int groupId,
    required List<int> inviteeIds,
  }) async {
    await _apiClient.postJson(
      '/api/groups/$groupId/invites',
      token: token,
      body: {'inviteeIds': inviteeIds},
    );
  }

  Future<void> removeMember({
    required String token,
    required int groupId,
    required int userId,
  }) async {
    await _apiClient.deleteJson('/api/groups/$groupId/members/$userId', token: token);
  }

  Future<GroupMessage> sendMessage({
    required String token,
    required int groupId,
    required String type,
    String? content,
    String? imagePath,
  }) async {
    final json = await _apiClient.postJson(
      '/api/groups/$groupId/messages',
      token: token,
      body: {'type': type, 'content': content, 'imagePath': imagePath},
    );
    return GroupMessage.fromJson(json['message'] as Map<String, dynamic>);
  }

  Future<void> markRead({
    required String token,
    required int groupId,
    required int lastReadMessageId,
  }) async {
    await _apiClient.patchJson(
      '/api/groups/$groupId/read',
      token: token,
      body: {'lastReadMessageId': lastReadMessageId},
    );
  }

  Future<String> uploadImage({
    required String token,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final json = await _apiClient.postMultipartBytes(
      '/api/groups/images',
      token: token,
      fieldName: 'image',
      fileName: fileName,
      bytes: bytes,
    );
    return json['imagePath'] as String? ?? '';
  }
}

