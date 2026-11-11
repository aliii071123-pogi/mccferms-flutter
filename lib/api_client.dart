import 'dart:convert';

import 'package:http/http.dart' as http;

class FermsApiClient {
  FermsApiClient({required String baseUrl, http.Client? client, this.token})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  final Uri _baseUri;
  final http.Client _client;
  final bool _ownsClient;
  String? token;

  Future<dynamic> get(String path, {Map<String, String>? queryParameters}) =>
      _send('GET', path, queryParameters: queryParameters);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = _baseUri
        .resolve(normalizedPath)
        .replace(queryParameters: queryParameters);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token case final value?) 'Authorization': 'Bearer $value',
    };
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, decoded);
    }
    return decoded;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.errors = const {},
    this.profileRequired = false,
  });

  final int statusCode;
  final String message;
  final Map<String, List<String>> errors;
  final bool profileRequired;

  factory ApiException.fromResponse(int statusCode, dynamic body) {
    if (body is! Map) {
      return ApiException(
        statusCode: statusCode,
        message: 'The server returned an unexpected response ($statusCode).',
      );
    }
    final rawErrors = body['errors'];
    final errors = <String, List<String>>{};
    if (rawErrors is Map) {
      for (final entry in rawErrors.entries) {
        final value = entry.value;
        errors[entry.key.toString()] = value is List
            ? value.map((item) => item.toString()).toList()
            : [value.toString()];
      }
    }
    return ApiException(
      statusCode: statusCode,
      message: body['message']?.toString() ?? 'Request failed ($statusCode).',
      errors: errors,
      profileRequired: body['profile_required'] == true,
    );
  }

  @override
  String toString() => message;
}
