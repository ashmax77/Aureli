// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aureli/providers/auth_provider.dart';
import 'package:aureli/services/api_service.dart';
import 'package:aureli/services/auth_service.dart';
import 'package:aureli/views/auth/auth_view.dart';

class _SignedOutAuthGateway implements AuthGateway {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get userChanges => Stream<User?>.value(null);

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

void main() {
  testWidgets('auth screen renders without Firebase initialization',
      (WidgetTester tester) async {
    final gateway = _SignedOutAuthGateway();
    final apiService = ApiService(gateway);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(gateway, apiService),
        child: const MaterialApp(home: AuthView()),
      ),
    );
    await tester.pump();

    expect(find.text('Sign In'), findsNWidgets(2));
    expect(find.text('Email'), findsOneWidget);
  });
}
