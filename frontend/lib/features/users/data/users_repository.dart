import '../../../core/network/api_client.dart';
import '../domain/app_user.dart';

class UsersRepository {
  const UsersRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppUser>> fetchAllUsers({
    required String token,
    String search = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String>[
      'limit=$limit',
      'offset=$offset',
      if (search.isNotEmpty) 'search=${Uri.encodeQueryComponent(search)}',
    ].join('&');
    final path = '/api/users?$query';
    final json = await _apiClient.getJson(path, token: token);
    final list = json['users'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppUser> updatePublicKey({
    required String token,
    required String publicKey,
  }) async {
    final json = await _apiClient.patchJson(
      '/api/users/me/public-key',
      token: token,
      body: {'publicKey': publicKey},
    );
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
  }
}
