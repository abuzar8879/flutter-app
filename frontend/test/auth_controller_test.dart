import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/auth/domain/auth_session.dart';
import 'package:frontend/features/auth/domain/auth_user.dart';
import 'package:frontend/features/auth/presentation/providers/auth_controller.dart';

class MemoryTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<void> clearToken() async {
    token = null;
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async {
    token = value;
  }
}

class StubAuthRepository implements AuthRepository {
  @override
  Future<AuthUser> fetchCurrentUser(String token) async {
    return const AuthUser(id: 9, name: 'Restored User', email: 'restored@example.com');
  }

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    return AuthSession(
      token: 'token-123',
      user: AuthUser(id: 3, name: 'Tester', email: email),
    );
  }

  @override
  Future<AuthSession> signup({required String name, required String email, required String password}) async {
    return AuthSession(
      token: 'token-456',
      user: AuthUser(id: 4, name: name, email: email),
    );
  }
}

void main() {
  test('login stores token and authenticates session', () async {
    final tokenStorage = MemoryTokenStorage();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => StubAuthRepository()),
        tokenStorageProvider.overrideWith((ref) => tokenStorage),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.login(email: 'tester@example.com', password: 'secret123');

    final state = container.read(authControllerProvider);
    expect(state.isAuthenticated, isTrue);
    expect(tokenStorage.token, 'token-123');
    expect(state.session?.user.email, 'tester@example.com');
  });
}
