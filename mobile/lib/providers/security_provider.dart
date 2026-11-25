import 'package:flutter/foundation.dart';
import '../services/security_service.dart';

class SecurityProvider with ChangeNotifier {
  final SecurityService _securityService;

  bool _isBiometricsEnabled = false;
  bool _isScreenSecurityEnabled = true;
  bool _isBiometricsAvailable = false;
  bool _isAppUnlocked = false;
  bool _isInitialized = false;

  /// False until the stored security preferences have been loaded. Routing must not
  /// show protected screens before this is true, or the biometric lock can be skipped.
  bool get isInitialized => _isInitialized;

  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get isScreenSecurityEnabled => _isScreenSecurityEnabled;
  bool get isBiometricsAvailable => _isBiometricsAvailable;
  bool get isAppUnlocked => _isAppUnlocked;
  SecurityService get securityService => _securityService;

  SecurityProvider({SecurityService? securityService})
      : _securityService = securityService ?? SecurityService() {
    _init();
  }

  Future<void> _init() async {
    try {
      // The lock preference is the security-critical read, so it gets its own handling:
      // if it cannot be read we do not know whether the user enabled the lock, and the
      // safe assumption is that they did. (_isAppUnlocked stays false, so the lock screen shows.)
      try {
        _isBiometricsEnabled = await _securityService.isBiometricsEnabled();
      } catch (e) {
        _isBiometricsEnabled = true;
        if (kDebugMode) debugPrint('Failed to load biometric lock preference, failing closed: $e');
      }

      // These only affect convenience / hardening, not whether the lock applies, and each
      // has a safe default, so a failure here must not change the lock decision.
      try {
        _isBiometricsAvailable = await _securityService.isBiometricsAvailable();
      } catch (e) {
        _isBiometricsAvailable = false;
        if (kDebugMode) debugPrint('Failed to check biometric availability: $e');
      }

      try {
        _isScreenSecurityEnabled = await _securityService.isScreenSecurityEnabled();
      } catch (e) {
        _isScreenSecurityEnabled = true; // default to the more protective setting
        if (kDebugMode) debugPrint('Failed to load screen security preference: $e');
      }

      // Apply FLAG_SECURE if screen security is enabled
      try {
        await _securityService.applyScreenSecurity(_isScreenSecurityEnabled);
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to apply screen security: $e');
      }

      // If biometrics are not enabled, app starts unlocked
      if (!_isBiometricsEnabled) {
        _isAppUnlocked = true;
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> authenticateAndUnlock() async {
    if (!_isBiometricsEnabled) {
      _isAppUnlocked = true;
      notifyListeners();
      return true;
    }

    final success = await _securityService.authenticateUser(
      localizedReason: 'Unlock Aureli to access your financial records',
    );

    if (success) {
      _isAppUnlocked = true;
      notifyListeners();
    }
    return success;
  }

  void lockApp() {
    if (_isBiometricsEnabled) {
      _isAppUnlocked = false;
      notifyListeners();
    }
  }

  Future<bool> toggleBiometrics(bool enable) async {
    if (enable) {
      // Prompt user to verify biometric capability before enabling
      final success = await _securityService.authenticateUser(
        localizedReason: 'Authenticate to enable Biometric Lock',
      );
      if (!success) return false;
    }

    await _securityService.setBiometricsEnabled(enable);
    _isBiometricsEnabled = enable;
    if (!enable) {
      _isAppUnlocked = true;
    }
    notifyListeners();
    return true;
  }

  Future<void> toggleScreenSecurity(bool enable) async {
    await _securityService.setScreenSecurityEnabled(enable);
    _isScreenSecurityEnabled = enable;
    notifyListeners();
  }
}
