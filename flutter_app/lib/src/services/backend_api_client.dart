import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import 'session_store.dart';

class BackendApiException implements Exception {
  BackendApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'BackendApiException($statusCode): $message';
}

class BackendApiClient {
  BackendApiClient({
    required this.baseUrl,
    required this.sessionStore,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final SessionStore sessionStore;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await _send(
      'GET',
      path,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await _send(
      'GET',
      path,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw BackendApiException(
        'Expected a JSON list from $path',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      'POST',
      path,
      body: body,
      authenticated: authenticated,
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      'PATCH',
      path,
      body: body,
      authenticated: authenticated,
    );
    return _decodeObject(response);
  }

  Future<void> delete(
    String path, {
    bool authenticated = true,
  }) async {
    await _send('DELETE', path, authenticated: authenticated);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse(baseUrl).resolve(path).replace(
          queryParameters: queryParameters,
        );
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (authenticated) {
      final AuthSession? session = await sessionStore.loadSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) {
        throw BackendApiException('Missing authenticated session');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    late final http.Response response;
    switch (method) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers);
      case 'POST':
        response = await _httpClient.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const <String, Object?>{}),
        );
      case 'PATCH':
        response = await _httpClient.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const <String, Object?>{}),
        );
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: headers);
      default:
        throw BackendApiException('Unsupported HTTP method: $method');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        response.body.isEmpty ? 'Request failed' : response.body,
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw BackendApiException(
        'Expected a JSON object',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}
