import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../models/session.dart';
import '../storage/local_store.dart';
import 'auth_api.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _sessionKey = 'session';

  Session? _session;

  Session? get session => _session;
  AuthUser? get user => _session?.user;
  String? get token => _session?.token;

  bool get loggedIn => _session != null && (_session?.token.isNotEmpty ?? false);

  Future<void> init() async {
    final raw = LocalStore.authBox().get(_sessionKey);
    if (raw == null) return;
    try {
      final session = Session.fromJson(Map<String, Object?>.from(raw));
      if (session.token.isNotEmpty && session.user.id.isNotEmpty) {
        _session = session;
      }
    } catch (_) {
      // Ignore corrupted session data.
      _session = null;
    }
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await AuthApi.instance.login(email: email, password: password);

    final token = response['token'];
    final userRaw = response['user'];
    if (token is! String || token.isEmpty || userRaw is! Map) {
      throw const FormatException('Invalid login response');
    }

    final session = Session(
      token: token,
      user: AuthUser.fromJson(Map<String, Object?>.from(userRaw)),
    );

    _session = session;
    await LocalStore.authBox().put(_sessionKey, session.toJson());
    notifyListeners();
  }

  Future<void> logout() async {
    _session = null;
    await LocalStore.authBox().delete(_sessionKey);
    notifyListeners();
  }
}

