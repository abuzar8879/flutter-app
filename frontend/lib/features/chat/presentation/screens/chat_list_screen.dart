import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../domain/chat_message.dart';
import '../../domain/conversation_summary.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../groups/presentation/screens/group_invites_screen.dart';
import '../../../groups/presentation/screens/group_list_screen.dart';
import '../providers/chat_providers.dart';
import '../providers/conversation_list_provider.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final socket = ref.read(chatSocketServiceProvider);
      socket?.addMessageListener(_handleNewMessage);
    });
  }

  @override
  void dispose() {
    ref.read(chatSocketServiceProvider)?.removeMessageListener(_handleNewMessage);
    super.dispose();
  }

  void _handleNewMessage(ChatMessage message) {
    ref.invalidate(conversationListProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(encryptionBootstrapProvider);
    final conversations = ref.watch(conversationListProvider);
    final invites = ref.watch(groupInvitesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GroupListScreen()),
            ),
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
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: conversations.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(conversationListProvider.future),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _ConversationTile(summary: items[index])
                    .animate()
                    .fadeIn(delay: (index * 50).ms)
                    .slideX(begin: 0.1);
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
                Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
                const SizedBox(height: 16),
                Text('Failed to load chats', style: theme.textTheme.titleMedium),
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
  const _ConversationTile({required this.summary});

  final ConversationSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
              ChatScreen(friend: summary.friend),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(Tween(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic))),
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
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      _initial(summary.friend.name),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
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
                        border: Border.all(color: theme.colorScheme.surface, width: 2),
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
                          fontWeight: summary.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      if (summary.lastMessage != null)
                        Text(
                          _formatDate(summary.lastMessage!.createdAtDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _Preview(summary: summary),
                      ),
                      if (summary.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
  const _Preview({required this.summary});

  final ConversationSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final message = summary.lastMessage;
    
    if (message == null) {
      return Text(
        'No messages yet',
        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      );
    }

    String content = '';
    IconData? icon;

    if (message.type == ChatMessageType.image) {
      content = 'Photo';
      icon = Icons.image_rounded;
    } else if (message.type == ChatMessageType.encrypted) {
      final decryptor = ref.watch(
        messageDecryptorProvider(
          MessageDecryptionRequest(message: message, friend: summary.friend),
        ),
      );
      content = decryptor.when(
        data: (text) => text,
        loading: () => 'Decrypting...',
        error: (_, __) => 'Encrypted message',
      );
      icon = Icons.lock_rounded;
    } else {
      content = message.content ?? '';
    }

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: theme.colorScheme.onSurface.withOpacity(0.4)),
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
                : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ],
    );
  }
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
