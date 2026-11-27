import 'dart:async';
import 'dart:convert';

import 'package:aureli/providers/auth_provider.dart';
import 'package:aureli/services/api_service.dart';
import 'package:aureli/services/auth_service.dart';
import 'package:aureli/widgets/email_verification_banner.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException, User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'helpers/fake_server_api.dart';

class _FakeUser implements User {
  @override
  String get uid => 'user-1';

  @override
  String? get email => 'a@b.c';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A gateway whose verification state and replies the test controls.
class _Gateway implements AuthGateway {
  _Gateway({this.verified = false});

  bool verified;
  User? _user;
  int sent = 0;
  int reloads = 0;
  Future<void> Function() onSend = () async {};
  Future<bool> Function()? onReload;
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
    _user = null;
    _changes.add(null);
  }

  @override
  bool get isEmailVerified => verified;

  @override
  Future<void> sendEmailVerification() async {
    sent++;
    await onSend();
  }

  @override
  Future<bool> reloadEmailVerified() async {
    reloads++;
    return onReload == null ? verified : onReload!();
  }
}

class _MeApi implements ApiService {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthProvider _auth(_Gateway gateway) => AuthProvider(gateway, _MeApi());

void main() {
  setUp(installFakeSecureStorage);

  group('sign-up', () {
    test('sends a verification email and asks for confirmation', () async {
      final gateway = _Gateway();
      final auth = _auth(gateway);

      expect(await auth.signUp('a@b.c', 'password1'), isTrue);
      await settle(50);

      expect(gateway.sent, 1);
      expect(auth.needsEmailVerification, isTrue);
      expect(auth.showVerificationBanner, isTrue);
      expect(auth.verificationEmailSent, isTrue);
    });

    test('does not wait for the email: onboarding still appears at once', () async {
      final gateway = _Gateway();
      final slowEmail = Completer<void>();
      gateway.onSend = () => slowEmail.future;
      final auth = _auth(gateway);

      final signUp = auth.signUp('a@b.c', 'password1');
      expect(await signUp.timeout(const Duration(seconds: 2)), isTrue);

      expect(auth.needsOnboarding || auth.userModel != null, isTrue);
      expect(auth.verificationEmailSent, isFalse);
      slowEmail.complete();
      await settle(50);
      expect(auth.verificationEmailSent, isTrue);
    });

    test('a failed email never fails the sign-up, and Resend can recover', () async {
      final gateway = _Gateway();
      gateway.onSend = () async => throw Exception('network');
      final auth = _auth(gateway);

      expect(await auth.signUp('a@b.c', 'password1'), isTrue);
      await settle(50);
      expect(auth.verificationEmailSent, isFalse);
      expect(auth.showVerificationBanner, isTrue);

      gateway.onSend = () async {};
      expect(await auth.sendVerificationEmail(), isNull);
      expect(auth.verificationEmailSent, isTrue);
      expect(gateway.sent, 2);
    });
  });

  group('signing in', () {
    test('an unverified existing account is reminded but not emailed on its own', () async {
      final gateway = _Gateway(verified: false);
      final auth = _auth(gateway);

      await auth.login('a@b.c', 'password1');

      expect(auth.needsEmailVerification, isTrue);
      expect(gateway.sent, 0);
      expect(auth.verificationEmailSent, isFalse);
    });

    test('a verified account sees no reminder', () async {
      final gateway = _Gateway(verified: true);
      final auth = _auth(gateway);

      await auth.login('a@b.c', 'password1');

      expect(auth.needsEmailVerification, isFalse);
      expect(auth.showVerificationBanner, isFalse);
    });

    test('nothing is shown while signed out', () {
      expect(_auth(_Gateway()).needsEmailVerification, isFalse);
    });
  });

  group('resending', () {
    test('asking twice while one is in flight sends one email', () async {
      final gateway = _Gateway();
      final slow = Completer<void>();
      gateway.onSend = () => slow.future;
      final auth = _auth(gateway);
      await auth.login('a@b.c', 'password1');

      final first = auth.sendVerificationEmail();
      final second = auth.sendVerificationEmail();
      slow.complete();
      await Future.wait([first, second]);

      expect(gateway.sent, 1);
      expect(auth.isSendingVerification, isFalse);
    });

    test('Firebase rate limiting becomes a friendly message', () async {
      final gateway = _Gateway();
      gateway.onSend = () async => throw FirebaseAuthException(code: 'too-many-requests');
      final auth = _auth(gateway);
      await auth.login('a@b.c', 'password1');

      expect(
        await auth.sendVerificationEmail(),
        'Please wait a moment before asking for another email.',
      );
      expect(auth.isSendingVerification, isFalse);
      expect(auth.verificationEmailSent, isFalse);
    });

    test('a verified account is not emailed again', () async {
      final gateway = _Gateway(verified: true);
      final auth = _auth(gateway);
      await auth.login('a@b.c', 'password1');

      expect(await auth.sendVerificationEmail(), isNull);
      expect(gateway.sent, 0);
    });
  });

  group('checking', () {
    test('the reminder goes away once the link has been opened', () async {
      final gateway = _Gateway();
      final auth = _auth(gateway);
      await auth.login('a@b.c', 'password1');
      expect(auth.showVerificationBanner, isTrue);

      gateway.verified = true;
      expect(await auth.refreshEmailVerification(), isTrue);

      expect(auth.needsEmailVerification, isFalse);
      expect(auth.showVerificationBanner, isFalse);
    });

    test('still unverified reports false and keeps the reminder', () async {
      final auth = _auth(_Gateway());
      await auth.login('a@b.c', 'password1');

      expect(await auth.refreshEmailVerification(), isFalse);
      expect(auth.needsEmailVerification, isTrue);
    });

    test('a check that cannot reach Firebase reports null and changes nothing', () async {
      final gateway = _Gateway();
      gateway.onReload = () async => throw Exception('offline');
      final auth = _auth(gateway);
      await auth.login('a@b.c', 'password1');

      expect(await auth.refreshEmailVerification(), isNull);
      expect(auth.needsEmailVerification, isTrue);
    });

    test('a check that finishes after sign-out does not resurrect state', () async {
      final gateway = _Gateway();
      final slow = Completer<bool>();
      gateway.onReload = () => slow.future;
      final auth = _auth(gateway);
      await auth.login('a@b.c', 'password1');

      final check = auth.refreshEmailVerification();
      await auth.logout();
      await settle(50);
      slow.complete(true);

      expect(await check, isNull);
      expect(auth.needsEmailVerification, isFalse);
    });
  });

  group('dismissing', () {
    test('hides the reminder for the session but the account stays unverified', () async {
      final auth = _auth(_Gateway());
      await auth.login('a@b.c', 'password1');

      auth.dismissVerificationBanner();

      expect(auth.showVerificationBanner, isFalse);
      expect(auth.needsEmailVerification, isTrue);
    });

    test('signing out forgets the dismissal and the sent flag', () async {
      final gateway = _Gateway();
      final auth = _auth(gateway);
      await auth.signUp('a@b.c', 'password1');
      await settle(50);
      auth.dismissVerificationBanner();

      await auth.logout();
      await settle(50);
      expect(auth.needsEmailVerification, isFalse);

      await auth.login('a@b.c', 'password1');
      expect(auth.showVerificationBanner, isTrue);
      expect(auth.verificationEmailSent, isFalse);
    });
  });

  group('banner', () {
    Future<void> show(WidgetTester tester, AuthProvider auth) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(
            home: Scaffold(body: Column(children: [EmailVerificationBanner()])),
          ),
        ),
      );
    }

