import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final apiClient = ApiClient();
  ref.onDispose(apiClient.dispose);
  return apiClient;
});
