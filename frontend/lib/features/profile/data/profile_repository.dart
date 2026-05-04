import 'dart:typed_data';

import '../domain/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> fetchMyProfile(String token);
  Future<UserProfile> updateMyProfile({
    required String token,
    required String name,
  });
  Future<UserProfile> uploadMyAvatar({
    required String token,
    required String fileName,
    required Uint8List bytes,
  });
}
