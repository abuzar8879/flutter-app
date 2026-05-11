import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/providers/api_client_provider.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/status_repository.dart';
import '../../domain/status_story.dart';

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  return StatusRepository(ref.watch(apiClientProvider));
});

final statusStoriesProvider =
    NotifierProvider<StatusStoriesController, List<StatusStory>>(
      StatusStoriesController.new,
    );

class StatusStoriesController extends Notifier<List<StatusStory>> {
  @override
  List<StatusStory> build() {
    Future.microtask(refresh);
    return const [];
  }

  List<StatusStory> get activeStories {
    final active = state.where((story) => story.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return active;
  }

  List<StatusStoryGroup> activeGroups({String? excludeUserId}) {
    final groups = <String, List<StatusStory>>{};
    for (final story in activeStories) {
      if (excludeUserId != null && story.userId == excludeUserId) continue;
      groups.putIfAbsent(story.userId, () => []).add(story);
    }

    return groups.entries.map((entry) {
        final stories = entry.value
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return StatusStoryGroup(
          userId: entry.key,
          userName: stories.first.userName,
          stories: List.unmodifiable(stories),
        );
      }).toList()
      ..sort((a, b) => b.latest.createdAt.compareTo(a.latest.createdAt));
  }

  StatusStoryGroup? activeGroupForUser(String userId) {
    final stories =
        activeStories.where((story) => story.userId == userId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (stories.isEmpty) return null;
    return StatusStoryGroup(
      userId: userId,
      userName: stories.first.userName,
      stories: List.unmodifiable(stories),
    );
  }

  Future<void> refresh() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    try {
      final statuses = await ref
          .read(statusRepositoryProvider)
          .fetchStatuses(token: session.token);
      state = statuses.where((story) => story.isActive).toList();
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        state = activeStories;
        return;
      }
      rethrow;
    }
  }

  Future<void> postOwnStatus(String text) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final status = await ref
        .read(statusRepositoryProvider)
        .postStatus(token: session.token, text: trimmed);
    state = [status, ...activeStories.where((story) => story.id != status.id)];
  }

  void purgeExpired() {
    final active = activeStories;
    if (active.length != state.length) {
      state = active;
    }
  }
}
