import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  final AuthService _authService;

  // Base URL pointing to the local Spring Boot backend.
  // Using localhost:8080 for physical Android device with adb reverse tcp:8080 tcp:8080 port forwarding.
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
    final response = await http.get(uri, headers: headers);
    _logResponse(response);
    return response;
  }

  // POST Request helper
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();
    final jsonBody = jsonEncode(body);
    if (kDebugMode) {
      debugPrint("ApiService POST $uri");
    }
    final response = await http.post(uri, headers: headers, body: jsonBody);
    _logResponse(response);
    return response;
  }

  // PUT Request helper
  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();
    final jsonBody = jsonEncode(body);
    if (kDebugMode) {
      debugPrint("ApiService PUT $uri");
    }
    final response = await http.put(uri, headers: headers, body: jsonBody);
    _logResponse(response);
    return response;
  }

  // PATCH Request helper
  Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();
    final jsonBody = jsonEncode(body);
    if (kDebugMode) {
      debugPrint("ApiService PATCH $uri");
    }
    final response = await http.patch(uri, headers: headers, body: jsonBody);
    _logResponse(response);
    return response;
  }

  // DELETE Request helper
  Future<http.Response> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();
    if (kDebugMode) {
      debugPrint("ApiService DELETE $uri");
    }
    final response = await http.delete(uri, headers: headers);
    _logResponse(response);
    return response;
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

  static Future getToken() async {}
}
