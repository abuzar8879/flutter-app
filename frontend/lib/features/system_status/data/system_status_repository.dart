import '../../../core/network/api_client.dart';
import '../domain/system_status.dart';

class SystemStatusRepository {
  const SystemStatusRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<SystemStatus> fetchStatus() async {
    final json = await _apiClient.getJson('/api/health');
    return SystemStatus.fromJson(json);
  }
}
