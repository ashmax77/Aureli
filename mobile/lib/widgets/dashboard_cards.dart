import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'glass_card.dart';
import 'meter_bar.dart';
import 'money_text.dart';

/// Icon tile + title (+ optional trailing widget): the top row of every dashboard card.
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // A Wrap: when the screen is narrow (or the text large) the trailing widget drops
    // below the title rather than squeezing it.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpace.sm,
      runSpacing: 0,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: t.soft(color, brightness: Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: AppSpace.md),
            Flexible(
              child: Text(
                title,
                style: AppText.title2.copyWith(color: t.ink),
              ),
            ),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A small caption over an amount.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.amount,
    this.tone = MoneyTone.neutral,
    this.color,
    this.end = false,
  });

  final String label;
  final double amount;
  final MoneyTone tone;
  final Color? color;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment:
          end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.caption.copyWith(color: t.inkSecondary),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: Money(amount, tone: tone, color: color),
        ),
      ],
    );
  }
}

/// Cumulative savings, the monthly reserve, an optional goal, and what is left to spend.
class SavingsVaultCard extends StatelessWidget {
  const SavingsVaultCard({
    super.key,
    required this.saved,
    required this.reservedThisMonth,
    required this.ratePercent,
    required this.spendable,
    required this.unallocated,
    required this.onEditRate,
    required this.onEditGoal,
    this.goalName = '',
    this.goalAmount = 0,
  });

  final double saved;
  final double reservedThisMonth;
  final double ratePercent;
  final double spendable;
  final double unallocated;
  final String goalName;
  final double goalAmount;
  final VoidCallback onEditRate;
  final VoidCallback onEditGoal;

