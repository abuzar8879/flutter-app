import '../../../core/config/app_config.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarPath,
    this.publicKey,
  });

  final int id;
  final String name;
  final String email;
  final String? avatarPath;
  final String? publicKey;

  String? get avatarUrl => (avatarPath != null && avatarPath!.isNotEmpty)
      ? '${AppConfig.apiBaseUrl}$avatarPath'
      : null;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _readId(json['id']),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarPath: json['avatarPath'] as String?,
      publicKey: json['publicKey'] as String?,
    );
  }
}

int _readId(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
