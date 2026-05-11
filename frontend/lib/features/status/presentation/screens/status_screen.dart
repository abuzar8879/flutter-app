import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/status_story.dart';
import '../providers/status_provider.dart';
import 'status_viewer_screen.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(statusStoriesProvider.notifier).refresh());
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final controller = ref.read(statusStoriesProvider.notifier);
      controller.purgeExpired();
      unawaited(controller.refresh());
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _postStatus() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add status'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'What do you want to share?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButtonTheme(
              data: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Post'),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (text == null || text.trim().isEmpty) return;

    try {
      await ref.read(statusStoriesProvider.notifier).postOwnStatus(text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Status posted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to post status: $error')));
    }
  }

  void _openViewer(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StatusViewerScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    final storiesController = ref.watch(statusStoriesProvider.notifier);
    ref.watch(statusStoriesProvider);

    final currentUser = session?.user;
    final ownGroup = currentUser == null
        ? null
        : storiesController.activeGroupForUser(currentUser.id);
    final recentGroups = storiesController.activeGroups(
      excludeUserId: currentUser?.id,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status'),
        actions: [
          IconButton(
            tooltip: 'Add status',
            onPressed: _postStatus,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _MyStatusTile(
            userName: currentUser?.name ?? 'You',
            hasStatus: ownGroup != null,
            latestStatus: ownGroup?.latest,
            onAdd: _postStatus,
            onView: ownGroup == null
                ? null
                : () => _openViewer(ownGroup.userId),
          ),
          const SizedBox(height: 20),
          Text(
            'Recent updates',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (recentGroups.isEmpty)
            const _NoStatusState()
          else
            ...recentGroups.map(
              (group) => _StatusGroupTile(
                group: group,
                onTap: () => _openViewer(group.userId),
              ),
            ),
        ],
      ),
    );
  }
}

class _MyStatusTile extends StatelessWidget {
  const _MyStatusTile({
    required this.userName,
    required this.hasStatus,
    required this.latestStatus,
    required this.onAdd,
    required this.onView,
  });

  final String userName;
  final bool hasStatus;
  final StatusStory? latestStatus;
  final VoidCallback onAdd;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: hasStatus ? onView : onAdd,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.primary, width: 2),
            ),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              child: Text(_initial(userName)),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: InkWell(
              onTap: onAdd,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 11,
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      title: const Text(
        'My status',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        hasStatus ? _timeAgo(latestStatus!.createdAt) : 'Tap to add status',
      ),
      trailing: IconButton(
        tooltip: 'Add status',
        onPressed: onAdd,
        icon: const Icon(Icons.edit_rounded),
      ),
    );
  }
}

class _StatusGroupTile extends StatelessWidget {
  const _StatusGroupTile({required this.group, required this.onTap});

  final StatusStoryGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 54,
        height: 54,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Text(_initial(group.userName)),
        ),
      ),
      title: Text(
        group.userName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(_timeAgo(group.latest.createdAt)),
      trailing: group.stories.length > 1
          ? Text(
              '${group.stories.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _NoStatusState extends StatelessWidget {
  const _NoStatusState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 56,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 12),
          Text(
            'No recent status updates',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Only people who added a status in the last 24 hours appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return 'expired';
}
