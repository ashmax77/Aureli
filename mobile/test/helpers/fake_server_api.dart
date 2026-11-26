import 'dart:convert';

import 'package:aureli/services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// In-memory stand-in for the backend plus a switch to simulate losing the network.
class FakeServerApi implements ApiService {
  FakeServerApi({this.userId = 'user-1'});

  final String userId;

  /// When false every call behaves like a dropped connection (what ApiService returns on SocketException).
  bool online = true;

  /// When true POSTs get a server error while GETs still work.
  bool failPosts = false;

  /// Number of upcoming POSTs that get a server error (then POSTs succeed again).
  int failPostsRemaining = 0;

  /// When true the server stores the transaction but the response never reaches the
  /// client (what a timeout after commit looks like).
  bool dropResponseAfterCommit = false;

  /// Runs at the start of every POST (lets a test act "while a sync is in flight").
  Future<void> Function()? beforePost;

  final List<Map<String, dynamic>> serverTransactions = [];
  int _nextId = 1;
  int getCount = 0;
  int postCount = 0;

  @override
  String? get currentUserId => userId;

  http.Response _offline() => http.Response(
        jsonEncode({'error': 'Network connection unreachable.', 'isOffline': true}),
        503,
      );

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async {
    getCount++;
    if (!online) return _offline();
    if (path == '/transactions') {
      final start = queryParams?['startDate'];
      final end = queryParams?['endDate'];
      final rows = serverTransactions.where((t) {
        final d = t['transactionDate'] as String;
        return (start == null || d.compareTo(start) >= 0) &&
            (end == null || d.compareTo(end) <= 0);
      }).toList()
        ..sort((a, b) => (b['transactionDate'] as String).compareTo(a['transactionDate'] as String));
      return http.Response(jsonEncode({'content': rows, 'last': true}), 200);
    }
    if (path == '/categories') {
      return http.Response(jsonEncode([]), 200);
    }
    return http.Response('{}', 404);
  }

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    postCount++;
    if (beforePost != null) await beforePost!();
    if (!online) return _offline();
    if (failPosts || failPostsRemaining > 0) {
      if (failPostsRemaining > 0) failPostsRemaining--;
      return http.Response('{"message":"boom"}', 500);
    }
    if (path == '/transactions') {
      final requestId = body['clientRequestId'];
      final existing = serverTransactions.where((t) => t['clientRequestId'] == requestId);
      if (requestId != null && existing.isNotEmpty) {
        return http.Response(jsonEncode(existing.first), 201); // idempotent replay
      }
      final created = <String, dynamic>{
        'id': _nextId++,
        'clientRequestId': requestId,
        'amount': body['amount'],
        'type': body['type'],
        'categoryId': body['categoryId'],
        'categoryName': 'Cat${body['categoryId']}',
        'transactionDate': body['transactionDate'],
        'paymentMethod': body['paymentMethod'],
        'note': body['note'],
        'createdAt': DateTime.now().toUtc().toIso8601String().replaceAll('Z', ''),
      };
      serverTransactions.add(created);
      if (dropResponseAfterCommit) return _offline();
      return http.Response(jsonEncode(created), 201);
    }
    return http.Response('{}', 404);
  }

  /// When true PUT / DELETE get a server error with a message.
  bool failEdits = false;
  Map<String, dynamic>? lastPutBody;
  int putCount = 0;
  int deleteCount = 0;

  int? _idFrom(String path) => int.tryParse(path.split('/').last);

  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    putCount++;
    if (!online) return _offline();
    if (failEdits) return http.Response('{"message":"Edit rejected"}', 500);
    final index = serverTransactions.indexWhere((t) => t['id'] == _idFrom(path));
    if (index == -1) return http.Response('{"message":"Transaction not found"}', 404);
    lastPutBody = Map<String, dynamic>.from(body);
    final updated = Map<String, dynamic>.from(serverTransactions[index])
      ..addAll({
        'amount': body['amount'],
        'type': body['type'],
        'categoryId': body['categoryId'],
        'transactionDate': body['transactionDate'],
        'paymentMethod': body['paymentMethod'],
        'note': body['note'],
        'isSavingsEnabled': body['isSavingsEnabled'],
        'savingsRate': body['savingsRate'],
      });
    serverTransactions[index] = updated;
    return http.Response(jsonEncode(updated), 200);
  }

  @override
  Future<http.Response> delete(String path) async {
    deleteCount++;
    if (!online) return _offline();
    if (failEdits) return http.Response('{"message":"Delete rejected"}', 500);
    final before = serverTransactions.length;
    serverTransactions.removeWhere((t) => t['id'] == _idFrom(path));
    if (serverTransactions.length == before) {
      return http.Response('{"message":"Transaction not found"}', 404);
    }
    return http.Response('', 204);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Adds a server-side transaction dated today (so it shows in the current month).
void seedServerTransaction(
  FakeServerApi api, {
  required int id,
  double amount = 500,
  String note = 'groceries',
  String type = 'EXPENSE',
  int categoryId = 1,
  bool? isSavingsEnabled,
  double? savingsRate,
}) {
  final today = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  api.serverTransactions.add({
    'id': id,
    'amount': amount,
    'type': type,
    'categoryId': categoryId,
    'categoryName': 'Food',
    'transactionDate': '${today.year.toString().padLeft(4, '0')}-${two(today.month)}-${two(today.day)}',
    'paymentMethod': 'CASH',
    'note': note,
    'isSavingsEnabled': isSavingsEnabled,
    'savingsRate': savingsRate,
    'createdAt': '2026-01-01T00:00:00',
  });
}

/// Mocks the flutter_secure_storage channel with an in-memory map that survives provider
/// re-creation (like the real keystore survives an app restart).
Map<String, String> installFakeSecureStorage() {
  final store = <String, String>{};
  TestWidgetsFlutterBinding.ensureInitialized();
  TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = (call.arguments as Map?) ?? {};
      switch (call.method) {
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return store[args['key'] as String];
        case 'delete':
          store.remove(args['key'] as String);
          return null;
        case 'deleteAll':
          store.clear();
          return null;
      }
      return null;
    },
  );
  return store;
}

/// Lets queued async work (provider startup loads, fire-and-forget syncs) finish.
Future<void> settle([int ms = 60]) => Future<void>.delayed(Duration(milliseconds: ms));
