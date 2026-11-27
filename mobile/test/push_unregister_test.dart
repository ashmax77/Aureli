import 'dart:async';
import 'dart:convert';

import 'package:aureli/providers/auth_provider.dart';
import 'package:aureli/services/api_service.dart';
import 'package:aureli/services/auth_service.dart';
import 'package:aureli/services/push_token_service.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/fake_server_api.dart';

class _FakeUser implements User {
  @override
  String get uid => 'user-1';

  @override
  String? get email => 'a@b.c';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records, in order, what sign-out does.
class _Events {
  final List<String> log = [];
}

class _Gateway implements AuthGateway {
  _Gateway(this.events);

  final _Events events;
  User? _user;
  final _changes = StreamController<User?>.broadcast();

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> get userChanges => _changes.stream;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signIn(String email, String password) async => _user = _FakeUser();

  @override
  Future<void> signUp(String email, String password) async => _user = _FakeUser();

  @override
  Future<void> signOut() async {
    events.log.add('signOut');
    _user = null;
    _changes.add(null);
  }

  @override
  bool get isEmailVerified => true;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> reloadEmailVerified() async => true;
}

class _Api implements ApiService {
  _Api(this.events, this.gateway);

  final _Events events;
  final _Gateway gateway;
  Future<http.Response> Function(Map<String, dynamic> body) onUnregister =
      (_) async => http.Response('', 204);
  bool? signedInWhenUnregistering;
  String? unregisterPath;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async =>
      path == '/me'
          ? http.Response(
              jsonEncode({
                'id': 1,
                'firebaseUid': 'user-1',
                'email': 'a@b.c',
                'onboardingStatus': 'COMPLETED',
                'savingsRatePercentage': 20,
              }),
              200)
          : http.Response('[]', 200);

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    unregisterPath = path;
    signedInWhenUnregistering = gateway.currentUser != null;
    events.log.add('unregister:${body['fcmToken']}');
    return onUnregister(body);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tokens implements PushTokenSource {
  _Tokens(this.events);

  final _Events events;
  String? token = 'token-1';
  Future<void> Function() onDiscard = () async {};

  @override
  Future<String?> currentToken() async => token;

  @override
  Future<void> discardToken() async {
    events.log.add('discard');
    await onDiscard();
  }
}

class _Rig {
  _Rig({Duration timeout = const Duration(milliseconds: 150), bool withPush = true}) {
    gateway = _Gateway(events);
    api = _Api(events, gateway);
    tokens = _Tokens(events);
    auth = AuthProvider(
      gateway,
      api,
      pushTokens: withPush ? tokens : null,
      unregisterTimeout: timeout,
    );
  }

  final events = _Events();
  late final _Gateway gateway;
  late final _Api api;
  late final _Tokens tokens;
  late final AuthProvider auth;

  Future<void> signIn() async {
    await auth.login('a@b.c', 'password1');
    await settle(30);
  }
}

void main() {
  setUp(installFakeSecureStorage);

  test('signing out tells the backend to forget this phone, while still signed in', () async {
    final rig = _Rig();
    await rig.signIn();

    await rig.auth.logout();

    expect(rig.api.unregisterPath, '/me/fcm-token/unregister');
    expect(rig.api.signedInWhenUnregistering, isTrue,
        reason: 'the request needs the account to still be signed in');
    expect(rig.events.log, ['unregister:token-1', 'signOut']);
  });

  test('when the backend confirms, the token is left alone', () async {
    final rig = _Rig();
    await rig.signIn();

    await rig.auth.logout();
    await settle(50);

    expect(rig.events.log, isNot(contains('discard')));
  });

  test('a backend that refuses still lets the user sign out, and the token is discarded',
      () async {
    final rig = _Rig();
    rig.api.onUnregister = (_) async => http.Response('boom', 500);
    await rig.signIn();

    await rig.auth.logout();
    await settle(50);

    expect(rig.events.log, ['unregister:token-1', 'signOut', 'discard']);
  });

  test('a backend that never answers cannot hold sign-out hostage', () async {
    final rig = _Rig(timeout: const Duration(milliseconds: 100));
    final neverAnswers = Completer<http.Response>();
    rig.api.onUnregister = (_) => neverAnswers.future;
    await rig.signIn();

    await rig.auth.logout().timeout(const Duration(seconds: 3));
    await settle(50);

    expect(rig.events.log, ['unregister:token-1', 'signOut', 'discard']);
  });

  test('a request that throws (offline) still signs out and discards the token', () async {
    final rig = _Rig();
    rig.api.onUnregister = (_) async => throw Exception('socket closed');
    await rig.signIn();

    await rig.auth.logout();
    await settle(50);

    expect(rig.events.log, ['unregister:token-1', 'signOut', 'discard']);
  });

  test('with no token to read, nothing is sent but the token is still discarded', () async {
    final rig = _Rig();
    rig.tokens.token = null;
    await rig.signIn();

    await rig.auth.logout();
    await settle(50);

    expect(rig.api.unregisterPath, isNull);
    expect(rig.events.log, ['signOut', 'discard']);
  });

  test('a discard that fails never breaks sign-out', () async {
    final rig = _Rig();
    rig.api.onUnregister = (_) async => http.Response('boom', 500);
    rig.tokens.onDiscard = () async => throw Exception('offline');
    await rig.signIn();

    await rig.auth.logout();
    await settle(50);

    expect(rig.gateway.currentUser, isNull);
  });

  test('without push support (no token source) sign-out just signs out', () async {
    final rig = _Rig(withPush: false);
    await rig.signIn();

    await rig.auth.logout();

    expect(rig.events.log, ['signOut']);
    expect(rig.api.unregisterPath, isNull);
  });

  test('signing out when nobody is signed in sends nothing', () async {
    final rig = _Rig();

    await rig.auth.logout();

    expect(rig.api.unregisterPath, isNull);
    expect(rig.events.log, ['signOut']);
  });
}
