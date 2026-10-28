import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorMapper {
  static String message(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'An account already exists with this email. Please sign in.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait or reset your password.';
        case 'user-disabled':
          return 'This account has been disabled. Contact support.';
        case 'operation-not-allowed':
          return 'Email sign-in is currently unavailable. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
      }
    }

    final lower = error.toString().toLowerCase();
    if (lower.contains('network')) {
      return 'Network error. Check your connection and try again.';
    }
    return error.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim();
  }
}
