class AuthUser {
  AuthUser({
    required this.id,
    required this.email,
    required this.role,
  });

  final String id;
  final String email;
  final String role; // 'user' | 'volunteer'

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
    };
  }

  static AuthUser fromJson(Map<String, Object?> json) {
    return AuthUser(
      id: (json['id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'user',
    );
  }
}

