import 'dart:convert';

import 'package:http/http.dart' as http;

/// Shown when a write that needs the server (it can't be queued offline) hits a dead connection.
const String offlineWriteMessage =
    "You're offline. This change needs an internet connection - please try again once you're back online.";

/// Shown when the server did not answer in time.
const String timeoutWriteMessage =
    "The server took too long to respond. Check your connection and try again.";

/// ApiService turns SocketException / timeouts into synthetic 5xx responses carrying
/// `isOffline` / `isTimeout`; genuine server errors never have these flags.
bool isConnectivityFailure(http.Response response) =>
    _flag(response, 'isOffline') || _flag(response, 'isTimeout');

/// A user-facing explanation when [response] is a connection-level failure, else null
/// (so callers can fall back to the server's own error message).
String? connectivityFailureMessage(http.Response response) {
  if (_flag(response, 'isOffline')) return offlineWriteMessage;
  if (_flag(response, 'isTimeout')) return timeoutWriteMessage;
  return null;
}

bool _flag(http.Response response, String name) {
  if (response.statusCode < 500) return false;
  try {
    final body = jsonDecode(response.body);
    return body is Map && body[name] == true;
  } catch (_) {
    return false;
  }
}
