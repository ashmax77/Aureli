import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized encrypted storage service for sensitive financial data.
/// Uses Android Keystore / iOS Keychain under the hood via flutter_secure_storage.
/// Non-sensitive preferences (theme, etc.) should remain in SharedPreferences.
class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// Write a value to encrypted storage.
  static Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) debugPrint("SecureStorage write error for '$key': $e");
    }
  }

  /// Read a value from encrypted storage.
  static Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint("SecureStorage read error for '$key': $e");
      return null;
    }
  }

  /// Delete a specific key from encrypted storage.
  static Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint("SecureStorage delete error for '$key': $e");
    }
  }

  /// Delete all values from encrypted storage (e.g. on logout).
  static Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      if (kDebugMode) debugPrint("SecureStorage deleteAll error: $e");
    }
  }
}
