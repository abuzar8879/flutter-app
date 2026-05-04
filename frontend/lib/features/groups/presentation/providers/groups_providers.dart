import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/groups_repository.dart';
import '../../domain/group_summary.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.watch(apiClientProvider));
});

final groupListProvider = FutureProvider<List<GroupSummary>>((ref) async {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) throw Exception('Not authenticated');
  return ref.read(groupsRepositoryProvider).listGroups(token: session.token);
});

final groupInvitesProvider = FutureProvider<List<GroupInvite>>((ref) async {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) throw Exception('Not authenticated');
  return ref.read(groupsRepositoryProvider).listInvites(token: session.token);
});

