import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

abstract class AuthRepository {
  Future<AuthSession> signup({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<AuthUser> fetchCurrentUser(String token);
}
