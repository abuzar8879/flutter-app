import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../users/domain/app_user.dart';
import '../../../users/presentation/providers/users_providers.dart';
import '../../data/friends_repository.dart';
import '../../domain/friend_request.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(ref.watch(apiClientProvider));
});

final pendingRequestsProvider = FutureProvider<List<FriendRequest>>((
  ref,
) async {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) throw Exception('Not authenticated');
  return ref
      .read(friendsRepositoryProvider)
      .fetchPendingRequests(token: session.token);
});

final myFriendsProvider = FutureProvider<List<AppUser>>((ref) async {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) throw Exception('Not authenticated');
  return ref
      .read(friendsRepositoryProvider)
      .fetchMyFriends(token: session.token);
});

class FriendsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> sendRequest(int receiverId) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) throw Exception('Not authenticated');

    state = const AsyncLoading();
    try {
      final result = await ref
          .read(friendsRepositoryProvider)
          .sendRequest(token: session.token, receiverId: receiverId);

      ref.invalidate(allUsersProvider);
      ref.invalidate(pendingRequestsProvider);
      ref.invalidate(myFriendsProvider);
      state = const AsyncData(null);

      return result.status == FriendRequestStatus.accepted
          ? 'You are now friends.'
          : 'Friend request sent.';
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  Future<void> acceptRequest(int requestId) async {
    await _respond(requestId: requestId, action: 'accepted');
    ref.invalidate(myFriendsProvider);
  }

  Future<void> rejectRequest(int requestId) async {
    await _respond(requestId: requestId, action: 'rejected');
  }

  Future<void> _respond({
    required int requestId,
    required String action,
  }) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) throw Exception('Not authenticated');

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(friendsRepositoryProvider)
          .respondToRequest(
            token: session.token,
            requestId: requestId,
            action: action,
          );
      ref.invalidate(allUsersProvider);
      ref.invalidate(pendingRequestsProvider);
    });
  }
}

final friendsNotifierProvider = AsyncNotifierProvider<FriendsNotifier, void>(
  FriendsNotifier.new,
);
