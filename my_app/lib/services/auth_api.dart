import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';

class AuthApi {
  AuthApi._();

  static final AuthApi instance = AuthApi._();

  static const Duration _connectTimeout = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 10);

  Uri _base() {
    final apiBase = AppConfig.remoteBaseUrl;
    if (apiBase == null) {
      throw StateError('Backend URL not configured');
    }
    // Support passing either:
    // - http://host:port/api  (Flutter sync uses this)
    // - http://host:port      (optional)
    final normalized = apiBase.endsWith('/api')
        ? apiBase.substring(0, apiBase.length - 4)
        : apiBase;
    return Uri.parse(normalized);
  }

  Future<Map<String, Object?>> login({
    required String email,
    required String password,
  }) async {
    final uri = _base().resolve('/auth/login');
    final client = HttpClient();
    client.connectionTimeout = _connectTimeout;
    try {
      final request = await client.postUrl(uri).timeout(_requestTimeout);
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(
          jsonEncode({'email': email.trim().toLowerCase(), 'password': password}),
        ),
      );
      final response = await request.close().timeout(_requestTimeout);
      final body = await utf8.decoder.bind(response).join().timeout(_requestTimeout);

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok) {
        throw HttpException('Login failed (${response.statusCode}): $body', uri: uri);
      }

      final parsed = jsonDecode(body);
      if (parsed is! Map) {
        throw const FormatException('Invalid login response');
      }
      return Map<String, Object?>.from(parsed);
    } finally {
      client.close(force: true);
    }
  }
}

