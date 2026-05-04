import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../../data/system_status_repository.dart';
import '../../domain/system_status.dart';

final systemStatusRepositoryProvider = Provider<SystemStatusRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SystemStatusRepository(apiClient);
});

final systemStatusProvider = FutureProvider<SystemStatus>((ref) async {
  final repository = ref.watch(systemStatusRepositoryProvider);
  return repository.fetchStatus();
});
