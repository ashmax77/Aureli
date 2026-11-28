import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'glass_card.dart';
import 'money_text.dart';

/// A section title with an optional quiet action on the right ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppText.title1.copyWith(color: t.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              minimumSize: const Size(0, 36),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// One-line entry point to scheduled payments, with the count of what is coming up.
class ScheduledPaymentsTile extends StatelessWidget {
  const ScheduledPaymentsTile({
    super.key,
    required this.upcomingCount,
    required this.onTap,
  });

  final int upcomingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final brightness = Theme.of(context).brightness;
    final hasUpcoming = upcomingCount > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.soft(t.cobalt, brightness: brightness),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.event_note_rounded, color: t.cobalt, size: 20),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scheduled payments',
                      style: AppText.title2.copyWith(color: t.ink)),
                  const SizedBox(height: 2),
                  Text(
                    hasUpcoming
                        ? '$upcomingCount upcoming payment${upcomingCount > 1 ? 's' : ''} due'
                        : 'No upcoming payments scheduled',
                    style: AppText.bodySmall.copyWith(
                        color: hasUpcoming ? t.emerald : t.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// A category in the "Top categories" strip: icon, name, and what was spent.
class TopCategoryTile extends StatelessWidget {
  const TopCategoryTile({
    super.key,
    required this.icon,
    required this.color,
    required this.name,
    required this.spent,
  });

  /// The category glyph, already coloured.
  final Widget icon;
  final Color color;
  final String name;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassCard(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpace.lg, horizontal: AppSpace.sm),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.soft(color, brightness: Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Money(
              spent,
              style: AppText.figure.copyWith(fontSize: 13),
              color: t.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the recent-expenses panel.
class RecentExpenseRow extends StatelessWidget {
  const RecentExpenseRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.badge,
  });

  final Widget icon;
  final Color color;
  final String title;
  final String subtitle;
  final double amount;

  /// Shown under the subtitle, e.g. a "pending sync" badge.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.soft(color, brightness: Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title2.copyWith(fontSize: 14, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppText.caption.copyWith(color: t.inkMuted)),
                if (badge != null) ...[const SizedBox(height: 3), badge!],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Money(amount, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}
