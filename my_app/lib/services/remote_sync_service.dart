import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import '../models/outbox_item.dart';

class RemoteSyncService {
  RemoteSyncService._();

  static final RemoteSyncService instance = RemoteSyncService._();

  bool get enabled => AppConfig.remoteBaseUrl != null;

  static const Duration _connectTimeout = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 10);

  Uri _uri(String path) {
    final baseUrl = AppConfig.remoteBaseUrl;
    if (baseUrl == null) {
      throw StateError('Remote sync not configured');
    }
    final trimmed = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$trimmed$path');
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
    final uri = switch (item.action) {
      OutboxAction.createRequest || OutboxAction.updateRequest => _uri(
        '/requests/${Uri.encodeComponent(item.requestId)}',
      ),
      OutboxAction.updateStatus => _uri(
        '/requests/${Uri.encodeComponent(item.requestId)}/status',
      ),
    };

    final method = switch (item.action) {
      OutboxAction.createRequest || OutboxAction.updateRequest => 'PUT',
      OutboxAction.updateStatus => 'PATCH',
    };

    final client = HttpClient();
    client.connectionTimeout = _connectTimeout;
    try {
      final request = await client.openUrl(method, uri).timeout(_requestTimeout);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(item.payload)));
      final response = await request.close().timeout(_requestTimeout);
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok) {
        final body = await utf8.decoder.bind(response).join().timeout(_requestTimeout);
        throw HttpException(
          'Sync failed (${response.statusCode}): $body',
          uri: uri,
        );
      }
    } finally {
      client.close(force: true);
    }
  }
}
