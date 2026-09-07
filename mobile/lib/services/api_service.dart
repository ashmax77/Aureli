import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  final AuthService _authService;
  final http.Client _client = http.Client();

  static const Duration _requestTimeout = Duration(seconds: 25);

  // Base URL pointing to Render Spring Boot backend.
  static String get baseUrl => 'https://aureli-9twx.onrender.com/api/v1';

  ApiService(this._authService);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET Request helper
  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    if (kDebugMode) {
      debugPrint("ApiService GET $uri");
    }
    try {
      final response = await _client.get(uri, headers: headers).timeout(_requestTimeout);
      _logResponse(response);
      return response;
    } on TimeoutException {
      if (kDebugMode) debugPrint("ApiService GET Timeout: $uri");
      return http.Response(jsonEncode({'error': 'Request timed out'}), 504);
    } catch (e) {
      if (kDebugMode) debugPrint("ApiService GET Error: $e");
      rethrow;
    }
  }

  // POST Request helper
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();
    final jsonBody = jsonEncode(body);
    if (kDebugMode) {
      debugPrint("ApiService POST $uri");
    }
    try {
      final response = await _client.post(uri, headers: headers, body: jsonBody).timeout(_requestTimeout);
      _logResponse(response);
      return response;
    } on TimeoutException {
      if (kDebugMode) debugPrint("ApiService POST Timeout: $uri");
      return http.Response(jsonEncode({'error': 'Request timed out'}), 504);
    } catch (e) {
      if (kDebugMode) debugPrint("ApiService POST Error: $e");
      rethrow;
    }
  }

  // PUT Request helper
  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();
    final jsonBody = jsonEncode(body);
    if (kDebugMode) {
      debugPrint("ApiService PUT $uri");
    }
    try {
      final response = await _client.put(uri, headers: headers, body: jsonBody).timeout(_requestTimeout);
      _logResponse(response);
      return response;
    } on TimeoutException {
      if (kDebugMode) debugPrint("ApiService PUT Timeout: $uri");
      return http.Response(jsonEncode({'error': 'Request timed out'}), 504);
    } catch (e) {
      if (kDebugMode) debugPrint("ApiService PUT Error: $e");
      rethrow;
    }
  }

  // PATCH Request helper
  Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();
    final jsonBody = jsonEncode(body);
    if (kDebugMode) {
      debugPrint("ApiService PATCH $uri");
    }
    try {
      final response = await _client.patch(uri, headers: headers, body: jsonBody).timeout(_requestTimeout);
      _logResponse(response);
      return response;
    } on TimeoutException {
      if (kDebugMode) debugPrint("ApiService PATCH Timeout: $uri");
      return http.Response(jsonEncode({'error': 'Request timed out'}), 504);
    } catch (e) {
      if (kDebugMode) debugPrint("ApiService PATCH Error: $e");
      rethrow;
    }
  }

  // DELETE Request helper
  Future<http.Response> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();
    if (kDebugMode) {
      debugPrint("ApiService DELETE $uri");
    }
    try {
      final response = await _client.delete(uri, headers: headers).timeout(_requestTimeout);
      _logResponse(response);
      return response;
    } on TimeoutException {
      if (kDebugMode) debugPrint("ApiService DELETE Timeout: $uri");
      return http.Response(jsonEncode({'error': 'Request timed out'}), 504);
    } catch (e) {
      if (kDebugMode) debugPrint("ApiService DELETE Error: $e");
      rethrow;
    }
  }

  void _logResponse(http.Response response) {
    if (kDebugMode) {
      debugPrint(
        "ApiService Response ${response.statusCode} | Content-Length: ${response.body.length}",
      );
    }
    // Auto-revoke local session if server returns 401 Unauthorized (token revoked/invalid)
    if (response.statusCode == 401) {
      if (kDebugMode) {
        debugPrint("ApiService 401 Unauthorized: Revoking stale session");
      }
      _authService.signOut();
    }
  }
}
