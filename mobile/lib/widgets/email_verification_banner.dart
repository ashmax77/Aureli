import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Reminder shown above the app until the signed-in user confirms their email address.
/// Never blocks anything; it can be dismissed for the session and disappears by itself
/// once the address is verified. Renders nothing otherwise.
class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  State<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  static const Color _background = Color(0xFF0F5E4C);

  bool _checking = false;

  void _say(ScaffoldMessengerState messenger, String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _resend(AuthProvider auth) async {
    final messenger = ScaffoldMessenger.of(context);
    final email = auth.firebaseUser?.email;
    final error = await auth.sendVerificationEmail();
    if (!mounted) return;
    _say(
      messenger,
      error ?? (email == null ? 'Verification email sent.' : 'Verification email sent to $email.'),
    );
  }

  Future<void> _check(AuthProvider auth) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checking = true);
    final verified = await auth.refreshEmailVerification();
    if (!mounted) return;
    setState(() => _checking = false);
    _say(
      messenger,
      switch (verified) {
        true => 'Email verified. Thank you!',
        false => 'Not verified yet. Open the link in the email, then try again.',
        null => "Couldn't check right now. Check your connection and try again.",
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.showVerificationBanner) return const SizedBox.shrink();

    final email = auth.firebaseUser?.email;
    final who = email ?? 'your email';
    final message = auth.verificationEmailSent
        ? 'We sent a link to $who. Open it, then come back.'
        : 'Confirm $who to keep your account secure.';

    const white = TextStyle(fontFamily: 'Manrope', color: Colors.white);
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
      ),
    );

    return Material(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.mark_email_unread_outlined, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify your email',
                          style: white.copyWith(fontSize: 13.5, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: white.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remind me later',
                    onPressed: auth.dismissVerificationBanner,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Wrap(
                  children: [
                    TextButton(
                      style: buttonStyle,
                      onPressed: auth.isSendingVerification ? null : () => _resend(auth),
                      child: Text(auth.isSendingVerification ? 'Sending…' : 'Resend email'),
                    ),
                    TextButton(
                      style: buttonStyle,
                      onPressed: _checking ? null : () => _check(auth),
                      child: Text(_checking ? 'Checking…' : "I've verified"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
