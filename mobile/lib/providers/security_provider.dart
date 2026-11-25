import 'package:flutter/material.dart';
import '../services/security_service.dart';

class SecurityProvider with ChangeNotifier {
  final SecurityService _securityService = SecurityService();

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

  SecurityProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      _isBiometricsAvailable = await _securityService.isBiometricsAvailable();
      _isBiometricsEnabled = await _securityService.isBiometricsEnabled();
      _isScreenSecurityEnabled = await _securityService.isScreenSecurityEnabled();

      // Apply FLAG_SECURE if screen security is enabled
      await _securityService.applyScreenSecurity(_isScreenSecurityEnabled);

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
