import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  final AuthService _authService;
  final http.Client _client = http.Client();

  static const Duration _requestTimeout = Duration(seconds: 60);

  // Base URL pointing to Render Spring Boot backend.
  // Override at build time: flutter run --dart-define=BASE_URL=https://your-server.com/api/v1
  static const String _defaultBaseUrl = 'https://aureli-9twx.onrender.com/api/v1';
  static String get baseUrl => const String.fromEnvironment('BASE_URL', defaultValue: _defaultBaseUrl);
  static String get _rootUrl => baseUrl.replaceAll('/v1', '');

  ApiService(this._authService);

  // Proactively ping health endpoint to wake up Render free tier container immediately on app start
  void wakeUpServer() {
    try {
      final uri = Uri.parse('$_rootUrl/health');
      _client.get(uri).timeout(const Duration(seconds: 60)).then((response) {
        if (kDebugMode) debugPrint("ApiService: Server warm-up responded with ${response.statusCode}");
      }).catchError((e) {
        if (kDebugMode) debugPrint("ApiService: Server warm-up ping: $e");
      });
    } catch (_) {}
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function(Map<String, String> headers) requestFn, {
    String methodName = 'REQUEST',
    Uri? uri,
  }) async {
    Map<String, String> headers = await _getHeaders();
    try {
      var response = await requestFn(headers).timeout(_requestTimeout);
      _logResponse(response);

      // Handle 401 Unauthorized by force refreshing Firebase token and retrying once
      if (response.statusCode == 401) {
        if (kDebugMode) debugPrint("ApiService: Received 401 for $methodName $uri. Attempting token force refresh...");
        final newToken = await _authService.getIdToken(true);
        if (newToken != null) {
          headers = {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $newToken',
          };
          response = await requestFn(headers).timeout(_requestTimeout);
          _logResponse(response);
        }
      }

      // Handle 504 / Gateway Timeout by retrying after server wake-up check
      if (response.statusCode == 504) {
        if (kDebugMode) debugPrint("ApiService: Received 504 for $methodName $uri. Retrying after container warm-up...");
        wakeUpServer();
        await Future.delayed(const Duration(seconds: 2));
        response = await requestFn(headers).timeout(_requestTimeout);
        _logResponse(response);
      }

      return response;
    } on TimeoutException {
      if (kDebugMode) debugPrint("ApiService $methodName Timeout for $uri. Retrying once...");
      try {
        wakeUpServer();
        final response = await requestFn(headers).timeout(_requestTimeout);
        _logResponse(response);
        return response;
      } on TimeoutException {
        if (kDebugMode) debugPrint("ApiService $methodName Double Timeout for $uri");
        return http.Response(jsonEncode({'error': 'Server connection timed out. Please try again.'}), 504);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("ApiService $methodName Error: $e");
      rethrow;
    }
  }

  // GET Request helper
  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    if (kDebugMode) debugPrint("ApiService GET $uri");
    return _executeWithRetry(
      (headers) => _client.get(uri, headers: headers),
      methodName: 'GET',
      uri: uri,
    );
  }

  // POST Request helper
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final jsonBody = jsonEncode(body);
    if (kDebugMode) debugPrint("ApiService POST $uri");
    return _executeWithRetry(
      (headers) => _client.post(uri, headers: headers, body: jsonBody),
      methodName: 'POST',
      uri: uri,
    );
  }

  // PUT Request helper
  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final jsonBody = jsonEncode(body);
    if (kDebugMode) debugPrint("ApiService PUT $uri");
    return _executeWithRetry(
      (headers) => _client.put(uri, headers: headers, body: jsonBody),
      methodName: 'PUT',
      uri: uri,
    );
  }

  // PATCH Request helper
  Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final jsonBody = jsonEncode(body);
    if (kDebugMode) debugPrint("ApiService PATCH $uri");
    return _executeWithRetry(
      (headers) => _client.patch(uri, headers: headers, body: jsonBody),
      methodName: 'PATCH',
      uri: uri,
    );
  }

  // DELETE Request helper
  Future<http.Response> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    if (kDebugMode) debugPrint("ApiService DELETE $uri");
    return _executeWithRetry(
      (headers) => _client.delete(uri, headers: headers),
      methodName: 'DELETE',
      uri: uri,
    );
  }

  void _logResponse(http.Response response) {
    if (kDebugMode) {
      debugPrint("ApiService Response ${response.statusCode} | Content-Length: ${response.body.length}");
    }
  }
}
