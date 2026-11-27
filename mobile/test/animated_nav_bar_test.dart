import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aureli/widgets/animated_nav_bar.dart';

const _destinations = [
  NavBarDestination(
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded),
  NavBarDestination(
      label: 'Transactions',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded),
  NavBarDestination(
      label: 'Budgets',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded),
  NavBarDestination(
      label: 'Analytics',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded),
  NavBarDestination(
      label: 'Lifetime',
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events_rounded),
];

Widget _host({
  required int index,
  required ValueChanged<int> onTap,
  bool reduceMotion = false,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: AnimatedNavBar(
          currentIndex: index,
          onTap: onTap,
          destinations: _destinations,
        ),
      ),
    ),
  );
}

Rect _capsuleRect(WidgetTester tester) {
  final positioned = tester.widget<AnimatedPositioned>(
    find.byType(AnimatedPositioned),
  );
  return Rect.fromLTWH(
    positioned.left!,
    positioned.top!,
    positioned.width!,
    positioned.height!,
  );
}

void main() {
  testWidgets('every tab name is shown, whole, at the narrowest phone width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(index: 0, onTap: (_) {}));

    for (final d in _destinations) {
      final label = find.text(d.label);
      expect(label, findsOneWidget);
      final text = tester.widget<Text>(label);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.softWrap, isFalse);

      // The label is scaled to fit its slot rather than clipped by it.
      final box = tester.getRect(label);
      final slot = tester.getRect(
        find.ancestor(of: label, matching: find.byType(InkResponse)).first,
      );
      expect(box.left, greaterThanOrEqualTo(slot.left));
      expect(box.right, lessThanOrEqualTo(slot.right));
    }
  });

  testWidgets('tapping a tab reports its index', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_host(index: 0, onTap: taps.add));

    await tester.tap(find.text('Transactions'));
    await tester.tap(find.text('Lifetime'));
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));

    expect(taps, [1, 4, 2]);
  });

  testWidgets('selected tab shows the filled icon, others the outline',
      (tester) async {
    await tester.pumpWidget(_host(index: 3, onTap: (_) {}));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_outlined), findsNothing);
    expect(find.byIcon(Icons.space_dashboard_outlined), findsOneWidget);
    expect(find.byIcon(Icons.space_dashboard_rounded), findsNothing);
  });

  testWidgets('the capsule glides to the new tab instead of jumping',
      (tester) async {
    await tester.pumpWidget(_host(index: 0, onTap: (_) {}));
    await tester.pumpAndSettle();
    final start = _capsuleRect(tester);

    await tester.pumpWidget(_host(index: 4, onTap: (_) {}));
    await tester.pump(const Duration(milliseconds: 100));
    final midway = tester.getRect(
      find.descendant(
        of: find.byType(AnimatedPositioned),
        matching: find.byType(DecoratedBox),
      ),
    );
    await tester.pumpAndSettle();
    final end = _capsuleRect(tester);

    expect(end.left, greaterThan(start.left));
    expect(midway.left, greaterThan(start.left));
    expect(midway.left, lessThan(end.left));
  });

  testWidgets('reduced motion moves the capsule immediately', (tester) async {
    await tester.pumpWidget(_host(index: 0, onTap: (_) {}, reduceMotion: true));
    await tester.pumpWidget(_host(index: 4, onTap: (_) {}, reduceMotion: true));
    await tester.pump();

    final settled = _capsuleRect(tester);
    final onScreen = tester.getRect(
      find.descendant(
        of: find.byType(AnimatedPositioned),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(onScreen.left, closeTo(settled.left, 0.5));
  });

  testWidgets('renders in the dark theme with semantics for the selection',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(index: 2, onTap: (_) {}, brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Budgets')),
      matchesSemantics(
        label: 'Budgets',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
