import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/api_profile_repository.dart';
import '../../data/profile_repository.dart';
import '../../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiProfileRepository(apiClient);
});

final profileProvider = FutureProvider<UserProfile>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final session = authState.session;
  if (session == null) {
    throw Exception('Authentication required');
  }

  return ref.read(profileRepositoryProvider).fetchMyProfile(session.token);
});
