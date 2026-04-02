import 'auth_user.dart';

class Session {
  Session({required this.token, required this.user});

  final String token;
  final AuthUser user;

  Map<String, Object?> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
    };
  }

  static Session fromJson(Map<String, Object?> json) {
    final userRaw = json['user'];
    return Session(
      token: (json['token'] as String?) ?? '',
      user: AuthUser.fromJson(
        Map<String, Object?>.from((userRaw as Map?) ?? const {}),
      ),
    );
  }
}

