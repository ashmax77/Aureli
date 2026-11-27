import 'dart:async';
import 'dart:convert';

import 'package:aureli/providers/auth_provider.dart';
import 'package:aureli/services/api_service.dart';
import 'package:aureli/services/auth_service.dart';
import 'package:aureli/services/snapshot_cache_service.dart';
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

/// Signing in or up "succeeds" instantly, as it does once Firebase has answered.
class _Gateway implements AuthGateway {
  User? _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> get userChanges => const Stream<User?>.empty();

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signIn(String email, String password) async => _user = _FakeUser();

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> signUp(String email, String password) async => _user = _FakeUser();
}

/// Only `/me` is scripted; the caller decides when (and how) the server answers it.
class _MeApi implements ApiService {
  _MeApi(this.me);

  final Future<http.Response> Function() me;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async =>
      path == '/me' ? me() : http.Response('[]', 200);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

http.Response _profile({required String status, double rate = 20}) => http.Response(
    jsonEncode({
      'id': 1,
      'firebaseUid': 'user-1',
      'email': 'a@b.c',
      'onboardingStatus': status,
      'savingsRatePercentage': rate,
    }),
    200);

void main() {
  setUp(installFakeSecureStorage);

  test('a new account sees onboarding at once, before the server answers', () async {
    final gate = Completer<http.Response>();
    final auth = AuthProvider(_Gateway(), _MeApi(() => gate.future));

    final signUp = auth.signUp('a@b.c', 'password1');
    await settle(100);

    expect(auth.needsOnboarding, isTrue);
    expect(auth.status, AuthStatus.ready);
    expect(auth.userModel?.email, 'a@b.c');

    // When the real profile arrives it replaces the provisional one.
    gate.complete(_profile(status: 'NOT_STARTED', rate: 12));
    expect(await signUp, isTrue);
    expect(auth.userModel?.id, 1);
    expect(auth.userModel?.savingsRatePercentage, 12);
  });

  test('a failed profile sync keeps onboarding available and caches nothing made up', () async {
    final auth = AuthProvider(
        _Gateway(), _MeApi(() async => http.Response('{"isOffline": true}', 503)));

    expect(await auth.signUp('a@b.c', 'password1'), isFalse);

    expect(auth.needsOnboarding, isTrue);
    expect(auth.status, AuthStatus.ready);
    expect(
      await SnapshotCacheService.read(userId: 'user-1', resource: 'profile'),
      isNull,
    );
  });

  test('signing in to an existing account does not guess: it waits for the real profile',
      () async {
    final gate = Completer<http.Response>();
    final auth = AuthProvider(_Gateway(), _MeApi(() => gate.future));

    final login = auth.login('a@b.c', 'password1');
    await settle(100);

    // Unknown whether this person finished onboarding, so no onboarding screen yet.
    expect(auth.userModel, isNull);
    expect(auth.needsOnboarding, isFalse);
    expect(auth.status, AuthStatus.syncingProfile);

    gate.complete(_profile(status: 'COMPLETED'));
    expect(await login, isTrue);
    expect(auth.needsOnboarding, isFalse);
    expect(auth.status, AuthStatus.ready);
  });
}
