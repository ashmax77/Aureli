import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// This phone's push-notification identity. Kept behind an interface so the auth logic can
/// be tested without Firebase.
abstract interface class PushTokenSource {
  /// The token the backend knows this installation by, or null if there isn't one.
  Future<String?> currentToken();

  /// Invalidates the token at Firebase, so nothing can be delivered to it any more.
  /// The next [currentToken] call hands out a fresh one.
  Future<void> discardToken();
}

class FirebasePushTokenSource implements PushTokenSource {
  FirebasePushTokenSource({FirebaseMessaging? messaging}) : _messaging = messaging;

  final FirebaseMessaging? _messaging;

  // Resolved on use so creating this object never touches Firebase.
  FirebaseMessaging get _fcm => _messaging ?? FirebaseMessaging.instance;

  @override
  Future<String?> currentToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      if (kDebugMode) debugPrint('PushTokenSource currentToken failed: $e');
      return null;
    }
  }

  @override
  Future<void> discardToken() => _fcm.deleteToken();
}
