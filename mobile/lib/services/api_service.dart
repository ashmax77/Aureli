import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_metrics.dart';

class ApiService {
  final AuthGateway _authService;
  final http.Client _client;
  final ApiMetrics metrics = ApiMetrics();

  // Optimized timeouts: 45s for standard requests
  static const Duration _requestTimeout = Duration(seconds: 45);

  // A sleeping Render free-tier container can take about a minute and a half to answer
  // its first request, so the wake-up ping gets a longer window than normal requests.
  static const Duration _warmUpTimeout = Duration(seconds: 100);
  bool _serverWarm = false;
  Future<void>? _warmUp;

  // In-flight GET request deduplication cache to minimize redundant mobile bandwidth consumption
  final Map<String, Future<http.Response>> _inFlightGetRequests = {};

  // Base URL pointing to Render Spring Boot backend.
  // Override at build time: flutter run --dart-define=BASE_URL=https://your-server.com/api/v1
  static const String _defaultBaseUrl = 'https://aureli-9twx.onrender.com/api/v1';
  static String get baseUrl => const String.fromEnvironment('BASE_URL', defaultValue: _defaultBaseUrl);
  static String get _rootUrl => baseUrl.replaceAll('/api/v1', '/api');

  ApiService(this._authService, {http.Client? client})
      : _client = client ?? http.Client();

  String? get currentUserId => _authService.currentUser?.uid;

  /// Pings the health endpoint so a sleeping Render free-tier container starts waking up.
  /// Only one ping is in flight at a time. Requests made before the server has answered
  /// wait for it (see [_awaitServer]), so concurrent first requests share one wake-up
  /// instead of each timing out against a cold server.
  void wakeUpServer() {
    if (_serverWarm || _warmUp != null) return;
    try {
      final uri = Uri.parse('$_rootUrl/health');
      _warmUp = _client.get(uri).timeout(_warmUpTimeout).then((response) {
        _serverWarm = response.statusCode < 500;
        if (kDebugMode) debugPrint("ApiService: Server warm-up responded with ${response.statusCode}");
      }).catchError((e) {
        if (kDebugMode) debugPrint("ApiService: Server warm-up ping: $e");
      }).whenComplete(() {
        // A failed ping must not block later requests; the next one tries again.
        if (!_serverWarm) _warmUp = null;
      });
    } catch (_) {
      _warmUp = null;
    }
  }

  /// The server may have gone back to sleep (timeout or gateway error): forget that it
  /// was warm and ping again.
  void _markServerCold() {
    _serverWarm = false;
    _warmUp = null;
    wakeUpServer();
  }

  /// Waits for the wake-up ping before sending a request, so requests made during a cold
  /// start all queue behind one ping rather than each timing out separately.
  Future<void> _awaitServer() async {
    if (_serverWarm) return;
    wakeUpServer();
    await _warmUp;
  }

  /// Optimized headers with explicit gzip/deflate compression support
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function(Map<String, String> headers) requestFn, {
    String methodName = 'REQUEST',
    Uri? uri,
  }) async {
    await _awaitServer();
    Map<String, String> headers = await _getHeaders();
    try {
      metrics.recordRequestAttempt();
      var response = await requestFn(headers).timeout(_requestTimeout);
      _logResponse(response);

      // 1. Handle 401 Unauthorized: Force refresh Firebase token and retry once
      if (response.statusCode == 401) {
        if (kDebugMode) debugPrint("ApiService: Received 401 for $methodName $uri. Refreshing token...");
        final newToken = await _authService.getIdToken(true);
        if (newToken != null) {
          metrics.recordRetry();
          headers = {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Accept-Encoding': 'gzip, deflate',
            'Authorization': 'Bearer $newToken',
          };
          response = await requestFn(headers).timeout(_requestTimeout);
          _logResponse(response);
        }
      }

      // Only retry ordinary GETs. Retrying writes can duplicate user actions,
      // while CSV exports can resend an unnecessarily large response.
      final canRetryTransient = methodName == 'GET' &&
          !(uri?.path.endsWith('/export') ?? false);

      // Handle transient gateway failures with one bounded retry.
      if (canRetryTransient &&
          (response.statusCode == 504 ||
              response.statusCode == 502 ||
              response.statusCode == 503)) {
              metrics.recordRetry();
        if (kDebugMode) {
          debugPrint(
              "ApiService: Received ${response.statusCode} for $methodName $uri. Retrying once...");
        }
        _markServerCold();
        await Future.delayed(const Duration(seconds: 3));
        response = await requestFn(headers).timeout(_requestTimeout);
        _logResponse(response);
      }

      return response;
    } on TimeoutException {
      final canRetryTimeout = methodName == 'GET' &&
          !(uri?.path.endsWith('/export') ?? false);
      if (!canRetryTimeout) {
        return http.Response(
          jsonEncode({'error': 'Server connection timed out.', 'isTimeout': true}),
          504,
        );
      }

      if (kDebugMode) {
        debugPrint(
            "ApiService $methodName Timeout for $uri. Retrying once...");
      }
      try {
        metrics.recordRetry();
        _markServerCold();
        await Future.delayed(const Duration(seconds: 2));
        final response = await requestFn(headers).timeout(_requestTimeout);
        _logResponse(response);
        return response;
      } catch (e) {
        if (kDebugMode) debugPrint("ApiService $methodName Double Timeout for $uri: $e");
        return http.Response(
          jsonEncode({'error': 'Server connection timed out. Falling back to cached data.', 'isTimeout': true}),
          504,
        );
      }
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint("ApiService $methodName Network SocketException for $uri: $e");
      return http.Response(
        jsonEncode({'error': 'Network connection unreachable. Displaying cached data.', 'isOffline': true}),
        503,
      );
    } catch (e) {
      if (kDebugMode) debugPrint("ApiService $methodName Error: $e");
      rethrow;
    }
  }

  // GET Request helper with in-flight deduplication
  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final requestKey = uri.toString();

    // If an identical GET request is currently traversing the network, coalesce to save bandwidth
    if (_inFlightGetRequests.containsKey(requestKey)) {
      metrics.recordInFlightGetHit();
      if (kDebugMode) debugPrint("ApiService: Coalescing redundant GET $uri");
      return _inFlightGetRequests[requestKey]!;
    }

    if (kDebugMode) debugPrint("ApiService GET $uri");
    final future = _executeWithRetry(
      (headers) => _client.get(uri, headers: headers),
      methodName: 'GET',
      uri: uri,
    );

    _inFlightGetRequests[requestKey] = future;
    future.whenComplete(() => _inFlightGetRequests.remove(requestKey));
    return future;
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
    metrics.recordResponseBytes(response.bodyBytes.length);
    if (kDebugMode) {
      debugPrint("ApiService Response ${response.statusCode} | Content-Length: ${response.body.length}");
    }
  }
}
