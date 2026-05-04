import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/conversation_summary.dart';
import 'chat_providers.dart';

final conversationListProvider = FutureProvider<List<ConversationSummary>>((
  ref,
) async {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) throw Exception('Not authenticated');
  ref.watch(encryptionBootstrapProvider);

  return ref
      .read(chatRepositoryProvider)
      .fetchConversations(token: session.token);
});
