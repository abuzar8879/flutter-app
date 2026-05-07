// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'token_storage.dart';

class WebSessionTokenStorage implements TokenStorage {
  static const _tokenKey = 'auth_token';

  @override
  Future<void> clearToken() async {
    html.window.sessionStorage.remove(_tokenKey);
  }

  @override
  Future<String?> readToken() async {
    return html.window.sessionStorage[_tokenKey];
  }

  @override
  Future<void> writeToken(String token) async {
    html.window.sessionStorage[_tokenKey] = token;
  }
}

TokenStorage? createPlatformTokenStorage() => WebSessionTokenStorage();
