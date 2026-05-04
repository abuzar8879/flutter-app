import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../friends/presentation/providers/friends_providers.dart';
import '../../../users/domain/app_user.dart';
import '../../domain/group_member.dart';
import '../../domain/group_summary.dart';
import '../providers/groups_providers.dart';

class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({required this.group, super.key});

  final GroupSummary group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(authControllerProvider).session;
    final membersAsync = FutureProvider<List<GroupMember>>((ref2) async {
      final s = ref2.watch(authControllerProvider).session;
      if (s == null) throw Exception('Not authenticated');
      return ref2.read(groupsRepositoryProvider).listMembers(token: s.token, groupId: group.id);
    });
    final members = ref.watch(membersAsync);

    return Scaffold(
      appBar: AppBar(title: const Text('Group info')),
      body: members.when(
        data: (items) {
          final me = items.where((m) => m.userId == (session?.user.id ?? 0)).toList();
          final isAdmin = me.isNotEmpty && me.first.role == 'admin' && me.first.status == 'accepted';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(group.displayName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${items.where((m) => m.status == 'accepted').length} members',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  )),
              const SizedBox(height: 16),
              if (isAdmin) ...[
                FilledButton.icon(
                  onPressed: () async {
                    final friends = await ref.read(myFriendsProvider.future);
                    if (!context.mounted) return;
                    final selected = await showModalBottomSheet<Set<int>>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _InvitePickerSheet(friends: friends),
                    );
                    if (selected == null || selected.isEmpty) return;
                    final s = ref.read(authControllerProvider).session;
                    if (s == null) return;
                    await ref.read(groupsRepositoryProvider).inviteMembers(
                          token: s.token,
                          groupId: group.id,
                          inviteeIds: selected.toList(),
                        );
                    ref.invalidate(membersAsync);
                    ref.invalidate(groupInvitesProvider);
                  },
                  icon: const Icon(Icons.person_add_alt_rounded),
                  label: const Text('Invite friends'),
                ),
                const SizedBox(height: 12),
              ],
              Text('Members', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...items.map((m) {
                final user = m.user;
                final title = user?.name ?? 'User ${m.userId}';
                final subtitle = '${m.role}${m.status == 'invited' ? ' • invited' : ''}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Text(title.trim().isEmpty ? '?' : title.trim().substring(0, 1).toUpperCase()),
                  ),
                  title: Text(title),
                  subtitle: Text(subtitle),
                  trailing: isAdmin && m.role != 'admin'
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          onPressed: () async {
                            final s = ref.read(authControllerProvider).session;
                            if (s == null) return;
                            await ref.read(groupsRepositoryProvider).removeMember(
                                  token: s.token,
                                  groupId: group.id,
                                  userId: m.userId,
                                );
                            ref.invalidate(membersAsync);
                          },
                        )
                      : null,
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load members: $error')),
      ),
    );
  }
}

class _InvitePickerSheet extends StatefulWidget {
  const _InvitePickerSheet({required this.friends});

  final List<AppUser> friends;

  @override
  State<_InvitePickerSheet> createState() => _InvitePickerSheetState();
}

class _InvitePickerSheetState extends State<_InvitePickerSheet> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Invite friends', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.friends.length,
                itemBuilder: (context, index) {
                  final f = widget.friends[index];
                  final checked = _selected.contains(f.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(f.id);
                        } else {
                          _selected.remove(f.id);
                        }
                      });
                    },
                    title: Text(f.name),
                    subtitle: Text(f.email),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

