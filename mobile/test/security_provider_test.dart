import 'package:aureli/providers/security_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/local_auth'),
      (call) async =>
          call.method == 'getAvailableBiometrics' ? <String>['fingerprint'] : true,
    );
  });

  Future<void> settle(SecurityProvider p) async {
    for (var i = 0; i < 50 && !p.isInitialized; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('is not initialized (router must wait) until preferences are loaded', () async {
    SharedPreferences.setMockInitialValues({'security_biometrics_enabled': true});
    final provider = SecurityProvider();

    // Before init the lock flags are still defaults, so the router must not trust them.
    expect(provider.isInitialized, isFalse);

    await settle(provider);
    expect(provider.isInitialized, isTrue);
    expect(provider.isBiometricsEnabled, isTrue);
    expect(provider.isAppUnlocked, isFalse, reason: 'biometric users start locked');
  });

  test('starts unlocked when biometrics are not enabled', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = SecurityProvider();
    await settle(provider);

    expect(provider.isInitialized, isTrue);
    expect(provider.isBiometricsEnabled, isFalse);
    expect(provider.isAppUnlocked, isTrue);
  });

  test('lockApp only locks when biometrics are enabled', () async {
    SharedPreferences.setMockInitialValues({});
    final off = SecurityProvider();
    await settle(off);
    off.lockApp();
    expect(off.isAppUnlocked, isTrue);

    SharedPreferences.setMockInitialValues({'security_biometrics_enabled': true});
    final on = SecurityProvider();
    await settle(on);
    expect(await on.authenticateAndUnlock(), isTrue);
    expect(on.isAppUnlocked, isTrue);
    on.lockApp();
    expect(on.isAppUnlocked, isFalse);
  });
}
