import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:aureli/providers/theme_provider.dart';
import 'package:aureli/theme/app_colors.dart';
import 'package:aureli/theme/app_theme.dart';
import 'package:aureli/theme/app_tokens.dart';
import 'package:aureli/widgets/glass_card.dart';
import 'package:aureli/widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG contrast ratio of [fg] drawn over an opaque [bg].
double contrast(Color fg, Color bg) {
  final a = fg.computeLuminance();
  final b = bg.computeLuminance();
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('colour tokens', () {
    for (final entry in {
      'light': AureliTokens.light,
      'dark': AureliTokens.dark,
    }.entries) {
      final t = entry.value;
      final surfaces = {'canvas': t.canvas, 'panel': t.panel};

      for (final s in surfaces.entries) {
        test('${entry.key}: text and accents are readable on ${s.key}', () {
          final readable = {
            'ink': (t.ink, 7.0),
            'inkSecondary': (t.inkSecondary, 4.5),
            'inkMuted': (t.inkMuted, 4.5),
            'emerald': (t.emerald, 4.5),
            'coral': (t.coral, 4.5),
            'amber': (t.amber, 4.5),
            'cobalt': (t.cobalt, 4.5),
          };
          for (final c in readable.entries) {
            final ratio = contrast(c.value.$1, s.value);
            expect(ratio, greaterThanOrEqualTo(c.value.$2),
                reason: '${c.key} on ${s.key} is only ${ratio.toStringAsFixed(2)}:1');
          }
        });
      }

      test('${entry.key}: white text on a primary button is readable', () {
        expect(contrast(Colors.white, t.brand), greaterThanOrEqualTo(4.5));
      });

      test('${entry.key}: snack bar text is readable on its ink fill', () {
        expect(contrast(t.inkInverse, t.ink), greaterThanOrEqualTo(7));
      });
    }

    test('light and dark define the same set of roles', () {
      // Guards against adding a token to one palette and forgetting the other.
      final light = AureliTokens.light;
      final dark = AureliTokens.dark;
      expect(light.copyWith(), isNot(same(light)));
      expect(dark.lerp(light, 0).canvas, dark.canvas);
      expect(dark.lerp(light, 1).canvas, light.canvas);
    });
  });

  group('money', () {
    test('groups thousands and always shows two decimals', () {
      expect(formatAmount(1234.5), '1,234.50');
      expect(formatAmount(0), '0.00');
      expect(formatAmount(1234567.891), '1,234,567.89');
    });

    test('a negative amount uses a real minus sign', () {
      expect(formatAmount(-1250), '\u22121,250.00');
      expect(formatAmount(-1250).contains('-'), isFalse);
    });

    test('an amount that rounds to zero has no sign', () {
      expect(formatAmount(-0.004), '0.00');
      expect(formatAmount(0.004, showPlus: true), '0.00');
    });

    test('showPlus marks gains only', () {
      expect(formatAmount(12, showPlus: true), '+12.00');
      expect(formatAmount(-12, showPlus: true), '\u221212.00');
    });

    testWidgets('digits are tabular and the code precedes the number', (tester) async {
      await tester.pumpWidget(_host(const Money(84250)));

      final text = tester.widget<Text>(find.byType(Text));
      final root = text.textSpan! as TextSpan;
      expect(root.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(text.textSpan!.toPlainText(), 'LKR\u2009' '84,250.00');
    });

    testWidgets('tone decides the colour', (tester) async {
      final t = AureliTokens.light;
      Color colourOf(WidgetTester tester) =>
          (tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan).style!.color!;

      await tester.pumpWidget(_host(const Money(-5, tone: MoneyTone.negative)));
      expect(colourOf(tester), t.coral);

      await tester.pumpWidget(_host(const Money(5, tone: MoneyTone.positive)));
      expect(colourOf(tester), t.emerald);

      await tester.pumpWidget(_host(const Money(-5, tone: MoneyTone.bySign)));
      expect(colourOf(tester), t.coral);

      await tester.pumpWidget(_host(const Money(0, tone: MoneyTone.bySign)));
      expect(colourOf(tester), t.ink);
    });

    testWidgets('the currency can be left out', (tester) async {
      await tester.pumpWidget(_host(const Money(10, showCurrency: false)));
      expect(find.textContaining('LKR', findRichText: true), findsNothing);
      expect(find.textContaining('10.00', findRichText: true), findsOneWidget);
    });
  });

  group('surfaces', () {
    testWidgets('a panel is flat: no backdrop blur', (tester) async {
      await tester.pumpWidget(_host(const GlassCard(child: Text('x'))));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('glass and hero blur what is behind them', (tester) async {
      await tester.pumpWidget(_host(const Column(children: [
        GlassCard(variant: GlassVariant.glass, child: Text('a')),
        GlassCard(
            variant: GlassVariant.hero,
            tint: Color(0xFF34C79F),
            child: Text('b')),
      ])));
      expect(find.byType(BackdropFilter), findsNWidgets(2));
    });

    testWidgets('radii come from the scale', (tester) async {
      await tester.pumpWidget(_host(const Column(children: [
        GlassCard(child: Text('panel')),
        GlassCard(variant: GlassVariant.glass, child: Text('glass')),
      ])));

      final panel = tester.widget<Container>(find
          .ancestor(of: find.text('panel'), matching: find.byType(Container))
          .first);
      expect(((panel.decoration! as BoxDecoration).borderRadius! as BorderRadius).topLeft.x,
          AppRadius.md);

      final clip = tester.widget<ClipRRect>(find.ancestor(
          of: find.text('glass'), matching: find.byType(ClipRRect)));
      expect((clip.borderRadius as BorderRadius).topLeft.x, AppRadius.lg);
    });

    testWidgets('the backdrop paints the canvas colour', (tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        width: 100,
        height: 100,
        child: AmbientBackdrop(),
      )));
      final fill = tester.widgetList<ColoredBox>(find.byType(ColoredBox)).first;
      expect(fill.color, AureliTokens.light.canvas);
    });
  });

  group('theme', () {
    test('both themes carry the tokens and the bundled font', () {
      for (final (theme, tokens) in [
        (AppTheme.light, AureliTokens.light),
        (AppTheme.dark, AureliTokens.dark),
      ]) {
        expect(theme.extension<AureliTokens>(), isNotNull);
        expect(theme.scaffoldBackgroundColor, tokens.canvas);
        expect(theme.colorScheme.primary, tokens.brand);
        expect(theme.textTheme.bodyMedium!.fontFamily, 'Manrope');
      }
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    testWidgets('context.tokens follows the active theme', (tester) async {
      late AureliTokens seen;
      Widget probe() => Builder(builder: (c) {
            seen = c.tokens;
            return const SizedBox();
          });

      await tester.pumpWidget(_host(probe(), theme: AppTheme.dark));
      expect(seen.canvas, AureliTokens.dark.canvas);

      await tester.pumpWidget(_host(probe(), theme: AppTheme.light));
      await tester.pumpAndSettle(); // MaterialApp animates theme changes
      expect(seen.canvas, AureliTokens.light.canvas);
    });

    testWidgets('a plain MaterialApp still resolves tokens', (tester) async {
      late AureliTokens seen;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(builder: (c) {
          seen = c.tokens;
          return const SizedBox();
        }),
      ));
      expect(seen.canvas, AureliTokens.dark.canvas);
    });

    test('every bundled weight exists', () {
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
        expect(File('assets/fonts/Manrope-$w.ttf').existsSync(), isTrue, reason: w);
      }
      expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    });
  });

  group('theme choice', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<ThemeProvider> loaded() async {
      final p = ThemeProvider();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return p;
    }

    test('follows the system until the user picks one', () async {
      final p = await loaded();
      expect(p.themeMode, ThemeMode.system);
      expect(p.followsSystem, isTrue);
    });

    test('a previously saved choice is kept', () async {
      SharedPreferences.setMockInitialValues({'aureli_theme_mode': 'dark'});
      expect((await loaded()).themeMode, ThemeMode.dark);

      SharedPreferences.setMockInitialValues({'aureli_theme_mode': 'light'});
      expect((await loaded()).themeMode, ThemeMode.light);
    });

    test('a choice survives a restart, including going back to the system', () async {
      var p = await loaded();
      await p.setThemeMode(ThemeMode.dark);
      expect((await loaded()).themeMode, ThemeMode.dark);

      p = await loaded();
      await p.setThemeMode(ThemeMode.system);
      expect((await loaded()).themeMode, ThemeMode.system);
    });

    test('toggling while following the system flips what is on screen', () async {
      var p = await loaded();
      await p.toggleTheme(Brightness.dark);
      expect(p.themeMode, ThemeMode.light);

      p = await loaded();
      await p.setThemeMode(ThemeMode.system);
      await p.toggleTheme(Brightness.light);
      expect(p.themeMode, ThemeMode.dark);
    });
  });
}
