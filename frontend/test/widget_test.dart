import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/app/app.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/auth/domain/auth_session.dart';
import 'package:frontend/features/auth/domain/auth_user.dart';
import 'package:frontend/features/auth/presentation/providers/auth_controller.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.restoredUser});

  final AuthUser? restoredUser;

  @override
  Future<AuthUser> fetchCurrentUser(String token) async {
    if (restoredUser == null) {
      throw Exception('No session');
    }
    return restoredUser!;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return AuthSession(
      token: 'login-token',
      user: AuthUser(id: 1, name: 'Login User', email: email),
    );
  }

  @override
  Future<AuthSession> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    return AuthSession(
      token: 'signup-token',
      user: AuthUser(id: 2, name: name, email: email),
    );
  }
}

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage(this._token);

  String? _token;

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }
}

void main() {
  testWidgets('shows login screen when no stored session exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeAuthRepository()),
          tokenStorageProvider.overrideWith((ref) => FakeTokenStorage(null)),
        ],
        child: const ChatApp(),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Phase 2 Authentication'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });

  testWidgets('restores stored session and opens home screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith(
            (ref) => FakeAuthRepository(
              restoredUser: const AuthUser(
                id: 7,
                name: 'Stored User',
                email: 'stored@example.com',
              ),
            ),
          ),
          tokenStorageProvider.overrideWith(
            (ref) => FakeTokenStorage('stored-token'),
          ),
        ],
        child: const ChatApp(),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Rabta'), findsOneWidget);
    expect(find.text('Stored User'), findsOneWidget);
    expect(find.text('stored@example.com'), findsOneWidget);
    expect(find.text('Open conversations'), findsOneWidget);
  });
}
