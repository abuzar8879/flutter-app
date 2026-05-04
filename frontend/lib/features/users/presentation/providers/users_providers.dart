import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/users_repository.dart';
import '../../domain/app_user.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(apiClientProvider));
});

final usersSearchQueryProvider =
    NotifierProvider<UsersSearchQueryController, String>(
      UsersSearchQueryController.new,
    );

class UsersSearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final allUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) throw Exception('Not authenticated');

  final search = ref.watch(usersSearchQueryProvider);
  return ref
      .read(usersRepositoryProvider)
      .fetchAllUsers(token: session.token, search: search);
});
