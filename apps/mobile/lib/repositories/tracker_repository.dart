import 'dart:convert';

import 'package:http/http.dart' as http;

class TrackerRepository {
  TrackerRepository({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_URL',
              defaultValue: 'http://localhost:4000/api',
            );

  final http.Client _client;
  final String _baseUrl;

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body);

  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body);

  Future<void> delete(String path) async {
    await _send('DELETE', path);
  }

  Future<dynamic> _send(String method, String path,
      [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = {'Content-Type': 'application/json'};
    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers);
        case 'POST':
          response = await _client.post(uri,
              headers: headers, body: jsonEncode(body ?? {}));
        case 'PUT':
          response = await _client.put(uri,
              headers: headers, body: jsonEncode(body ?? {}));
        case 'DELETE':
          response = await _client.delete(uri, headers: headers);
      }
    } catch (_) {
      throw Exception(
          'Tidak dapat terhubung ke API. Pastikan server berjalan dan API_URL sudah benar.');
    }
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    final result = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(result is Map
          ? result['Message'] ?? 'Permintaan tidak berhasil.'
          : 'Permintaan tidak berhasil.');
    }
    return result;
  }
}
