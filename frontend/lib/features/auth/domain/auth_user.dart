class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarPath,
    this.publicKey,
  });

  final String id;
  final String name;
  final String email;
  final String? avatarPath;
  final String? publicKey;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarPath: json['avatarPath'] as String?,
      publicKey: json['publicKey'] as String?,
    );
  }
}
