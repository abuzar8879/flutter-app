import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/groups/domain/group_summary.dart';
import '../../features/groups/presentation/screens/group_chat_screen.dart';
import '../../features/users/domain/app_user.dart';
import '../navigation/app_navigator.dart';
import '../network/api_client.dart';
import '../providers/api_client_provider.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(apiClientProvider));
});

class PushNotificationService {
  PushNotificationService(this._apiClient);

  final ApiClient _apiClient;
  bool _initialized = false;
  String? _sessionToken;

  Future<void> initialize(String sessionToken) async {
    try {
      // NOTE: You must have initialized Firebase in main.dart:
      // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      
      _sessionToken = sessionToken;
      final messaging = FirebaseMessaging.instance;

      if (!_initialized) {
        await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      }

      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token, sessionToken);
      }

      if (_initialized) return;
      _initialized = true;

      messaging.onTokenRefresh.listen((newToken) {
        final currentToken = _sessionToken;
        if (currentToken == null || currentToken.isEmpty) return;
        _registerToken(newToken, currentToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Foreground handling can be enhanced with local notifications later.
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      // FCM not configured or failed
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final targetType = data['targetType'] ?? data['chatType'] ?? '';
    if (targetType == 'private') {
      _openPrivateChat(data);
      return;
    }
    if (targetType == 'group') {
      _openGroupChat(data);
    }
  }

  void _openPrivateChat(Map<String, dynamic> data) {
    final friendId =
        (data['friendId'] ?? data['senderId'] ?? '').toString().trim();
    if (friendId.isEmpty) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final friend = AppUser(
      id: friendId,
      name: (data['friendName'] ?? data['senderName'] ?? 'Chat').toString(),
      email: (data['friendEmail'] ?? '').toString(),
      avatarPath: (data['friendAvatarPath'] ?? '').toString().isEmpty
          ? null
          : (data['friendAvatarPath'] ?? '').toString(),
      publicKey: (data['friendPublicKey'] ?? '').toString().isEmpty
          ? null
          : (data['friendPublicKey'] ?? '').toString(),
    );

    navigator.push(
      MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
    );
  }

  void _openGroupChat(Map<String, dynamic> data) {
    final groupId = (data['groupId'] ?? '').toString().trim();
    if (groupId.isEmpty) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final group = GroupSummary(
      id: groupId,
      name: (data['groupName'] ?? 'Group').toString(),
      createdBy: (data['groupCreatedBy'] ?? '').toString(),
      updatedAt: '',
      unreadCount: 0,
      memberCount: 0,
    );

    navigator.push(
      MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
    );
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
