import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../chat/data/chat_socket_service.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../domain/group_message.dart';
import 'groups_providers.dart';

class GroupChatState {
  const GroupChatState({
    this.messages = const [],
    this.isLoading = true,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.typingUserIds = const {},
    this.error,
  });

  final List<GroupMessage> messages;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool isSending;
  final Set<String> typingUserIds;
  final String? error;

  GroupChatState copyWith({
    List<GroupMessage>? messages,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? isSending,
    Set<String>? typingUserIds,
    String? error,
  }) {
    return GroupChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isSending: isSending ?? this.isSending,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      error: error,
    );
  }
}

final groupChatControllerProvider = NotifierProvider.autoDispose
    .family<GroupChatController, GroupChatState, String>(
      GroupChatController.new,
    );

class GroupChatController extends Notifier<GroupChatState> {
  GroupChatController(this.groupId);

  final String groupId;
  Timer? _typingTimer;
  bool _loading = false;
  bool _loadScheduled = false;
  bool _loaded = false;
  ChatSocketService? _socket;
  bool _socketListenersAttached = false;

  @override
  GroupChatState build() {
    ref.onDispose(() {
      _typingTimer?.cancel();
      _attachSocket(null);
    });

    ref.listen(authControllerProvider, (_, next) {
      if (next.session == null) return;
      _ensureLoaded();
    });

    ref.listen(chatSocketServiceProvider, (_, next) {
      _attachSocket(next);
    });

    _ensureLoaded();
    return const GroupChatState();
  }

  void _attachSocket(ChatSocketService? socket) {
    if (_socket != socket || socket == null) {
      _socket?.removeGroupMessageListener(_onGroupMessage);
      _socket?.removeGroupMessageUpdatedListener(_onGroupMessageUpdated);
      _socket?.removeGroupTypingListener(_onGroupTyping);
      _socket?.removeGroupStopTypingListener(_onGroupStopTyping);
      _socketListenersAttached = false;
    }

    _socket = socket;
    if (_socket == null || !_loaded || _socketListenersAttached) return;

    _socket?.addGroupMessageListener(_onGroupMessage);
    _socket?.addGroupMessageUpdatedListener(_onGroupMessageUpdated);
    _socket?.addGroupTypingListener(_onGroupTyping);
    _socket?.addGroupStopTypingListener(_onGroupStopTyping);
    unawaited(_socket!.joinGroup(groupId));
    _socketListenersAttached = true;
  }

  void _ensureLoaded() {
    if (_loadScheduled || _loading) return;
    _loadScheduled = true;
    Future.microtask(() async {
      _loadScheduled = false;
      await _load();
    });
  }

  Future<void> _load() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    if (_loading) return;
    _loading = true;

    try {
      _loaded = true;
      _attachSocket(ref.read(chatSocketServiceProvider));

      final repo = ref.read(groupsRepositoryProvider);
      final messages = await repo.fetchMessages(
        token: session.token,
        groupId: groupId,
      );

      state = state.copyWith(messages: List.of(messages), isLoading: false);
      await _markLatestAsRead();
      ref.invalidate(groupListProvider);
    } catch (error) {
      state = state.copyWith(error: error.toString(), isLoading: false);
    } finally {
      _loading = false;
    }
  }

  void _onGroupMessage(GroupMessage message) {
    if (message.groupId != groupId) return;
    if (state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);

    _markLatestAsRead();
    ref.invalidate(groupListProvider);
  }

  void _onGroupMessageUpdated(GroupMessage message) {
    if (message.groupId != groupId) return;
    final next = [...state.messages];
    final index = next.indexWhere((m) => m.id == message.id);
    if (index == -1) return;
    next[index] = message;
    state = state.copyWith(messages: next);
    ref.invalidate(groupListProvider);
  }

  void _onGroupTyping(String userId, String gId) {
    if (gId != groupId) return;
    final currentUserId = ref.read(authControllerProvider).session?.user.id;
    if (currentUserId != null && userId == currentUserId) return;
    final next = Set<String>.from(state.typingUserIds)..add(userId);
    state = state.copyWith(typingUserIds: next);
  }

  void _onGroupStopTyping(String userId, String gId) {
    if (gId != groupId) return;
    final currentUserId = ref.read(authControllerProvider).session?.user.id;
    if (currentUserId != null && userId == currentUserId) return;
    final next = Set<String>.from(state.typingUserIds)..remove(userId);
    state = state.copyWith(typingUserIds: next);
  }

  void onMessageChanged() {
    ref.read(chatSocketServiceProvider)?.sendGroupTyping(groupId);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      ref.read(chatSocketServiceProvider)?.sendGroupStopTyping(groupId);
    });
  }

  void setSending(bool isSending) {
    state = state.copyWith(isSending: isSending);
  }

  void addLocalMessage(GroupMessage message) {
    if (state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);
    ref.invalidate(groupListProvider);
  }

  Future<GroupMessage?> deleteMessage(String messageId) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return null;

    final socket = ref.read(chatSocketServiceProvider);
    var message = await socket?.deleteGroupMessage(
      groupId: groupId,
      messageId: messageId,
    );
    message ??= await ref
        .read(groupsRepositoryProvider)
        .deleteMessage(
          token: session.token,
          groupId: groupId,
          messageId: messageId,
        );
    _onGroupMessageUpdated(message);
    return message;
  }

  Future<void> _markLatestAsRead() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || state.messages.isEmpty) return;

    final latest = state.messages.last;
    if (latest.senderId == session.user.id) return;

    ref.read(chatSocketServiceProvider)?.sendMarkGroupRead(groupId, latest.id);
    await ref
        .read(groupsRepositoryProvider)
        .markRead(
          token: session.token,
          groupId: groupId,
          lastReadMessageId: latest.id,
        );
    ref.invalidate(groupListProvider);
  }
}
