import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream of auth state changes
  Stream<User?> get userChanges => _auth.userChanges();

  // Current authenticated user
  User? get currentUser => _auth.currentUser;

  // Sign in with Email and Password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } catch (e) {
      debugPrint("AuthService signIn failed: $e");
      rethrow;
    }
  }

  // Sign up with Email and Password
  Future<UserCredential> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } catch (e) {
      debugPrint("AuthService signUp failed: $e");
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint("AuthService signOut failed: $e");
      rethrow;
    }
  }

  // Get current ID Token (JWT)
  Future<String?> getIdToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await user.getIdToken(true);
      }
      return null;
    } catch (e) {
      debugPrint("AuthService getIdToken failed: $e");
      return null;
    }
  }
}
