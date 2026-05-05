import '../../../core/network/api_client.dart';
import '../../users/domain/app_user.dart';
import '../domain/friend_request.dart';

class FriendsRepository {
  const FriendsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<FriendRequest> sendRequest({
    required String token,
    required String receiverId,
  }) async {
    final json = await _apiClient.postJson(
      '/api/friends/requests',
      token: token,
      body: {'receiverId': receiverId},
    );
    return FriendRequest.fromJson(json['request'] as Map<String, dynamic>);
  }

  Future<FriendRequest> respondToRequest({
    required String token,
    required String requestId,
    required String action, // 'accepted' | 'rejected'
  }) async {
    final json = await _apiClient.patchJson(
      '/api/friends/requests/$requestId',
      token: token,
      body: {'action': action},
    );
    return FriendRequest.fromJson(json['request'] as Map<String, dynamic>);
  }

  Future<List<FriendRequest>> fetchPendingRequests({
    required String token,
  }) async {
    final json = await _apiClient.getJson(
      '/api/friends/requests/pending',
      token: token,
    );
    final list = json['requests'] as List<dynamic>? ?? [];
    return list
        .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppUser>> fetchMyFriends({required String token}) async {
    final json = await _apiClient.getJson('/api/friends', token: token);
    final list = json['friends'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
