import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around connectivity_plus so providers depend on a plain `Stream<bool>`
/// (easy to fake in tests). `true` means at least one network interface is up; it does
/// not prove the internet or the backend is reachable, so callers must still handle
/// failed requests.
class ConnectivityService {
  static Stream<bool> onlineChanges() => Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none))
      .distinct();
}
