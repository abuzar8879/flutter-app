import 'secure_token_storage.dart';
import 'token_storage.dart';
import 'web_session_token_storage_stub.dart'
    if (dart.library.html) 'web_session_token_storage.dart';

TokenStorage createTokenStorage() {
  return createPlatformTokenStorage() ?? SecureTokenStorage();
}
