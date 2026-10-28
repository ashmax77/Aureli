import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aureli/services/auth_error_mapper.dart';

void main() {
  test('maps invalid credentials without exposing Firebase internals', () {
    final error = FirebaseAuthException(code: 'invalid-credential');

    expect(AuthErrorMapper.message(error), 'Invalid email or password.');
  });

  test('maps network failures to a retryable message', () {
    final error = FirebaseAuthException(code: 'network-request-failed');

    expect(
      AuthErrorMapper.message(error),
      'Network error. Check your connection and try again.',
    );
  });

  test('maps unknown errors without crashing', () {
    expect(AuthErrorMapper.message(StateError('unexpected')), contains('unexpected'));
  });
}
