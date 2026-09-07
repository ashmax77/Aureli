import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _keyBiometricsEnabled = 'security_biometrics_enabled';
  static const String _keyScreenSecurityEnabled = 'security_screen_protection_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if biometrics are supported and hardware is available.
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint("Biometrics availability check error: $e");
      }
      return false;
    }
  }

  /// Performs biometric authentication with localized prompt.
  Future<bool> authenticateUser({String localizedReason = 'Authenticate to access Aureli'}) async {
    try {
      final bool available = await isBiometricsAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allows fallback to passcode if biometrics fail/unavailable
        ),
      );
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint("Biometrics authentication error: $e");
      }
      return false;
    }
  }

  /// Retrieves whether biometric authentication is enabled in app preferences.
  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricsEnabled) ?? false;
  }

  /// Enables or disables biometric authentication preference.
  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricsEnabled, enabled);
  }

  /// Retrieves whether screen screenshot protection (FLAG_SECURE) is enabled in app preferences.
  Future<bool> isScreenSecurityEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyScreenSecurityEnabled) ?? true; // default enabled for financial security
  }

  /// Toggles and applies screen security flags.
  Future<void> setScreenSecurityEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyScreenSecurityEnabled, enabled);
    await applyScreenSecurity(enabled);
  }

  /// Applies Android task switcher / screenshot security window flags.
  Future<void> applyScreenSecurity([bool? forceState]) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final bool enabled = forceState ?? await isScreenSecurityEnabled();
      if (enabled) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint("FlutterWindowManager flag modification failed: $e");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error setting screen security flag: $e");
      }
    }
  }
}
