import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/chat_message.dart';
import 'chat_providers.dart';
import 'conversation_list_provider.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.conversationId,
    this.isLoading = true,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.isFriendOnline = false,
    this.isFriendTyping = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final int? conversationId;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool isSending;
  final bool isFriendOnline;
  final bool isFriendTyping;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    int? conversationId,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? isSending,
    bool? isFriendOnline,
    bool? isFriendTyping,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isSending: isSending ?? this.isSending,
      isFriendOnline: isFriendOnline ?? this.isFriendOnline,
      isFriendTyping: isFriendTyping ?? this.isFriendTyping,
      error: error,
    );
  }
}

final chatControllerProvider =
    NotifierProvider.autoDispose.family<ChatController, ChatState, int>(
  ChatController.new,
);

class ChatController extends Notifier<ChatState> {
  ChatController(this.friendId);

  final int friendId;
  Timer? _typingTimer;
  bool _loadScheduled = false;
  bool _loading = false;
  int? _loadedConversationId;

  @override
  ChatState build() {
    ref.onDispose(() {
      _typingTimer?.cancel();
      final socket = ref.read(chatSocketServiceProvider);
      socket?.removeMessageListener(_handleSocketMessage);
      socket?.removeOnlineListener(_handleOnlineUsers);
      socket?.removeTypingListener(_handleTyping);
      socket?.removeStopTypingListener(_handleStopTyping);
      socket?.removeMessagesReadListener(_handleMessagesRead);
    });

    // If the screen is opened before the auth session is restored, `_loadChat`
    // may return early. We must retry once the session becomes available;
    // otherwise this tab never subscribes to socket events and incoming
    // messages/typing will only appear after re-opening (API refetch).
    ref.listen(authControllerProvider, (_, next) {
      if (next.session == null) return;
      _ensureLoaded();
    });

    _ensureLoaded();
    return const ChatState();
  }

  void _ensureLoaded() {
    if (_loadScheduled || _loading) return;
    // IMPORTANT: Don't read `state` here; `build()` runs before the first state
    // is initialized, and accessing `state` would throw.
    if (_loadedConversationId != null) return;

    _loadScheduled = true;
    Future.microtask(() async {
      _loadScheduled = false;
      await _loadChat();
    });
  }

  Future<void> _loadChat() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    if (_loading) return;
    _loading = true;

    try {
      final repository = ref.read(chatRepositoryProvider);
      final conversation = await repository.getOrCreateConversation(
        token: session.token,
        friendId: friendId,
      );
      final messages = await repository.fetchMessages(
        token: session.token,
        conversationId: conversation.id,
      );
      await repository.markConversationRead(
        token: session.token,
        conversationId: conversation.id,
      );

      final socket = ref.read(chatSocketServiceProvider);
      socket?.sendMarkRead(friendId, conversation.id);

      state = state.copyWith(
        conversationId: conversation.id,
        messages: List.from(messages),
        isLoading: false,
      );
      _loadedConversationId = conversation.id;

      socket?.addMessageListener(_handleSocketMessage);
      socket?.addOnlineListener(_handleOnlineUsers);
      socket?.addTypingListener(_handleTyping);
      socket?.addStopTypingListener(_handleStopTyping);
      socket?.addMessagesReadListener(_handleMessagesRead);

      ref.invalidate(conversationListProvider);
    } catch (error) {
      state = state.copyWith(
        error: error.toString(),
        isLoading: false,
      );
    } finally {
      _loading = false;
    }
  }

  void _handleSocketMessage(ChatMessage message) {
    if (state.conversationId != message.conversationId) return;
    if (state.messages.any((item) => item.id == message.id)) return;

    state = state.copyWith(messages: [...state.messages, message]);
    _markRead();
  }

  Future<void> _markRead() async {
    final session = ref.read(authControllerProvider).session;
    final conversationId = state.conversationId;
    if (session == null || conversationId == null) return;

    final socket = ref.read(chatSocketServiceProvider);
    socket?.sendMarkRead(friendId, conversationId);

    await ref.read(chatRepositoryProvider).markConversationRead(
          token: session.token,
          conversationId: conversationId,
        );
    ref.invalidate(conversationListProvider);
  }

  Future<void> loadOlderMessages() async {
    final session = ref.read(authControllerProvider).session;
    final conversationId = state.conversationId;
    if (session == null ||
        conversationId == null ||
        state.messages.isEmpty ||
        state.isLoadingOlder) {
      return;
    }

    state = state.copyWith(isLoadingOlder: true);

    try {
      final olderMessages = await ref.read(chatRepositoryProvider).fetchMessages(
            token: session.token,
            conversationId: conversationId,
            beforeId: state.messages.first.id,
          );
      state = state.copyWith(
        messages: [...olderMessages, ...state.messages],
        isLoadingOlder: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingOlder: false);
    }
  }

  void _handleOnlineUsers(Set<int> userIds) {
    state = state.copyWith(isFriendOnline: userIds.contains(friendId));
  }

  void _handleTyping(int userId, int conversationId) {
    if (userId == friendId && conversationId == state.conversationId) {
      state = state.copyWith(isFriendTyping: true);
    }
  }

  void _handleStopTyping(int userId, int conversationId) {
    if (userId == friendId && conversationId == state.conversationId) {
      state = state.copyWith(isFriendTyping: false);
    }
  }

  void _handleMessagesRead(int conversationId, int readerId) {
    if (conversationId != state.conversationId || readerId != friendId) return;

    final nowStr = DateTime.now().toIso8601String();
    final updatedMessages = state.messages.map((m) {
      if (m.senderId != friendId && m.readAt == null) {
        return ChatMessage(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          receiverId: m.receiverId,
          type: m.type,
          createdAt: m.createdAt,
          content: m.content,
          imagePath: m.imagePath,
          readAt: nowStr,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updatedMessages);
  }

  void onMessageChanged() {
    if (state.conversationId == null) return;
    final socket = ref.read(chatSocketServiceProvider);
    socket?.sendTyping(friendId, state.conversationId!);

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      socket?.sendStopTyping(friendId, state.conversationId!);
    });
  }

  void addLocalMessage(ChatMessage message) {
    if (state.messages.any((item) => item.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void setSending(bool isSending) {
    state = state.copyWith(isSending: isSending);
  }
}
