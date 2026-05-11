import '../../../core/network/api_client.dart';
import '../domain/status_story.dart';

class StatusRepository {
  const StatusRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<StatusStory>> fetchStatuses({required String token}) async {
    final json = await _apiClient.getJson('/api/statuses', token: token);
    final items = json['statuses'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(StatusStory.fromJson)
        .toList();
  }

  Future<StatusStory> postStatus({
    required String token,
    required String text,
  }) async {
    final json = await _apiClient.postJson(
      '/api/statuses',
      token: token,
      body: {'text': text},
    );
    return StatusStory.fromJson(json['status'] as Map<String, dynamic>);
  }
}
