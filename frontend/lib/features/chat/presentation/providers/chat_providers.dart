import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../users/domain/app_user.dart';
import '../../../users/presentation/providers/users_providers.dart';
import '../../data/chat_repository.dart';
import '../../data/chat_socket_service.dart';
import '../../data/message_crypto_service.dart';
import '../../domain/chat_message.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});

final chatSocketServiceProvider = Provider<ChatSocketService?>((ref) {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) return null;

  final service = ChatSocketService(
    token: session.token,
    currentUserId: session.user.id,
  )..connect();
  ref.onDispose(service.dispose);
  return service;
});

final messageCryptoServiceProvider = Provider<MessageCryptoService>((ref) {
  return MessageCryptoService();
});

final encryptionBootstrapProvider = FutureProvider<void>((ref) async {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) return;

  final scopeKey = session.user.id.toString();
  final publicKey = await ref
      .read(messageCryptoServiceProvider)
      .getOrCreatePublicKey(scopeKey: scopeKey);
  if (session.user.publicKey == publicKey) return;

  final user = await ref
      .read(usersRepositoryProvider)
      .updatePublicKey(token: session.token, publicKey: publicKey);

  ref
      .read(authControllerProvider.notifier)
      .updateCurrentUser(
        AuthUser(
          id: user.id,
          name: user.name,
          email: user.email,
          avatarPath: user.avatarPath,
          publicKey: user.publicKey,
        ),
      );
});

class MessageDecryptionRequest {
  const MessageDecryptionRequest({required this.message, required this.friend});

  final ChatMessage message;
  final AppUser friend;

  @override
  bool operator ==(Object other) {
    return other is MessageDecryptionRequest &&
        other.message.id == message.id &&
        other.message.content == message.content &&
        other.message.deletedAt == message.deletedAt &&
        other.message.editedAt == message.editedAt &&
        other.friend.id == friend.id &&
        other.friend.publicKey == friend.publicKey;
  }

  @override
  int get hashCode {
    return Object.hash(
      message.id,
      message.content,
      message.deletedAt,
      message.editedAt,
      friend.id,
      friend.publicKey,
    );
  }
}

final messagePayloadProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, MessageDecryptionRequest>((
      ref,
      request,
    ) async {
      final content = request.message.content;
      if (request.message.type != ChatMessageType.encrypted ||
          content == null ||
          content.isEmpty) {
        return {
          'type': request.message.type.name,
          'content': request.message.content ?? '',
          'imagePath': request.message.imagePath,
          'audioPath': request.message.audioPath,
        };
      }

      final session = ref.watch(authControllerProvider).session;
      if (session == null) {
        throw StateError('Not authenticated.');
      }

      await ref.read(encryptionBootstrapProvider.future);
      final iAmSender = session.user.id == request.message.senderId;
      return ref
          .read(messageCryptoServiceProvider)
          .decryptPayload(
            encryptedPayload: content,
            iAmSender: iAmSender,
            scopeKey: session.user.id.toString(),
            friendFallbackPublicKey: request.friend.publicKey,
          );
    });

final messageDecryptorProvider = FutureProvider.autoDispose
    .family<String, MessageDecryptionRequest>((ref, request) async {
      final payload = await ref.watch(messagePayloadProvider(request).future);
      final type = payload['type'] as String? ?? 'text';
      if (type == 'image') return 'Photo';
      if (type == 'voice') return 'Voice message';
      return payload['content'] as String? ?? '';
    });
