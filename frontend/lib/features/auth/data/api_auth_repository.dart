import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AuthUser> fetchCurrentUser(String token) async {
    final json = await _apiClient.getJson('/api/auth/me', token: token);
    return AuthUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.postJson(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );

    return AuthSession(
      token: json['token'] as String? ?? '',
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<AuthSession> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.postJson(
      '/api/auth/signup',
      body: {'name': name, 'email': email, 'password': password},
    );

    return AuthSession(
      token: json['token'] as String? ?? '',
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
