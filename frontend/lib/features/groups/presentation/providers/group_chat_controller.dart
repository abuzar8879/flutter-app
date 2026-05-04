import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
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
  final Set<int> typingUserIds;
  final String? error;

  GroupChatState copyWith({
    List<GroupMessage>? messages,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? isSending,
    Set<int>? typingUserIds,
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

final groupChatControllerProvider =
    NotifierProvider.autoDispose.family<GroupChatController, GroupChatState, int>(
  GroupChatController.new,
);

class GroupChatController extends Notifier<GroupChatState> {
  GroupChatController(this.groupId);

  final int groupId;
  Timer? _typingTimer;
  bool _loading = false;
  bool _loadScheduled = false;
  bool _startedListeners = false;

  @override
  GroupChatState build() {
    ref.onDispose(() {
      _typingTimer?.cancel();
      final socket = ref.read(chatSocketServiceProvider);
      socket?.removeGroupMessageListener(_onGroupMessage);
      socket?.removeGroupTypingListener(_onGroupTyping);
      socket?.removeGroupStopTypingListener(_onGroupStopTyping);
    });

    ref.listen(authControllerProvider, (_, next) {
      if (next.session == null) return;
      _ensureLoaded();
    });

    _ensureLoaded();
    return const GroupChatState();
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
      if (!_startedListeners) {
        _startedListeners = true;
        final socket = ref.read(chatSocketServiceProvider);
        socket?.addGroupMessageListener(_onGroupMessage);
        socket?.addGroupTypingListener(_onGroupTyping);
        socket?.addGroupStopTypingListener(_onGroupStopTyping);
        // Join early so realtime events aren't missed while initial fetch runs.
        await socket?.joinGroup(groupId);
      }

      final repo = ref.read(groupsRepositoryProvider);
      final messages = await repo.fetchMessages(token: session.token, groupId: groupId);

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

  void _onGroupTyping(int userId, int gId) {
    if (gId != groupId) return;
    final currentUserId = ref.read(authControllerProvider).session?.user.id;
    if (currentUserId != null && userId == currentUserId) return;
    final next = Set<int>.from(state.typingUserIds)..add(userId);
    state = state.copyWith(typingUserIds: next);
  }

  void _onGroupStopTyping(int userId, int gId) {
    if (gId != groupId) return;
    final currentUserId = ref.read(authControllerProvider).session?.user.id;
    if (currentUserId != null && userId == currentUserId) return;
    final next = Set<int>.from(state.typingUserIds)..remove(userId);
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

  Future<void> _markLatestAsRead() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || state.messages.isEmpty) return;

    final latest = state.messages.last;
    if (latest.senderId == session.user.id) return;

    ref.read(chatSocketServiceProvider)?.sendMarkGroupRead(groupId, latest.id);
    await ref.read(groupsRepositoryProvider).markRead(
          token: session.token,
          groupId: groupId,
          lastReadMessageId: latest.id,
        );
    ref.invalidate(groupListProvider);
  }
}