    Future<AuthProvider> signedIn(WidgetTester tester, _Gateway gateway) async {
      final auth = _auth(gateway);
      await tester.runAsync(() async {
        await auth.login('a@b.c', 'password1');
        await settle(50);
      });
      return auth;
    }

    testWidgets('is absent for a verified account', (tester) async {
      final auth = await signedIn(tester, _Gateway(verified: true));
      await show(tester, auth);

      expect(find.text('Verify your email'), findsNothing);
    });

    testWidgets('names the address and offers both actions', (tester) async {
      final auth = await signedIn(tester, _Gateway());
      await show(tester, auth);

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('a@b.c'), findsOneWidget);
      expect(find.text('Resend email'), findsOneWidget);
      expect(find.text("I've verified"), findsOneWidget);
    });

    testWidgets('Resend emails the user and confirms it', (tester) async {
      final gateway = _Gateway();
      final auth = await signedIn(tester, gateway);
      await show(tester, auth);

      await tester.tap(find.text('Resend email'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(gateway.sent, 1);
      expect(find.text('Verification email sent to a@b.c.'), findsOneWidget);
    });

    testWidgets("I've verified removes the reminder once the link was opened",
        (tester) async {
      final gateway = _Gateway();
      final auth = await signedIn(tester, gateway);
      await show(tester, auth);

      gateway.verified = true;
      await tester.tap(find.text("I've verified"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Verify your email'), findsNothing);
      expect(find.text('Email verified. Thank you!'), findsOneWidget);
    });

    testWidgets("I've verified says so when the link has not been opened yet",
        (tester) async {
      final auth = await signedIn(tester, _Gateway());
      await show(tester, auth);

      await tester.tap(find.text("I've verified"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('Not verified yet'), findsOneWidget);
    });

    testWidgets("I've verified says so when it cannot check", (tester) async {
      final gateway = _Gateway();
      gateway.onReload = () async => throw Exception('offline');
      final auth = await signedIn(tester, gateway);
      await show(tester, auth);

      await tester.tap(find.text("I've verified"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining("Couldn't check"), findsOneWidget);
      expect(find.text('Verify your email'), findsOneWidget);
    });

    testWidgets('can be dismissed', (tester) async {
      final auth = await signedIn(tester, _Gateway());
      await show(tester, auth);

      await tester.tap(find.byTooltip('Remind me later'));
      await tester.pump();

      expect(find.text('Verify your email'), findsNothing);
    });

    testWidgets('fits a 320 px wide phone without overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final gateway = _Gateway();
      final auth = await signedIn(tester, gateway);
      await tester.runAsync(() => auth.sendVerificationEmail());
      await show(tester, auth);

      expect(tester.takeException(), isNull);
      expect(find.text('Resend email'), findsOneWidget);
    });
  });
}
