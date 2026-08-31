import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/glass_card.dart';
import '../notifications/notification_views.dart';

/// Reusable user profile avatar icon for AppBars.
/// Tapping it directs the user to the Profile page.
class UserProfileAvatarIcon extends StatelessWidget {
  const UserProfileAvatarIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
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
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF147D64).withOpacity(0.6), width: 1.5),
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
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final notifProvider = Provider.of<NotificationProvider>(context);
    final user = authProvider.firebaseUser;
    final photoUrl = user?.photoURL;
    final displayName = _getUserDisplayName(authProvider);
    final email = authProvider.userModel?.email ?? user?.email ?? 'user@example.com';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621),
      appBar: AppBar(
        title: const Text(
          "Aureli",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
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
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 2. ACCOUNT & SECURITY Section
            _buildSectionHeader("ACCOUNT & SECURITY"),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.account_balance_rounded,
                    iconColor: const Color(0xFF4C9FD1),
                    iconBg: const Color(0xFF0B3B5A).withOpacity(0.3),
                    title: "Linked Accounts",
                    onTap: () {
                      _showComingSoonDialog(context, "Linked Accounts", "Multi-bank synchronization and account linking is coming in an upcoming release.");
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.security_rounded,
                    iconColor: const Color(0xFF4C9FD1),
                    iconBg: const Color(0xFF0B3B5A).withOpacity(0.3),
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
            _buildSectionHeader("PREFERENCES"),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF147D64),
                    iconBg: const Color(0xFF147D64).withOpacity(0.2),
                    title: "Base Currency",
                    trailingText: "LKR",
                    onTap: () {
                      _showCurrencyDialog(context);
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.notifications_rounded,
                    iconColor: const Color(0xFFE89A58),
                    iconBg: const Color(0xFFE89A58).withOpacity(0.2),
                    title: "Notifications",
                    badgeCount: notifProvider.unreadCount,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 4. SUPPORT Section
            _buildSectionHeader("SUPPORT"),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFF4C9FD1),
                    iconBg: const Color(0xFF0B3B5A).withOpacity(0.3),
                    title: "Help & Support",
                    onTap: () {
                      _showHelpDialog(context);
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFF4C9FD1),
                    iconBg: const Color(0xFF0B3B5A).withOpacity(0.3),
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
                  color: const Color(0xFFCD5C52).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCD5C52).withOpacity(0.35)),
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

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white.withOpacity(0.45),
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
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
                  color: Colors.white.withOpacity(0.5),
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
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 20),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Security & Privacy", style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: Colors.white)),
        content: const Text(
          "Your transaction and budget records are encrypted in transit and securely bound to your authenticated Firebase session.",
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
