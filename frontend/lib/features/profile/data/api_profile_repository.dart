import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../domain/user_profile.dart';
import 'profile_repository.dart';

class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<UserProfile> fetchMyProfile(String token) async {
    final json = await _apiClient.getJson('/api/profile/me', token: token);
    return UserProfile.fromJson(json['profile'] as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> updateMyProfile({
    required String token,
    required String name,
  }) async {
    final json = await _apiClient.patchJson(
      '/api/profile/me',
      token: token,
      body: {'name': name},
    );
    return UserProfile.fromJson(json['profile'] as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> uploadMyAvatar({
    required String token,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final json = await _apiClient.postMultipartBytes(
      '/api/profile/me/avatar',
      token: token,
      fieldName: 'avatar',
      fileName: fileName,
      bytes: bytes,
    );
    return UserProfile.fromJson(json['profile'] as Map<String, dynamic>);
  }
}
