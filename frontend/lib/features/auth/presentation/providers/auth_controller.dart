import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/api_auth_repository.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_session.dart';
import '../../domain/auth_state.dart';
import '../../domain/auth_user.dart';

enum AuthMode { login, signup }

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiAuthRepository(apiClient);
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return SecureTokenStorage();
});

final authModeProvider = NotifierProvider<AuthModeController, AuthMode>(
  AuthModeController.new,
);

class AuthModeController extends Notifier<AuthMode> {
  @override
  AuthMode build() => AuthMode.login;

  void setMode(AuthMode mode) {
    state = mode;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(restoreSession);
    return const AuthState.initial();
  }

  Future<void> restoreSession() async {
    if (state.initialized && state.session != null) {
      return;
    }

    state = AuthState(
      initialized: false,
      isLoading: true,
      session: state.session,
      errorMessage: null,
    );

    final tokenStorage = ref.read(tokenStorageProvider);
    final authRepository = ref.read(authRepositoryProvider);
    final token = await tokenStorage.readToken();

    if (token == null || token.isEmpty) {
      state = const AuthState(
        initialized: true,
        isLoading: false,
        session: null,
        errorMessage: null,
      );
      return;
    }

    try {
      final user = await authRepository.fetchCurrentUser(token);
      state = AuthState(
        initialized: true,
        isLoading: false,
        session: AuthSession(token: token, user: user),
        errorMessage: null,
      );
    } catch (_) {
      await tokenStorage.clearToken();
      state = const AuthState(
        initialized: true,
        isLoading: false,
        session: null,
        errorMessage: null,
      );
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = AuthState(
      initialized: state.initialized,
      isLoading: true,
      session: state.session,
      errorMessage: null,
    );

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(email: email.trim(), password: password);
      await ref.read(tokenStorageProvider).writeToken(session.token);
      state = AuthState(
        initialized: true,
        isLoading: false,
        session: session,
        errorMessage: null,
      );
      return true;
    } catch (error) {
      state = AuthState(
        initialized: true,
        isLoading: false,
        session: null,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    state = AuthState(
      initialized: state.initialized,
      isLoading: true,
      session: state.session,
      errorMessage: null,
    );

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .signup(name: name.trim(), email: email.trim(), password: password);
      await ref.read(tokenStorageProvider).writeToken(session.token);
      state = AuthState(
        initialized: true,
        isLoading: false,
        session: session,
        errorMessage: null,
      );
      return true;
    } catch (error) {
      state = AuthState(
        initialized: true,
        isLoading: false,
        session: null,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clearToken();
    state = const AuthState(
      initialized: true,
      isLoading: false,
      session: null,
      errorMessage: null,
    );
  }

  void updateCurrentUser(AuthUser user) {
    if (state.session == null) {
      return;
    }

    state = AuthState(
      initialized: state.initialized,
      isLoading: state.isLoading,
      session: AuthSession(token: state.session!.token, user: user),
      errorMessage: state.errorMessage,
    );
  }

  void clearError() {
    state = AuthState(
      initialized: state.initialized,
      isLoading: state.isLoading,
      session: state.session,
      errorMessage: null,
    );
  }
}
