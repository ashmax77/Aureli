import 'package:aureli/theme/app_theme.dart';
import 'package:aureli/theme/app_tokens.dart';
import 'package:aureli/widgets/glass_card.dart';
import 'package:aureli/widgets/spending_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child,
        {ThemeData? theme, double width = 360, double textScale = 1.0}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );

SpendingHero _hero({
  double spent = 40000,
  double? budget = 100000,
  double previous = 0,
  VoidCallback? onTap,
}) =>
    SpendingHero(
      monthLabel: 'November',
      spent: spent,
      income: 210000,
      netCashFlow: 170000,
      cashSpent: 10000,
      bankSpent: 30000,
      budget: budget,
      previousSpent: previous,
      previousMonthLabel: 'October',
      onTap: onTap,
    );

void main() {
  group('budget state', () {
    test('no budget means nothing to compare with', () {
      expect(BudgetState.of(spent: 500, budget: null), BudgetState.none);
      expect(BudgetState.of(spent: 500, budget: 0), BudgetState.none);
    });

    test('thresholds match the server alerts: 90 % and 100 %', () {
      expect(BudgetState.of(spent: 89999, budget: 100000), BudgetState.onTrack);
      expect(BudgetState.of(spent: 90000, budget: 100000), BudgetState.nearing);
      expect(BudgetState.of(spent: 100000, budget: 100000), BudgetState.nearing);
      expect(BudgetState.of(spent: 100000.01, budget: 100000), BudgetState.over);
    });

    test('each state has its own colour in both themes', () {
      for (final t in [AureliTokens.light, AureliTokens.dark]) {
        final colours = {
          BudgetState.onTrack.color(t),
          BudgetState.nearing.color(t),
          BudgetState.over.color(t),
        };
        expect(colours.length, 3);
        expect(BudgetState.onTrack.color(t), t.emerald);
        expect(BudgetState.nearing.color(t), t.amber);
        expect(BudgetState.over.color(t), t.coral);
      }
    });
  });

  group('hero card', () {
    testWidgets('on track: shows what is left of the budget', (tester) async {
      await tester.pumpWidget(_host(_hero()));

      expect(find.text('On track'), findsOneWidget);
      expect(find.textContaining('60,000.00', findRichText: true), findsWidgets);
      expect(find.textContaining('left', findRichText: true), findsOneWidget);
      expect(find.textContaining('of LKR 100,000.00'), findsOneWidget);
    });

    testWidgets('over budget: says by how much', (tester) async {
      await tester.pumpWidget(_host(_hero(spent: 112450.75, budget: 100000)));

      expect(find.text('Over budget'), findsOneWidget);
      // The headline is 112,450.75; the shortfall line says LKR 12,450.75 over.
      expect(find.textContaining('LKR 12,450.75', findRichText: true), findsOneWidget);
      expect(find.textContaining(' over', findRichText: true), findsOneWidget);
    });

    testWidgets('the glass tint follows the state', (tester) async {
      Color? tintAfter(double spent) {
        final card = tester.widget<GlassCard>(find.byType(GlassCard));
        expect(card.variant, GlassVariant.hero);
        return card.tint;
      }

      final t = AureliTokens.light;
      await tester.pumpWidget(_host(_hero(spent: 10000)));
      expect(tintAfter(10000), t.emerald);

      await tester.pumpWidget(_host(_hero(spent: 95000)));
      expect(tintAfter(95000), t.amber);

      await tester.pumpWidget(_host(_hero(spent: 150000)));
      expect(tintAfter(150000), t.coral);

      await tester.pumpWidget(_host(_hero(budget: null)));
      expect(tintAfter(0), isNull);
    });

    testWidgets('no budget: invites the user to set one, and tapping opens budgets',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(_hero(budget: null, onTap: () => taps++)));

      expect(find.text('No limit set'), findsOneWidget);
      expect(find.text('Set budgets to track your progress'), findsOneWidget);
      expect(find.textContaining(' left', findRichText: true), findsNothing);

      await tester.tap(find.byType(SpendingHero));
      expect(taps, 1);
    });

    testWidgets('compares with last month only when there was spending', (tester) async {
      await tester.pumpWidget(_host(_hero(spent: 115000, previous: 100000)));
      expect(find.text('15.0% more than October'), findsOneWidget);

      await tester.pumpWidget(_host(_hero(spent: 85000, previous: 100000)));
      expect(find.text('15.0% less than October'), findsOneWidget);

      await tester.pumpWidget(_host(_hero(spent: 100000, previous: 100000)));
      expect(find.text('Same as October'), findsOneWidget);

      await tester.pumpWidget(_host(_hero(previous: 0)));
      expect(find.textContaining('October'), findsNothing);
    });

    testWidgets('negative net cash flow shows a minus sign and the loss colour',
        (tester) async {
      await tester.pumpWidget(_host(const SpendingHero(
        monthLabel: 'November',
        spent: 5000,
        income: 1000,
        netCashFlow: -4000,
        cashSpent: 5000,
        bankSpent: 0,
      )));

      final loss = find.textContaining('\u22124,000.00', findRichText: true);
      expect(loss, findsOneWidget);
      expect(find.textContaining('-4,000', findRichText: true), findsNothing);

      // Text wraps the span in one carrying the default style; Money's is the child.
      final outer = tester.widget<RichText>(loss).text as TextSpan;
      expect((outer.children!.single as TextSpan).style!.color,
          AureliTokens.light.coral);
    });

    testWidgets('a screen reader hears the headline in one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(_hero(spent: 95000)));

      expect(
        find.bySemanticsLabel(RegExp(
            r'Spent in November: LKR 95,000\.00, 95 percent of the budget, Nearing limit')),
        findsOneWidget,
      );
      handle.dispose();
    });

    for (final dark in [false, true]) {
      testWidgets('fits a 320 dp screen at 1.3x text (${dark ? 'dark' : 'light'})',
          (tester) async {
        await tester.pumpWidget(_host(
          _hero(spent: 1234567.89, budget: 1000000, previous: 900000),
          theme: dark ? AppTheme.dark : AppTheme.light,
          width: 320,
          textScale: 1.3,
        ));
        expect(tester.takeException(), isNull);
      });
    }
  });
}