  bool get _hasGoal => goalName.isNotEmpty && goalAmount > 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final brightness = Theme.of(context).brightness;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            icon: Icons.savings_rounded,
            color: t.amber,
            title: 'Savings vault',
            trailing: Semantics(
              button: true,
              label: 'Savings target ${ratePercent.toInt()} percent. Edit',
              child: InkWell(
                onTap: onEditRate,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.inputFill,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: t.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${ratePercent.toInt()}% target',
                            style:
                                AppText.label.copyWith(color: t.inkSecondary)),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_rounded, size: 12, color: t.inkMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('Total saved',
              style: AppText.bodySmall.copyWith(color: t.inkSecondary)),
          const SizedBox(height: AppSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Money(saved, style: AppText.hero.copyWith(fontSize: 28)),
          ),
          const SizedBox(height: AppSpace.lg),
          if (_hasGoal) ...[
            Row(
              children: [
                Icon(Icons.flag_rounded, size: 14, color: t.emerald),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Goal: $goalName',
                    style: AppText.label.copyWith(color: t.inkSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                GestureDetector(
                  onTap: onEditGoal,
                  behavior: HitTestBehavior.opaque,
                  child: Money(goalAmount,
                      style: AppText.label, tone: MoneyTone.positive),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            MeterBar(ratio: saved / goalAmount, color: t.emerald),
            const SizedBox(height: AppSpace.xs + 2),
            Text(
              '${(saved / goalAmount * 100).clamp(0, 100).toStringAsFixed(0)}% of your goal',
              style: AppText.caption.copyWith(color: t.inkSecondary),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: onEditGoal,
              icon: Icon(Icons.flag_rounded, size: 16, color: t.emerald),
              label: const Text('Set a savings goal'),
            ),
          const SizedBox(height: AppSpace.lg),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: AppSpace.md),
            decoration: BoxDecoration(
              color: t.soft(t.emerald, brightness: brightness),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: t.emerald),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'Reserved this month',
                    style: AppText.bodySmall.copyWith(color: t.inkSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Money(reservedThisMonth,
                    tone: MoneyTone.positive, showPlus: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Divider(height: 1, color: t.hairline),
          const SizedBox(height: AppSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child:
                      _Stat(label: 'Spendable allowance', amount: spendable)),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: _Stat(
                  label: 'Unallocated to budgets',
                  amount: unallocated,
                  color: unallocated > 0 ? t.cobalt : t.inkMuted,
                  end: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Net position across loans given and taken, opening the ledger when tapped.
class DebtPositionCard extends StatelessWidget {
  const DebtPositionCard({
    super.key,
    required this.netPosition,
    required this.totalLent,
    required this.totalBorrowed,
    required this.onTap,
  });

  final double netPosition;
  final double totalLent;
  final double totalBorrowed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final creditor = netPosition >= 0;
    final tone = creditor ? t.emerald : t.coral;

    return Semantics(
      button: true,
      label: 'Loan and debt position. Open ledger',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeader(
                icon: Icons.account_balance_rounded,
                color: t.cobalt,
                title: 'Loans & debts',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ledger',
                        style: AppText.label.copyWith(color: t.inkSecondary)),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: t.inkMuted),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Net position',
                            style: AppText.caption
                                .copyWith(color: t.inkSecondary)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Money(
                            netPosition,
                            style: AppText.title1.copyWith(fontSize: 22),
                            tone: MoneyTone.bySign,
                            showPlus: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.soft(tone,
                          brightness: Theme.of(context).brightness),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      creditor ? 'Net creditor' : 'Net debtor',
                      style: AppText.label.copyWith(color: tone),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Stat(
                        label: 'Lent',
                        amount: totalLent,
                        tone: MoneyTone.positive),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: _Stat(
                      label: 'Borrowed',
                      amount: totalBorrowed,
                      tone: MoneyTone.negative,
                      end: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How much of this month's allowance is left in cash and in the bank.
class MethodAllowanceCard extends StatelessWidget {
  const MethodAllowanceCard({
    super.key,
    required this.cashAllowance,
    required this.cashSpent,
    required this.bankAllowance,
    required this.bankSpent,
  });

  final double cashAllowance;
  final double cashSpent;
  final double bankAllowance;
  final double bankSpent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            icon: Icons.payments_rounded,
            color: t.emerald,
            title: 'Left to spend, by method',
          ),
          const SizedBox(height: AppSpace.xl),
          _MethodRow(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Cash',
            allowance: cashAllowance,
            spent: cashSpent,
          ),
          const SizedBox(height: AppSpace.lg),
          Divider(height: 1, color: t.hairline),
          const SizedBox(height: AppSpace.lg),
          _MethodRow(
            icon: Icons.account_balance_rounded,
            label: 'Bank transfer',
            allowance: bankAllowance,
            spent: bankSpent,
          ),
        ],
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.icon,
    required this.label,
    required this.allowance,
    required this.spent,
  });

  final IconData icon;
  final String label;
  final double allowance;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final left = (allowance - spent).clamp(0.0, double.infinity);
    final ratio = allowance > 0 ? spent / allowance : (spent > 0 ? 1.0 : 0.0);
    final color = ratio >= 1 ? t.coral : (ratio >= 0.9 ? t.amber : t.emerald);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: t.inkSecondary),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(label,
                  style: AppText.body
                      .copyWith(color: t.ink, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AppSpace.sm),
            Flexible(
              child:
                  Money(left, style: AppText.figure, tone: MoneyTone.neutral),
            ),
            const SizedBox(width: 4),
            Text('left',
                style: AppText.caption.copyWith(color: t.inkSecondary)),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        MeterBar(ratio: ratio, color: color),
        const SizedBox(height: AppSpace.xs + 2),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'Spent ',
                      style: AppText.caption.copyWith(color: t.inkSecondary)),
                  TextSpan(
                      text: formatAmount(spent),
                      style: AppText.tabular(AppText.caption)
                          .copyWith(color: t.ink)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'of ${formatAmount(allowance)}',
              style: AppText.tabular(AppText.caption)
                  .copyWith(color: t.inkSecondary),
              maxLines: 1,
            ),
          ],
        ),
      ],
    );
  }
}
