import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  @override
  void initState() {
    super.initState();
    // Refresh list on new group messages.
    Future.microtask(() {
      final socket = ref.read(chatSocketServiceProvider);
      socket?.addGroupMessageListener(_handleGroupMessage);
      socket?.addGroupReadListener(_handleGroupRead);
    });
  }

  @override
  void dispose() {
    ref.read(chatSocketServiceProvider)?.removeGroupMessageListener(_handleGroupMessage);
    ref.read(chatSocketServiceProvider)?.removeGroupReadListener(_handleGroupRead);
    super.dispose();
  }

  void _handleGroupMessage(GroupMessage message) {
    ref.invalidate(groupListProvider);
  }

  void _handleGroupRead(int groupId, int readerId, int lastReadMessageId) {
    ref.invalidate(groupListProvider);
  }

  @override
  Widget build(BuildContext context) {
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
                  MaterialPageRoute(builder: (_) => GroupChatScreen(group: created)),
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
              itemBuilder: (context, index) => _GroupTile(summary: items[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load groups: $error')),
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

