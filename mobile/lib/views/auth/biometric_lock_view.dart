import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/security_provider.dart';
import '../../providers/auth_provider.dart';

class BiometricLockView extends StatefulWidget {
  const BiometricLockView({super.key});

  @override
  State<BiometricLockView> createState() => _BiometricLockViewState();
}

class _BiometricLockViewState extends State<BiometricLockView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAuth();
    });
  }

  Future<void> _triggerAuth() async {
    final secProvider = Provider.of<SecurityProvider>(context, listen: false);
    await secProvider.authenticateAndUnlock();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    Provider.of<SecurityProvider>(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Security Icon with glowing effect
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF147D64).withValues(alpha: 0.15),
                    border: Border.all(
                        color: const Color(0xFF147D64).withValues(alpha: 0.5),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF147D64).withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Color(0xFF147D64),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  "Aureli App Locked",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  "Biometric verification required to access your financial records and balance details.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const Spacer(),

                // Unlock Button
                ElevatedButton(
                  onPressed: () => _triggerAuth(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF147D64),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Unlock App",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sign Out Fallback Button
                TextButton(
                  onPressed: () {
                    authProvider.logout();
                  },
                  child: const Text(
                    "Log Out of Account",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      color: Color(0xFFCD5C52),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
