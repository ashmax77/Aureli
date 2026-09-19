import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/security_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_card.dart';
import '../notifications/notification_views.dart';
import '../guide/app_tutorial_guide.dart';

/// Reusable user profile avatar icon for AppBars.
/// Tapping it directs the user to the Profile page.
class UserProfileAvatarIcon extends StatelessWidget {
  const UserProfileAvatarIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final notifProvider = Provider.of<NotificationProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authProvider.firebaseUser;
    final photoUrl = user?.photoURL;
    final name = _getUserDisplayName(authProvider);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileView()),
          );
        },
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF147D64).withValues(alpha: 0.6), width: 1.5),
              ),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFF0B3B5A),
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
            if (notifProvider.unreadCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCD5C52),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F1621) : const Color(0xFFF4F6F9),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _getUserDisplayName(AuthProvider auth) {
  final user = auth.firebaseUser;
  if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
    return user.displayName!;
  }
  final email = auth.userModel?.email ?? user?.email ?? '';
  if (email.isNotEmpty) {
    final prefix = email.split('@').first;
    final parts = prefix.split(RegExp(r'[._]'));
    return parts.map((p) => p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '').join(' ');
  }
  return "Aureli User";
}

/// Profile screen matching the design mockup.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).fetchUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final notifProvider = Provider.of<NotificationProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authProvider.firebaseUser;
    final photoUrl = user?.photoURL;
    final displayName = _getUserDisplayName(authProvider);
    final email = authProvider.userModel?.email ?? user?.email ?? 'user@example.com';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Aureli",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white70 : const Color(0xFF334155)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 1. User Profile Picture & Info
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF147D64).withOpacity(0.5), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF147D64).withOpacity(0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: const Color(0xFF0B3B5A),
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Text(
                              initial,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 2. ACCOUNT & SECURITY Section
            _buildSectionHeader("ACCOUNT & SECURITY", isDark),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.account_balance_rounded,
                    iconColor: const Color(0xFF4C9FD1),
                    iconBg: const Color(0xFF0B3B5A).withValues(alpha: 0.3),
                    title: "Linked Accounts",
                    onTap: () {
                      _showComingSoonDialog(context, "Linked Accounts", "Multi-bank synchronization and account linking is coming in an upcoming release.");
                    },
                  ),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.security_rounded,
                    iconColor: const Color(0xFF4C9FD1),
                    iconBg: const Color(0xFF0B3B5A).withValues(alpha: 0.3),
                    title: "Security & Privacy",
                    onTap: () {
                      _showSecurityDialog(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 3. PREFERENCES Section
            _buildSectionHeader("PREFERENCES", isDark),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF147D64),
                    iconBg: const Color(0xFF147D64).withValues(alpha: 0.2),
                    title: "Base Currency",
                    trailingText: "LKR",
                    onTap: () {
                      _showCurrencyDialog(context);
                    },
                  ),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    title: "App Theme",
                    trailingText: themeProvider.isDarkMode ? "Dark (Default)" : "Light (White)",
                    onTap: () {
                      _showThemeSelectionDialog(context, themeProvider);
                    },
                  ),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.notifications_rounded,
                    iconColor: const Color(0xFFE89A58),
                    iconBg: const Color(0xFFE89A58).withValues(alpha: 0.2),
                    title: "Notifications",
                    badgeCount: notifProvider.unreadCount,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
                      ).then((_) {
                        if (mounted) {
                          Provider.of<NotificationProvider>(context, listen: false).fetchUnreadCount();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 4. SUPPORT Section
            _buildSectionHeader("SUPPORT", isDark),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.school_rounded,
                    iconColor: const Color(0xFF2CB8A0),
                    iconBg: const Color(0xFF147D64).withValues(alpha: 0.2),
                    title: "App Guided Tour & Workflows",
                    onTap: () {
                      AppTutorialGuide.show(context, isManualTrigger: true);
                    },
                  ),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFF4C9FD1),
                    iconBg: const Color(0xFF0B3B5A).withValues(alpha: 0.3),
                    title: "Help & Support",
                    onTap: () {
                      _showHelpDialog(context);
                    },
                  ),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFF4C9FD1),
                    iconBg: const Color(0xFF0B3B5A).withValues(alpha: 0.3),
                    title: "About Aureli",
                    onTap: () {
                      _showAboutDialog(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 5. Log Out Button
            InkWell(
              onTap: () => _confirmLogout(context, authProvider),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCD5C52).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCD5C52).withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Color(0xFFCD5C52), size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Log Out",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCD5C52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    String? trailingText,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final itemSubColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: itemTextColor,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: itemSubColor,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (badgeCount != null && badgeCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFCD5C52),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$badgeCount",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }

  void _showThemeSelectionDialog(BuildContext context, ThemeProvider themeProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF141B26) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white70 : const Color(0xFF475569);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Select App Theme",
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: titleColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.dark_mode_rounded, color: Color(0xFF8B5CF6)),
              title: Text("Dark Theme (Default)", style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, color: titleColor)),
              subtitle: Text("Sleek dark mode aesthetic", style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: subColor)),
              trailing: themeProvider.isDarkMode ? const Icon(Icons.check_circle_rounded, color: Color(0xFF147D64)) : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.light_mode_rounded, color: Color(0xFFF59E0B)),
              title: Text("Light Theme (White)", style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, color: titleColor)),
              subtitle: Text("Clean light white aesthetic", style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: subColor)),
              trailing: !themeProvider.isDarkMode ? const Icon(Icons.check_circle_rounded, color: Color(0xFF147D64)) : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Log Out",
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: const Text(
          "Are you sure you want to log out of Aureli?",
          style: TextStyle(fontFamily: 'Manrope', color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Exit profile screen
              authProvider.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCD5C52)),
            child: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String feature, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(feature, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(description, style: const TextStyle(fontFamily: 'Manrope', color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got it", style: TextStyle(color: Color(0xFF147D64))),
          ),
        ],
      ),
    );
  }

  void _showSecurityDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141B26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer<SecurityProvider>(
          builder: (context, secProvider, child) {
            final mediaQuery = MediaQuery.of(context);
            final systemBottomPadding = mediaQuery.viewPadding.bottom > 0
                ? mediaQuery.viewPadding.bottom
                : mediaQuery.padding.bottom;
            final effectiveBottomPadding =
                (systemBottomPadding > 0 ? systemBottomPadding : 16.0) + 24.0;

            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 20.0,
                bottom: effectiveBottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Color(0xFF147D64), size: 24),
                      SizedBox(width: 10),
                      Text(
                        "Security & Privacy Controls",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 1. Biometric Lock Setting
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF147D64),
                    title: const Text(
                      "Biometric App Lock",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      secProvider.isBiometricsAvailable
                          ? "Require Fingerprint or Face ID when launching or resuming Aureli."
                          : "Biometrics hardware not available or unconfigured on this device.",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                    value: secProvider.isBiometricsEnabled,
                    onChanged: secProvider.isBiometricsAvailable
                        ? (bool value) async {
                            final success = await secProvider.toggleBiometrics(value);
                            if (!success && value && ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text("Biometric verification failed. Lock setting unchanged."),
                                  backgroundColor: Color(0xFFCD5C52),
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                  const Divider(color: Colors.white10),

                  // 2. Task Switcher Privacy Protection (FLAG_SECURE)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF147D64),
                    title: const Text(
                      "Task Switcher Privacy",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      "Obscure application screens in recent apps switcher and block unauthorized screenshots.",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                    value: secProvider.isScreenSecurityEnabled,
                    onChanged: (bool value) {
                      secProvider.toggleScreenSecurity(value);
                    },
                  ),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),

                  // 3. Encrypted Transit Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B3B5A).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4C9FD1).withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, color: Color(0xFF4C9FD1), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "All API requests are authenticated with Firebase JWTs and protected with automated 401 session revocation.",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCurrencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Base Currency", style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: Colors.white)),
        content: const Text(
          "Current currency is Sri Lankan Rupee (LKR). Multi-currency conversions will be supported in future versions.",
          style: TextStyle(fontFamily: 'Manrope', color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Color(0xFF147D64))),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Help & Support", style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: Colors.white)),
        content: const Text(
          "For feedback or support inquiries, contact support@aureli.app.\n\nTips:\n• Set monthly limits in Budgets tab\n• Add notes to easily search transactions",
          style: TextStyle(fontFamily: 'Manrope', color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Color(0xFF147D64))),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("About Aureli", style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: Colors.white)),
        content: const Text(
          "Aureli — Smart Expense Tracker & Financial Manager.\nVersion 1.0.0\nBuilt with Flutter & Spring Boot.",
          style: TextStyle(fontFamily: 'Manrope', color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Color(0xFF147D64))),
          ),
        ],
      ),
    );
  }
}
