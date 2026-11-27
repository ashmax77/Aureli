import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aureli/services/api_service.dart';
import 'package:aureli/services/auth_service.dart';
import 'package:aureli/widgets/connecting_view.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _QuietGateway implements AuthGateway {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get userChanges => const Stream<User?>.empty();

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp(String email, String password) async {}
}

bool _isHealth(http.BaseRequest request) => request.url.path.endsWith('/health');

void main() {
  group('server wake-up', () {
    test('requests made during a cold start wait for one shared health ping', () async {
      final health = Completer<http.Response>();
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        if (_isHealth(request)) return health.future;
        return http.Response(jsonEncode([]), 200);
      });
      final api = ApiService(_QuietGateway(), client: client);

      api.wakeUpServer();
      final first = api.get('/categories');
      final second = api.get('/transactions');
      await pumpEventQueue();

      // Nothing but the single ping has reached the server yet.
      expect(paths.where(_isHealthPath), hasLength(1));
      expect(paths.where((p) => !_isHealthPath(p)), isEmpty);

      health.complete(http.Response('ok', 200));
      await Future.wait([first, second]);

      expect(paths.where(_isHealthPath), hasLength(1));
      expect(paths.where((p) => !_isHealthPath(p)), hasLength(2));
    });

    test('a failed ping is retried by the next request', () async {
      var healthCalls = 0;
      final client = MockClient((request) async {
        if (_isHealth(request)) {
          healthCalls++;
          if (healthCalls == 1) throw const SocketException('no network yet');
          return http.Response('ok', 200);
        }
        return http.Response(jsonEncode([]), 200);
      });
      final api = ApiService(_QuietGateway(), client: client);

      api.wakeUpServer();
      await pumpEventQueue();
      expect(healthCalls, 1);

      await api.get('/categories');

      expect(healthCalls, 2);
    });

    test('once the server has answered, requests do not ping again', () async {
      var healthCalls = 0;
      final client = MockClient((request) async {
        if (_isHealth(request)) {
          healthCalls++;
          return http.Response('ok', 200);
        }
        return http.Response(jsonEncode([]), 200);
      });
      final api = ApiService(_QuietGateway(), client: client);

      api.wakeUpServer();
      await api.get('/categories');
      await api.get('/transactions');
      await api.get('/budgets');

      expect(healthCalls, 1);
    });
  });

  group('ConnectingView', () {
    testWidgets('explains a long wait only after a few seconds', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ConnectingView()));

      expect(find.text('Connecting to Aureli...'), findsOneWidget);
      expect(find.byKey(const Key('slow-hint')), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('slow-hint')), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('slow-hint')), findsOneWidget);
      expect(find.textContaining('Waking up the server'), findsOneWidget);
    });

    testWidgets('does not throw when removed before the hint timer fires', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ConnectingView()));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 10));

      expect(tester.takeException(), isNull);
    });
  });
}

bool _isHealthPath(String path) => path.endsWith('/health');
