import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../friends/presentation/providers/friends_providers.dart';
import '../../../users/domain/app_user.dart';
import '../../data/groups_repository.dart';
import '../providers/groups_providers.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _selected = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(myFriendsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Select friends',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text('${_selected.length} selected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    )),
              ],
            ),
          ),
          Expanded(
            child: friends.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No friends to add'));
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final friend = items[index];
                    final checked = _selected.contains(friend.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(friend.id);
                          } else {
                            _selected.remove(friend.id);
                          }
                        });
                      },
                      title: Text(friend.name),
                      subtitle: Text(friend.email),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load friends: $error')),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () async {
                          final session = ref.read(authControllerProvider).session;
                          if (session == null) return;
                          final group = await ref.read(groupsRepositoryProvider).createGroup(
                                token: session.token,
                                name: _nameController.text.trim(),
                                inviteeIds: _selected.toList(),
                              );
                          ref.invalidate(groupListProvider);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(group);
                        },
                  child: const Text('Create group'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

