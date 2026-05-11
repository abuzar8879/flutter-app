import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_mode_provider.dart';
import '../../data/chat_socket_service.dart';
import '../../domain/chat_message.dart';
import '../../domain/conversation_summary.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../groups/presentation/screens/group_invites_screen.dart';
import '../../../groups/presentation/screens/group_list_screen.dart';
import '../../../users/domain/app_user.dart';
import '../providers/chat_providers.dart';
import '../providers/conversation_list_provider.dart';
import 'chat_screen.dart';

enum _ChatMenuAction {
  blockContact,
  reportContact,
  spamFilter,
  disappearingMessages,
  themesAndWallpaper,
}

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  ChatSocketService? _socket;
  final _typingConversationIds = <String>{};
  final _typingTimers = <String, Timer>{};
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _blockedUserIds = <String>{};
  bool _isSearchMode = false;
  bool _spamFilterEnabled = false;
  String _searchQuery = '';
  Duration _disappearingAfter = Duration.zero;
  ChatWallpaperStyle _wallpaperStyle = ChatWallpaperStyle.plain;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _setSocket(ref.read(chatSocketServiceProvider));
    });
  }

  @override
  void dispose() {
    _setSocket(null);
    _searchController.dispose();
    _searchFocusNode.dispose();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _setSocket(ChatSocketService? socket) {
    if (_socket == socket) return;
    _socket?.removeMessageListener(_handleNewMessage);
    _socket?.removeTypingListener(_handleTyping);
    _socket?.removeStopTypingListener(_handleStopTyping);
    _socket = socket;
    _socket?.addMessageListener(_handleNewMessage);
    _socket?.addTypingListener(_handleTyping);
    _socket?.addStopTypingListener(_handleStopTyping);
  }

  void _handleNewMessage(ChatMessage message) {
    ref.invalidate(conversationListProvider);
  }

  void _handleTyping(String userId, String conversationId) {
    if (conversationId.isEmpty) return;
    _typingTimers[conversationId]?.cancel();
    _typingTimers[conversationId] = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _typingConversationIds.remove(conversationId));
      }
    });
    if (mounted) {
      setState(() => _typingConversationIds.add(conversationId));
    }
  }

  void _handleStopTyping(String userId, String conversationId) {
    _typingTimers.remove(conversationId)?.cancel();
    if (mounted) {
      setState(() => _typingConversationIds.remove(conversationId));
    }
  }

  void _toggleSearchMode() {
    if (_isSearchMode && _searchQuery.trim().isNotEmpty) {
      _clearSearch();
      _searchFocusNode.requestFocus();
      return;
    }
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    if (_isSearchMode) {
      Future.microtask(() => _searchFocusNode.requestFocus());
    } else {
      _searchFocusNode.unfocus();
    }
  }

  void _onSearchChanged(String value) {
    if (_searchQuery == value) return;
    setState(() => _searchQuery = value);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  List<ConversationSummary> _filteredConversations(
    List<ConversationSummary> items,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    return items.where((summary) {
      if (_blockedUserIds.contains(summary.friend.id)) return false;
      if (_spamFilterEnabled && _looksLikeSpam(summary.lastMessage)) {
        return false;
      }
      if (query.isEmpty) return true;

      final friendName = summary.friend.name.toLowerCase();
      final friendEmail = summary.friend.email.toLowerCase();
      final messageText = _searchablePreview(summary.lastMessage).toLowerCase();
      return friendName.contains(query) ||
          friendEmail.contains(query) ||
          messageText.contains(query);
    }).toList();
  }

  bool _looksLikeSpam(ChatMessage? message) {
    if (message == null ||
        message.content == null ||
        message.content!.isEmpty) {
      return false;
    }
    final text = message.content!.toLowerCase();
    const spamPatterns = [
      'free money',
      'winner',
      'lottery',
      'urgent transfer',
      'click this link',
      'bit.ly',
      'http://',
      'https://',
    ];
    return spamPatterns.any(text.contains);
  }

  String _searchablePreview(ChatMessage? message) {
    if (message == null) return '';
    if (message.type == ChatMessageType.image) return 'photo image';
    if (message.type == ChatMessageType.voice) return 'voice message';
    return message.content ?? '';
  }

  Future<void> _handleMenuAction(
    _ChatMenuAction action,
    List<ConversationSummary> items,
  ) async {
    switch (action) {
      case _ChatMenuAction.blockContact:
        await _showBlockContactSheet(items);
        break;
      case _ChatMenuAction.reportContact:
        await _showReportContactSheet(items);
        break;
      case _ChatMenuAction.spamFilter:
        setState(() => _spamFilterEnabled = !_spamFilterEnabled);
        _showSnack(
          _spamFilterEnabled ? 'Spam filter enabled' : 'Spam filter disabled',
        );
        break;
      case _ChatMenuAction.disappearingMessages:
        await _showDisappearingMessagesSheet();
        break;
      case _ChatMenuAction.themesAndWallpaper:
        await _showThemeAndWallpaperSheet();
        break;
    }
  }

  Future<void> _showBlockContactSheet(List<ConversationSummary> items) async {
    if (items.isEmpty) {
      _showSnack('No contacts available to block.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Block or unblock contacts',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              ...items.map((summary) {
                final isBlocked = _blockedUserIds.contains(summary.friend.id);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    child: Text(_initial(summary.friend.name)),
                  ),
                  title: Text(summary.friend.name),
                  subtitle: Text(
                    isBlocked ? 'Blocked' : 'Tap to block',
                    style: TextStyle(color: isBlocked ? Colors.red : null),
                  ),
                  trailing: Icon(
                    isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: isBlocked ? null : Colors.red,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      if (isBlocked) {
                        _blockedUserIds.remove(summary.friend.id);
                      } else {
                        _blockedUserIds.add(summary.friend.id);
                      }
                    });
                    _showSnack(
                      isBlocked
                          ? '${summary.friend.name} unblocked'
                          : '${summary.friend.name} blocked',
                    );
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReportContactSheet(List<ConversationSummary> items) async {
    if (items.isEmpty) {
      _showSnack('No contacts available to report.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Report contact',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              ...items.map((summary) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    child: Text(_initial(summary.friend.name)),
                  ),
                  title: Text(summary.friend.name),
                  subtitle: const Text('Tap to report'),
                  trailing: const Icon(Icons.flag_outlined),
                  onTap: () async {
                    Navigator.pop(context);
                    await _promptReportReason(summary.friend.name);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _promptReportReason(String friendName) async {
    final reasonController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Report $friendName'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Reason (spam, harassment, scam, etc.)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();
    if (submitted == true) {
      _showSnack('Report submitted for $friendName');
    }
  }

  Future<void> _showDisappearingMessagesSheet() async {
    const options = [
      _DisappearingOption('Off', Duration.zero),
      _DisappearingOption('24 hours', Duration(hours: 24)),
      _DisappearingOption('7 days', Duration(days: 7)),
      _DisappearingOption('30 days', Duration(days: 30)),
    ];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Disappearing messages',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              ...options.map((option) {
                final isSelected = option.value == _disappearingAfter;
                return ListTile(
                  title: Text(option.label),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _disappearingAfter = option.value);
                    _showSnack(
                      option.value == Duration.zero
                          ? 'Disappearing messages disabled'
                          : 'Messages disappear after ${option.label}',
                    );
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showThemeAndWallpaperSheet() async {
    var selectedTheme = ref.read(themeModeProvider);
    var selectedWallpaper = _wallpaperStyle;
    final themeController = ref.read(themeModeProvider.notifier);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Theme',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Light'),
                          selected: selectedTheme == ThemeMode.light,
                          onSelected: (_) {
                            themeController.setMode(ThemeMode.light);
                            setSheetState(
                              () => selectedTheme = ThemeMode.light,
                            );
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Dark'),
                          selected: selectedTheme == ThemeMode.dark,
                          onSelected: (_) {
                            themeController.setMode(ThemeMode.dark);
                            setSheetState(() => selectedTheme = ThemeMode.dark);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chat wallpaper',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Plain'),
                          selected:
                              selectedWallpaper == ChatWallpaperStyle.plain,
                          onSelected: (_) {
                            setState(
                              () => _wallpaperStyle = ChatWallpaperStyle.plain,
                            );
                            setSheetState(
                              () =>
                                  selectedWallpaper = ChatWallpaperStyle.plain,
                            );
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Gradient'),
                          selected:
                              selectedWallpaper == ChatWallpaperStyle.gradient,
                          onSelected: (_) {
                            setState(
                              () =>
                                  _wallpaperStyle = ChatWallpaperStyle.gradient,
                            );
                            setSheetState(
                              () => selectedWallpaper =
                                  ChatWallpaperStyle.gradient,
                            );
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Bubbles'),
                          selected:
                              selectedWallpaper == ChatWallpaperStyle.bubbles,
                          onSelected: (_) {
                            setState(
                              () =>
                                  _wallpaperStyle = ChatWallpaperStyle.bubbles,
                            );
                            setSheetState(
                              () => selectedWallpaper =
                                  ChatWallpaperStyle.bubbles,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatSocketService?>(chatSocketServiceProvider, (_, next) {
      _setSocket(next);
    });
    ref.watch(encryptionBootstrapProvider);
    final conversations = ref.watch(conversationListProvider);
    final invites = ref.watch(groupInvitesProvider);
    final theme = Theme.of(context);
    final currentItems =
        conversations.asData?.value ?? const <ConversationSummary>[];

    return Scaffold(
      appBar: AppBar(
        title: _isSearchMode
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _searchFocusNode.unfocus(),
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              )
            : const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_rounded),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const GroupListScreen())),
          ),
          invites.maybeWhen(
            data: (items) => IconButton(
              icon: Badge(
                isLabelVisible: items.isNotEmpty,
                label: Text('${items.length}'),
                child: const Icon(Icons.mail_outline_rounded),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GroupInvitesScreen()),
              ),
            ),
            orElse: () => IconButton(
              icon: const Icon(Icons.mail_outline_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GroupInvitesScreen()),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isSearchMode ? Icons.close_rounded : Icons.search_rounded,
            ),
            onPressed: _toggleSearchMode,
          ),
          PopupMenuButton<_ChatMenuAction>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) => _handleMenuAction(action, currentItems),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _ChatMenuAction.blockContact,
                child: _MenuLabel(
                  icon: Icons.block_rounded,
                  label: 'Block contact',
                ),
              ),
              const PopupMenuItem(
                value: _ChatMenuAction.reportContact,
                child: _MenuLabel(
                  icon: Icons.flag_outlined,
                  label: 'Report contact',
                ),
              ),
              CheckedPopupMenuItem(
                value: _ChatMenuAction.spamFilter,
                checked: _spamFilterEnabled,
                child: const _MenuLabel(
                  icon: Icons.report_gmailerrorred_rounded,
                  label: 'Spam filter',
                ),
              ),
              PopupMenuItem(
                value: _ChatMenuAction.disappearingMessages,
                child: _MenuLabel(
                  icon: Icons.timer_outlined,
                  label:
                      'Disappearing messages (${_durationLabel(_disappearingAfter)})',
                ),
              ),
              const PopupMenuItem(
                value: _ChatMenuAction.themesAndWallpaper,
                child: _MenuLabel(
                  icon: Icons.wallpaper_rounded,
                  label: 'Themes & chat wallpaper',
                ),
              ),
            ],
          ),
        ],
      ),
      body: conversations.when(
        data: (items) {
          final visibleItems = _filteredConversations(items);

          if (items.isEmpty) {
            return const _EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No conversations yet',
              subtitle:
                  'Start chatting with your friends to see messages here.',
            );
          }

          if (visibleItems.isEmpty) {
            return _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching chats',
              subtitle: _searchQuery.trim().isNotEmpty
                  ? 'Try a different search keyword.'
                  : 'Your filters hid all conversations.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(conversationListProvider.future),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                final summary = visibleItems[index];
                return _ConversationTile(
                  summary: summary,
                  isTyping: _typingConversationIds.contains(summary.id),
                  wallpaperStyle: _wallpaperStyle,
                  disappearingAfter: _disappearingAfter,
                ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load chats',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.summary,
    required this.isTyping,
    required this.wallpaperStyle,
    required this.disappearingAfter,
  });

  final ConversationSummary summary;
  final bool isTyping;
  final ChatWallpaperStyle wallpaperStyle;
  final Duration disappearingAfter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
              friend: summary.friend,
              wallpaperStyle: wallpaperStyle,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeOutCubic)),
                    ),
                    child: child,
                  );
                },
          ),
        );
        ref.invalidate(conversationListProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: _ConversationAvatar(friend: summary.friend),
                ),
                if (summary.unreadCount > 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        summary.friend.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: summary.unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                      if (summary.lastMessage != null)
                        Text(
                          _formatDate(summary.lastMessage!.createdAtDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _Preview(
                          summary: summary,
                          isTyping: isTyping,
                          disappearingAfter: disappearingAfter,
                        ),
                      ),
                      if (summary.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${summary.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({
    required this.summary,
    required this.isTyping,
    required this.disappearingAfter,
  });

  final ConversationSummary summary;
  final bool isTyping;
  final Duration disappearingAfter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final message = summary.lastMessage;

    if (isTyping) {
      return Row(
        children: [
          Text(
            'typing',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 6),
          _TypingDots(color: theme.colorScheme.primary, dotSize: 4),
        ],
      );
    }

    if (message == null) {
      return Text(
        'No messages yet',
        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      );
    }

    if (disappearingAfter > Duration.zero &&
        DateTime.now().difference(message.createdAtDate) >= disappearingAfter) {
      return Text(
        'Message disappeared',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    String content = '';
    IconData? icon;

    if (message.type == ChatMessageType.image) {
      content = 'Photo';
      icon = Icons.image_rounded;
    } else if (message.type == ChatMessageType.voice) {
      content = 'Voice message';
      icon = Icons.mic_rounded;
    } else if (message.type == ChatMessageType.encrypted) {
      final decryptor = ref.watch(
        messageDecryptorProvider(
          MessageDecryptionRequest(message: message, friend: summary.friend),
        ),
      );
      content = decryptor.when(
        data: (text) => text,
        loading: () => 'Decrypting...',
        error: (_, _) => 'Encrypted message',
      );
      icon = Icons.lock_rounded;
    } else {
      content = message.content ?? '';
    }

    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: summary.unreadCount > 0
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.friend});

  final AppUser friend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = friend.avatarUrl;

    if (avatarUrl == null) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Text(
          _initial(friend.name),
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (_, _) {},
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color, this.dotSize = 4});

  final Color color;
  final double dotSize;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final activeDot = (_controller.value * 3).floor() % 3;
        return Row(
          children: List.generate(3, (index) {
            final isActive = activeDot == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 3),
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: isActive ? 0.95 : 0.35),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _DisappearingOption {
  const _DisappearingOption(this.label, this.value);

  final String label;
  final Duration value;
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inDays == 0) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } else if (diff.inDays == 1) {
    return 'Yesterday';
  } else if (diff.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  } else {
    return '${date.day}/${date.month}';
  }
}

String _durationLabel(Duration value) {
  if (value == Duration.zero) return 'Off';
  if (value.inDays == 1) return '24h';
  return '${value.inDays}d';
}
