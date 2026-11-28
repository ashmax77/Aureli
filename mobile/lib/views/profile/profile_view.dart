import 'package:aureli/theme/app_colors.dart';
import 'package:aureli/theme/app_text.dart';
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
      padding: EdgeInsets.only(right: 16.0),
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
                border: Border.all(
                    color: context.tokens.emerald.withValues(alpha: 0.6),
                    width: 1.5),
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
                        style: AppText.title2.copyWith(fontSize: 13, color: context.textPrimary),
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
                    color: context.tokens.coral,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF0F1621)
                          : context.tokens.inputFill,
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
    return parts
        .map(
            (p) => p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '')
        .join(' ');
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
      Provider.of<NotificationProvider>(context, listen: false)
          .fetchUnreadCount();
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
    final email =
        authProvider.userModel?.email ?? user?.email ?? 'user@example.com';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    final primaryTextColor = context.textPrimary;
    final secondaryTextColor =
        context.tokens.inkMuted;

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
          icon: Icon(Icons.arrow_back_rounded, color: context.iconSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            SizedBox(height: 10),

            // 1. User Profile Picture & Info
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: context.tokens.emerald.withValues(alpha: 0.5),
                          width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: context.tokens.emerald.withValues(alpha: 0.2),
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
                              style: AppText.hero.copyWith(color: context.textPrimary),
                            )
                          : null,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    displayName,
                    style: AppText.title1.copyWith(color: primaryTextColor),
                  ),
                  SizedBox(height: 4),
                  Text(
                    email,
                    style: AppText.bodySmall.copyWith(color: secondaryTextColor),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // 2. ACCOUNT & SECURITY Section
            _buildSectionHeader("Account & security", isDark),
            SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.account_balance_rounded,
                    iconColor: context.tokens.cobalt,
                    iconBg: const Color(0xFF0B3B5A).withValues(alpha: 0.3),
                    title: "Linked Accounts",
                    onTap: () {
                      _showComingSoonDialog(context, "Linked Accounts",
                          "Multi-bank synchronization and account linking is coming in an upcoming release.");
                    },
                  ),
                  Divider(
                      color: context.tokens.hairline,
                      height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.security_rounded,
                    iconColor: context.tokens.cobalt,
                    iconBg: const Color(0xFF0B3B5A).withValues(alpha: 0.3),
                    title: "Security & Privacy",
                    onTap: () {
                      _showSecurityDialog(context);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 22),

            // 3. PREFERENCES Section
            _buildSectionHeader("Preferences", isDark),
            SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.payments_rounded,
                    iconColor: context.tokens.emerald,
                    iconBg: context.tokens.emerald.withValues(alpha: 0.2),
                    title: "Base Currency",
                    trailingText: "LKR",
                    onTap: () {
                      _showCurrencyDialog(context);
                    },
                  ),
                  Divider(
                      color: context.tokens.hairline,
                      height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: _themeIcon(
                        themeProvider.themeMode, Theme.of(context).brightness),
                    iconColor: const Color(0xFF8B5CF6),
                    iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    title: "App Theme",
                    trailingText: _themeLabel(themeProvider.themeMode),
                    onTap: () {
                      _showThemeSelectionDialog(context, themeProvider);
                    },
                  ),
                  Divider(
                      color: context.tokens.hairline,
                      height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.notifications_rounded,
                    iconColor: context.tokens.amber,
                    iconBg: context.tokens.amber.withValues(alpha: 0.2),
                    title: "Notifications",
                    badgeCount: notifProvider.unreadCount,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationHistoryScreen()),
                      ).then((_) {
                        if (context.mounted) {
                          Provider.of<NotificationProvider>(context,
                                  listen: false)
                              .fetchUnreadCount();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 22),

            // 4. SUPPORT Section
            _buildSectionHeader("Support", isDark),
            SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.school_rounded,
                    iconColor: context.tokens.emerald,
                    iconBg: context.tokens.emerald.withValues(alpha: 0.2),
                    title: "App Guided Tour & Workflows",
                    onTap: () {
                      AppTutorialGuide.show(context, isManualTrigger: true);
                    },
                  ),
                  Divider(
                      color: context.tokens.hairline,
                      height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    iconColor: context.tokens.cobalt,
                    iconBg: const Color(0xFF0B3B5A).withValues(alpha: 0.3),
                    title: "Help & Support",
                    onTap: () {
                      _showHelpDialog(context);
                    },
                  ),
                  Divider(
                      color: context.tokens.hairline,
                      height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    iconColor: context.tokens.cobalt,
                    iconBg: const Color(0xFF0B3B5A).withValues(alpha: 0.3),
                    title: "About Aureli",
                    onTap: () {
                      _showAboutDialog(context);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // 5. Log Out Button
            InkWell(
              onTap: () => _confirmLogout(context, authProvider),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: context.tokens.coral.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: context.tokens.coral.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded,
                        color: context.tokens.coral, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Log Out",
                      style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: context.tokens.coral),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
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
        style: AppText.label.copyWith(fontWeight: FontWeight.bold, color: context.tokens.inkMuted),
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
    final itemTextColor = context.textPrimary;
    final itemSubColor =
        context.tokens.inkMuted;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
            SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: itemTextColor),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: AppText.title2.copyWith(fontSize: 13, color: itemSubColor),
              ),
              SizedBox(width: 6),
            ],
            if (badgeCount != null && badgeCount > 0) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.tokens.coral,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$badgeCount",
                  style: AppText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
              ),
              SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right_rounded,
                color: context.tokens.inkMuted,
                size: 20),
          ],
        ),
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  static IconData _themeIcon(ThemeMode mode, Brightness current) =>
      switch (mode) {
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
        ThemeMode.system => current == Brightness.dark
            ? Icons.dark_mode_rounded
            : Icons.light_mode_rounded,
      };

  void _showThemeSelectionDialog(
      BuildContext context, ThemeProvider themeProvider) {
    const options = [
      (ThemeMode.system, 'System', 'Match your phone\u2019s setting'),
      (ThemeMode.light, 'Light', 'Bright, high-contrast surfaces'),
      (ThemeMode.dark, 'Dark', 'Easy on the eyes at night'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('App theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (mode, title, subtitle) in options)
              ListTile(
                key: ValueKey('theme-option-${mode.name}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(_themeIcon(mode, Theme.of(ctx).brightness),
                    color: ctx.tokens.cobalt),
                title: Text(title),
                subtitle: Text(subtitle,
                    style: AppText.bodySmall
                        .copyWith(color: ctx.tokens.inkSecondary)),
                trailing: themeProvider.themeMode == mode
                    ? Icon(Icons.check_circle_rounded,
                        color: ctx.tokens.emerald)
                    : null,
                onTap: () {
                  themeProvider.setThemeMode(mode);
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
        backgroundColor: context.cardLightBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Log Out",
          style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.bold,
              color: context.textPrimary),
        ),
        content: Text(
          "Are you sure you want to log out of Aureli?",
          style: TextStyle(fontFamily: 'Manrope', color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel",
                style: TextStyle(
                    color: context.tokens.inkMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Exit profile screen
              authProvider.logout();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: context.tokens.coral),
            child: Text("Log Out",
                style: TextStyle(
                    color: context.textPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(
      BuildContext context, String feature, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardLightBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(feature,
            style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                color: context.textPrimary)),
        content: Text(description,
            style:
                TextStyle(fontFamily: 'Manrope', color: context.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Got it",
                style: TextStyle(color: context.tokens.emerald)),
          ),
        ],
      ),
    );
  }

  void _showSecurityDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardLightBg,
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

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textPrimary = context.textPrimary;
            final textSecondary = context.tokens.inkMuted;

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
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.shield_rounded,
                          color: context.tokens.emerald, size: 24),
                      SizedBox(width: 10),
                      Text(
                        "Security & Privacy Controls",
                        style: AppText.title1.copyWith(fontSize: 18, color: textPrimary),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // 1. Biometric Lock Setting
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: context.tokens.brand,
                    title: Text(
                      "Biometric App Lock",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      secProvider.isBiometricsAvailable
                          ? "Require Fingerprint or Face ID when launching or resuming Aureli."
                          : "Biometrics hardware not available or unconfigured on this device.",
                      style: AppText.label.copyWith(color: textSecondary),
                    ),
                    value: secProvider.isBiometricsEnabled,
                    onChanged: secProvider.isBiometricsAvailable
                        ? (bool value) async {
                            final success =
                                await secProvider.toggleBiometrics(value);
                            if (!success && value && ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "Biometric verification failed. Lock setting unchanged."),
                                  backgroundColor: context.tokens.coral,
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                  Divider(color: context.tokens.hairline),

                  // 2. Task Switcher Privacy Protection (FLAG_SECURE)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: context.tokens.brand,
                    title: Text(
                      "Task Switcher Privacy",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      "Obscure application screens in recent apps switcher and block unauthorized screenshots.",
                      style: AppText.label.copyWith(color: textSecondary),
                    ),
                    value: secProvider.isScreenSecurityEnabled,
                    onChanged: (bool value) {
                      secProvider.toggleScreenSecurity(value);
                    },
                  ),
                  Divider(color: context.tokens.hairline),
                  SizedBox(height: 12),

                  // 3. Encrypted Transit Banner
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0B3B5A).withValues(alpha: 0.3)
                          : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? context.tokens.cobalt.withValues(alpha: 0.3)
                              : const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            color: context.tokens.cobalt, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "All API requests are authenticated with Firebase JWTs and protected with automated 401 session revocation.",
                            style: AppText.label.copyWith(color: isDark ? context.tokens.inkSecondary : Color(0xFF0369A1), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
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
        backgroundColor: context.cardLightBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Base Currency",
            style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                color: context.textPrimary)),
        content: Text(
          "Current currency is Sri Lankan Rupee (LKR). Multi-currency conversions will be supported in future versions.",
          style: TextStyle(fontFamily: 'Manrope', color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text("Close", style: TextStyle(color: context.tokens.emerald)),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardLightBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Help & Support",
            style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                color: context.textPrimary)),
        content: Text(
          "For feedback or support inquiries, contact support@aureli.app.\n\nTips:\n• Set monthly limits in Budgets tab\n• Add notes to easily search transactions",
          style: TextStyle(
              fontFamily: 'Manrope', color: context.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("OK", style: TextStyle(color: context.tokens.emerald)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardLightBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("About Aureli",
            style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                color: context.textPrimary)),
        content: Text(
          "Aureli — Smart Expense Tracker & Financial Manager.\nVersion 1.0.0\nBuilt with Flutter & Spring Boot.",
          style: TextStyle(
              fontFamily: 'Manrope', color: context.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text("Close", style: TextStyle(color: context.tokens.emerald)),
          ),
        ],
      ),
    );
  }
}
