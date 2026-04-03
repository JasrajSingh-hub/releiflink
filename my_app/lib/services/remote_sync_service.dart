import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import '../models/outbox_item.dart';

class SyncConflictException implements Exception {
  SyncConflictException({
    required this.requestId,
    required this.statusCode,
    required this.body,
    required this.uri,
  });

  final String requestId;
  final int statusCode;
  final String body;
  final Uri uri;

  @override
  String toString() => 'SyncConflictException($statusCode $uri): $body';
}

class RemoteSyncService {
  RemoteSyncService._();

  static final RemoteSyncService instance = RemoteSyncService._();

  bool get enabled => AppConfig.remoteBaseUrl != null;

  static const Duration _connectTimeout = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _healthTimeout = Duration(seconds: 2);

  Uri _uri(String path) {
    final baseUrl = AppConfig.remoteBaseUrl;
    if (baseUrl == null) {
      throw StateError('Remote sync not configured');
    }
    final trimmed = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$trimmed$path');
  }

  Future<bool> checkHealth() async {
    final uri = _uri('/health');
    final client = HttpClient();
    client.connectionTimeout = _healthTimeout;
    try {
      final request = await client.getUrl(uri).timeout(_healthTimeout);
      final response = await request.close().timeout(_healthTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, Object?>>> fetchAllRequests() async {
    final uri = _uri('/requests');
    final client = HttpClient();
    client.connectionTimeout = _connectTimeout;
    try {
      final request = await client.getUrl(uri).timeout(_requestTimeout);
      final response = await request.close().timeout(_requestTimeout);
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      final body = await utf8.decoder.bind(response).join().timeout(_requestTimeout);
      if (!ok) {
        throw HttpException('Fetch failed (${response.statusCode}): $body', uri: uri);
      }
      final parsed = jsonDecode(body);
      if (parsed is! List) return const [];
      return parsed
          .whereType<Map>()
          .map((m) => Map<String, Object?>.from(m))
          .toList();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> send(OutboxItem item) async {
    final client = HttpClient();
    client.connectionTimeout = _connectTimeout;
    try {
      if (item.action == OutboxAction.updateStatus) {
        await _sendStatusUpdate(client, item);
        return;
      }

      final uri = _uri('/requests/${Uri.encodeComponent(item.requestId)}');
      final request = await client.openUrl('PUT', uri).timeout(_requestTimeout);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(item.payload)));
      final response = await request.close().timeout(_requestTimeout);
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok) {
        final body = await utf8.decoder.bind(response).join().timeout(_requestTimeout);
        if (response.statusCode == 409 || response.statusCode == 403) {
          throw SyncConflictException(
            requestId: item.requestId,
            statusCode: response.statusCode,
            body: body,
            uri: uri,
          );
        }
        throw HttpException('Sync failed (${response.statusCode}): $body', uri: uri);
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _sendStatusUpdate(HttpClient client, OutboxItem item) async {
    final raw = item.payload['status'];
    final status = raw is String ? raw : '';

    // Backend task flow is:
    // open -> accept() -> assigned -> in_progress -> completed
    //
    // Our offline UI jumps open -> in_progress directly.
    // To keep sync reliable and prevent double assignment, we:
    // 1) Attempt accept
    // 2) If accept conflicts (409/403), stop and surface a conflict
    // 3) Then patch status (in_progress / completed)

    final acceptUri = _uri('/requests/${Uri.encodeComponent(item.requestId)}/accept');
    try {
      final acceptReq = await client.openUrl('POST', acceptUri).timeout(_requestTimeout);
      final acceptRes = await acceptReq.close().timeout(_requestTimeout);
      final ok = acceptRes.statusCode >= 200 && acceptRes.statusCode < 300;
      if (!ok) {
        final body = await utf8.decoder.bind(acceptRes).join().timeout(_requestTimeout);
        if (acceptRes.statusCode == 409 || acceptRes.statusCode == 403) {
          throw SyncConflictException(
            requestId: item.requestId,
            statusCode: acceptRes.statusCode,
            body: body,
            uri: acceptUri,
          );
        }
        throw HttpException('Accept failed (${acceptRes.statusCode}): $body', uri: acceptUri);
      }
    } on HttpException {
      rethrow;
    }

    final next = switch (status) {
      'inProgress' || 'in_progress' || 'in-progress' => 'in_progress',
      'completed' => 'completed',
      _ => status,
    };

    final uri = _uri('/requests/${Uri.encodeComponent(item.requestId)}/status');
    final request = await client.openUrl('PATCH', uri).timeout(_requestTimeout);
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode({'status': next})));
    final response = await request.close().timeout(_requestTimeout);
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (!ok) {
      final body = await utf8.decoder.bind(response).join().timeout(_requestTimeout);
      if (response.statusCode == 409 || response.statusCode == 403) {
        throw SyncConflictException(
          requestId: item.requestId,
          statusCode: response.statusCode,
          body: body,
          uri: uri,
        );
      }
      throw HttpException(
        'Sync failed (${response.statusCode}): $body',
        uri: uri,
      );
    }
  }
}
