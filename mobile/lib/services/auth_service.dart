import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

abstract interface class AuthGateway {
  Stream<User?> get userChanges;
  User? get currentUser;
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
  Future<String?> getIdToken([bool forceRefresh = false]);
  Future<void> sendPasswordResetEmail(String email);
}

class AuthService implements AuthGateway {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  // Stream of auth state changes
  @override
  Stream<User?> get userChanges => _auth.userChanges();

  // Current authenticated user
  @override
  User? get currentUser => _auth.currentUser;

  // Sign in with Email and Password
  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      if (kDebugMode) debugPrint("AuthService signIn failed: $e");
      rethrow;
    }
  }

  // Sign up with Email and Password
  @override
  Future<void> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      if (kDebugMode) debugPrint("AuthService signUp failed: $e");
      rethrow;
    }
  }

  // Sign out
  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint("AuthService signOut failed: $e");
      rethrow;
    }
  }

  // Get current ID Token (JWT)
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await user.getIdToken(forceRefresh);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint("AuthService getIdToken failed: $e");
      return null;
    }
  }

  // Send Password Reset Email
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      if (kDebugMode) debugPrint("AuthService sendPasswordResetEmail failed: $e");
      rethrow;
    }
  }
}
