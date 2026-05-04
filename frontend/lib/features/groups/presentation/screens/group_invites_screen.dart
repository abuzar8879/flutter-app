import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../providers/groups_providers.dart';

class GroupInvitesScreen extends ConsumerWidget {
  const GroupInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(groupInvitesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Group invitations')),
      body: invites.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No invitations',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invite = items[index];
              final by = invite.invitedBy;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.groupName.trim().isEmpty ? 'Group' : invite.groupName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      by == null ? 'Invitation' : 'Invited by ${by.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final session = ref.read(authControllerProvider).session;
                              if (session == null) return;
                              await ref.read(groupsRepositoryProvider).rejectInvite(
                                    token: session.token,
                                    groupId: invite.groupId,
                                  );
                              ref.invalidate(groupInvitesProvider);
                              ref.invalidate(groupListProvider);
                            },
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final session = ref.read(authControllerProvider).session;
                              if (session == null) return;
                              await ref.read(groupsRepositoryProvider).acceptInvite(
                                    token: session.token,
                                    groupId: invite.groupId,
                                  );
                              await ref.read(chatSocketServiceProvider)?.joinGroup(invite.groupId);
                              ref.invalidate(groupInvitesProvider);
                              ref.invalidate(groupListProvider);
                            },
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load invites: $error')),
      ),
    );
  }
}

