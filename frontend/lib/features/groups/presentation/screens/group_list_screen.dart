import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/data/chat_socket_service.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../domain/group_message.dart';
import '../../domain/group_summary.dart';
import '../providers/groups_providers.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';
import 'group_invites_screen.dart';

class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  ChatSocketService? _socket;

  @override
  void initState() {
    super.initState();
    // Refresh list on new group messages.
    Future.microtask(() {
      _setSocket(ref.read(chatSocketServiceProvider));
    });
  }

  @override
  void dispose() {
    _setSocket(null);
    super.dispose();
  }

  void _setSocket(ChatSocketService? socket) {
    if (_socket == socket) return;
    _socket?.removeGroupMessageListener(_handleGroupMessage);
    _socket?.removeGroupMessageUpdatedListener(_handleGroupMessage);
    _socket?.removeGroupReadListener(_handleGroupRead);
    _socket = socket;
    _socket?.addGroupMessageListener(_handleGroupMessage);
    _socket?.addGroupMessageUpdatedListener(_handleGroupMessage);
    _socket?.addGroupReadListener(_handleGroupRead);
  }

  void _handleGroupMessage(GroupMessage message) {
    ref.invalidate(groupListProvider);
  }

  void _handleGroupRead(
    String groupId,
    String readerId,
    String lastReadMessageId,
  ) {
    ref.invalidate(groupListProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatSocketService?>(chatSocketServiceProvider, (_, next) {
      _setSocket(next);
    });
    final groups = ref.watch(groupListProvider);
    final invites = ref.watch(groupInvitesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
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
            icon: const Icon(Icons.group_add_rounded),
            onPressed: () async {
              final created = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              );
              ref.invalidate(groupListProvider);
              ref.invalidate(groupInvitesProvider);
              if (!context.mounted) return;
              if (created is GroupSummary) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupChatScreen(group: created),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: groups.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No groups yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(groupListProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _GroupTile(summary: items[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Failed to load groups: $error')),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.summary});

  final GroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GroupChatScreen(group: summary)),
        );
      },
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        child: Icon(Icons.groups_rounded, color: theme.colorScheme.primary),
      ),
      title: Text(
        summary.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('${summary.memberCount} members'),
      trailing: summary.unreadCount > 0
          ? Badge(label: Text('${summary.unreadCount}'))
          : null,
    );
  }
}
