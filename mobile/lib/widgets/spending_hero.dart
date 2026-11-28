import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'glass_card.dart';
import 'meter_bar.dart';
import 'money_text.dart';

/// Where this month's spending stands against the budget.
enum BudgetState {
  /// No budget has been set, so there is nothing to compare with.
  none,
  onTrack,

  /// At or past 90 % of the budget (the same threshold the server alerts at).
  nearing,
  over;

  static BudgetState of({required double spent, required double? budget}) {
    if (budget == null || budget <= 0) return none;
    if (spent > budget) return over;
    if (spent / budget >= 0.9) return nearing;
    return onTrack;
  }

  String get label => switch (this) {
        none => 'No limit set',
        onTrack => 'On track',
        nearing => 'Nearing limit',
        over => 'Over budget',
      };

  IconData get icon => switch (this) {
        none => Icons.info_outline_rounded,
        onTrack => Icons.check_circle_outline_rounded,
        nearing => Icons.trending_up_rounded,
        over => Icons.error_outline_rounded,
      };

  Color color(AureliTokens t) => switch (this) {
        none => t.inkSecondary,
        onTrack => t.emerald,
        nearing => t.amber,
        over => t.coral,
      };
}

/// The dashboard's headline card: what has been spent this month, how that sits against
/// the budget, and the month's cash flow. It is the one glass surface on the screen and
/// its tint follows [BudgetState], so a glance says whether to worry.
class SpendingHero extends StatelessWidget {
  const SpendingHero({
    super.key,
    required this.monthLabel,
    required this.spent,
    required this.income,
    required this.netCashFlow,
    required this.cashSpent,
    required this.bankSpent,
    this.budget,
    this.previousSpent = 0,
    this.previousMonthLabel,
    this.onTap,
  });

  /// Opens the budgets screen.
  final VoidCallback? onTap;

  /// E.g. "November".
  final String monthLabel;
  final double spent;
  final double income;
  final double netCashFlow;
  final double cashSpent;
  final double bankSpent;

  /// The total of the category budgets, if any are set.
  final double? budget;

  /// Last month's spending, for the comparison line (hidden when zero).
  final double previousSpent;
  final String? previousMonthLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = BudgetState.of(spent: spent, budget: budget);
    final accent = state.color(t);
    final hasBudget = state != BudgetState.none;
    final ratio = hasBudget ? spent / budget! : 0.0;
    final left = hasBudget ? budget! - spent : 0.0;

    final semantics =
        StringBuffer('Spent in $monthLabel: LKR ${formatAmount(spent)}');
    if (hasBudget) {
      semantics.write(
          ', ${(ratio * 100).round()} percent of the budget, ${state.label}');
    }

    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      label: semantics.toString(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassCard(
          variant: GlassVariant.hero,
          tint: hasBudget ? accent : null,
          padding: const EdgeInsets.all(AppSpace.xl),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Spent in $monthLabel',
                        style:
                            AppText.bodySmall.copyWith(color: t.inkSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    _StatePill(state: state),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Money(spent, style: AppText.hero),
                ),
                if (hasBudget) ...[
                  const SizedBox(height: AppSpace.lg),
                  MeterBar(ratio: ratio, color: accent),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: 'LKR ${formatAmount(left.abs())}',
                              style: AppText.tabular(AppText.label)
                                  .copyWith(color: left < 0 ? t.coral : t.ink),
                            ),
                            TextSpan(
                              text: left < 0 ? ' over' : ' left',
                              style:
                                  AppText.label.copyWith(color: t.inkSecondary),
                            ),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'of LKR ${formatAmount(budget!)}',
                        style: AppText.tabular(AppText.caption)
                            .copyWith(color: t.inkSecondary),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ],
                if (!hasBudget && onTap != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      Text(
                        'Set budgets to track your progress',
                        style: AppText.label.copyWith(color: t.cobalt),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: t.cobalt),
                    ],
                  ),
                ],
                if (previousSpent > 0 && previousMonthLabel != null) ...[
                  const SizedBox(height: AppSpace.md),
                  _Comparison(
                    spent: spent,
                    previous: previousSpent,
                    previousMonthLabel: previousMonthLabel!,
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                Divider(height: 1, color: t.hairline),
                const SizedBox(height: AppSpace.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Income',
                        amount: income,
                        tone: MoneyTone.positive,
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Net cash flow',
                        amount: netCashFlow,
                        tone: MoneyTone.bySign,
                        showPlus: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _Stat(label: 'Paid in cash', amount: cashSpent)),
                    Expanded(
                        child: _Stat(label: 'Paid by bank', amount: bankSpent)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.state});
  final BudgetState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = state.color(t);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpace.sm + 2, vertical: 4),
      decoration: BoxDecoration(
        color: state == BudgetState.none
            ? t.inputFill
            : t.soft(color, brightness: Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(state.icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(state.label, style: AppText.label.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.spent,
    required this.previous,
    required this.previousMonthLabel,
  });

  final double spent;
  final double previous;
  final String previousMonthLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final diff = (spent - previous) / previous * 100;
    final up = diff > 0.05;
    final down = diff < -0.05;
    final color = up ? t.coral : (down ? t.emerald : t.inkSecondary);
    final icon = up
        ? Icons.trending_up_rounded
        : (down ? Icons.trending_down_rounded : Icons.trending_flat_rounded);
    final text = up
        ? '${diff.abs().toStringAsFixed(1)}% more than $previousMonthLabel'
        : down
            ? '${diff.abs().toStringAsFixed(1)}% less than $previousMonthLabel'
            : 'Same as $previousMonthLabel';

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: AppText.label.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.amount,
    this.tone = MoneyTone.neutral,
    this.showPlus = false,
  });

  final String label;
  final double amount;
  final MoneyTone tone;
  final bool showPlus;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption.copyWith(color: t.inkSecondary)),
        const SizedBox(height: 2),
        Money(amount, style: AppText.figure, tone: tone, showPlus: showPlus),
      ],
    );
  }
}
