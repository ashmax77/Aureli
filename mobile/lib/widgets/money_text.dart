import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// How an amount is coloured.
enum MoneyTone {
  /// Ink, whatever the sign.
  neutral,

  /// Emerald for income and gains.
  positive,

  /// Coral for expenses and losses.
  negative,

  /// Emerald when above zero, coral when below, ink at zero.
  bySign,
}

final NumberFormat _grouped = NumberFormat('#,##0.00');

/// `1,234.50`: grouped, always two decimals. A negative amount gets a true minus sign
/// (U+2212, the width of a plus) rather than a hyphen; [showPlus] adds a `+` to positives.
String formatAmount(num value, {bool showPlus = false}) {
  final rounded = (value.abs() * 100).round() / 100;
  final body = _grouped.format(rounded);
  if (value < 0 && rounded != 0) return '\u2212$body';
  if (showPlus && rounded != 0) return '+$body';
  return body;
}

/// An amount of money, set the way a ledger sets it: tabular digits so columns line up,
/// the currency code small and quiet before the number, a real minus sign.
class Money extends StatelessWidget {
  const Money(
    this.amount, {
    super.key,
    this.currency = 'LKR',
    this.style = AppText.figure,
    this.tone = MoneyTone.neutral,
    this.showCurrency = true,
    this.showPlus = false,
    this.textAlign,
    this.maxLines = 1,
  });

  final num amount;
  final String currency;

  /// Size and weight of the number; the currency code follows at a smaller size.
  final TextStyle style;
  final MoneyTone tone;
  final bool showCurrency;
  final bool showPlus;
  final TextAlign? textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (tone) {
      MoneyTone.neutral => t.ink,
      MoneyTone.positive => t.emerald,
      MoneyTone.negative => t.coral,
      MoneyTone.bySign => amount > 0
          ? t.emerald
          : amount < 0
              ? t.coral
              : t.ink,
    };
    final base = AppText.tabular(style).copyWith(color: color);
    final size = base.fontSize ?? 14;

    return Text.rich(
      TextSpan(
        children: [
          if (showCurrency)
            TextSpan(
              text: '$currency\u2009',
              style: base.copyWith(
                fontSize: size * 0.62,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: t.inkSecondary,
              ),
            ),
          TextSpan(text: formatAmount(amount, showPlus: showPlus)),
        ],
        style: base,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}
