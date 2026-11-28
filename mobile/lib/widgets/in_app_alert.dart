import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

/// The colour a push alert carries, from its title: red when a limit was passed, amber
/// for a warning, blue for anything informational.
Color alertAccentFor(BuildContext context, String title) {
  final lower = title.toLowerCase();
  final t = context.tokens;
  if (lower.contains('exceeded')) return t.coral;
  if (lower.contains('budget') ||
      lower.contains('limit') ||
      lower.contains('nearing') ||
      lower.contains('overdue')) {
    return t.amber;
  }
  return t.cobalt;
}

/// The card shown inside the in-app alert toast.
class InAppAlertCard extends StatelessWidget {
  const InAppAlertCard({
    super.key,
    required this.title,
    required this.body,
    required this.accent,
    this.icon = Icons.notifications_active_rounded,
  });

  final String title;
  final String body;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.hairline),
        boxShadow: [
          BoxShadow(
            color: t.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.soft(accent, brightness: Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title2.copyWith(fontSize: 14, color: t.ink)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySmall
                          .copyWith(color: t.inkSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a push message that arrived while the app is open.
void showInAppAlert(BuildContext context,
    {required String title, required String body}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 5),
        content: InAppAlertCard(
          title: title,
          body: body,
          accent: alertAccentFor(context, title),
        ),
      ),
    );
}
