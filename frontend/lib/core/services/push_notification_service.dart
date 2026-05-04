import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../providers/api_client_provider.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(apiClientProvider));
});

class PushNotificationService {
  PushNotificationService(this._apiClient);

  final ApiClient _apiClient;

  Future<void> initialize(String sessionToken) async {
    try {
      // NOTE: You must have initialized Firebase in main.dart:
      // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      
      final messaging = FirebaseMessaging.instance;

      // Request permission
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Get the token
      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token, sessionToken);
      }

      // Listen to token updates
      messaging.onTokenRefresh.listen((newToken) {
        _registerToken(newToken, sessionToken);
      });

      // Background messages are handled by FirebaseMessaging.onBackgroundMessage
      // Foreground messages:
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // You could show a local notification here if needed
      });
    } catch (e) {
      // FCM not configured or failed
    }
  }

  Future<void> _registerToken(String token, String sessionToken) async {
    try {
      await _apiClient.patchJson(
        '/users/me/fcm-token',
        body: {'fcmToken': token},
        token: sessionToken,
      );
    } catch (e) {
      // Ignore API errors if not logged in yet
    }
  }
}
