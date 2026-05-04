import 'auth_session.dart';

class AuthState {
  const AuthState({
    required this.initialized,
    required this.isLoading,
    required this.session,
    required this.errorMessage,
  });

  const AuthState.initial()
    : initialized = false,
      isLoading = true,
      session = null,
      errorMessage = null;

  final bool initialized;
  final bool isLoading;
  final AuthSession? session;
  final String? errorMessage;

  bool get isAuthenticated => session != null;
}
