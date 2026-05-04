class SystemStatus {
  const SystemStatus({
    required this.message,
    required this.environment,
    required this.databaseConfigured,
    required this.databaseConnected,
    required this.timestamp,
    this.databaseError,
  });

  final String message;
  final String environment;
  final bool databaseConfigured;
  final bool databaseConnected;
  final String timestamp;
  final String? databaseError;

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    final database =
        json['database'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return SystemStatus(
      message: json['message'] as String? ?? 'Unknown status',
      environment: json['environment'] as String? ?? 'unknown',
      databaseConfigured: database['configured'] as bool? ?? false,
      databaseConnected: database['connected'] as bool? ?? false,
      timestamp: json['timestamp'] as String? ?? '',
      databaseError:
          database['error'] as String? ??
          database['lastConnectionError'] as String?,
    );
  }
}
