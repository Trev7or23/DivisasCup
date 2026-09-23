import 'package:divisas_cup/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      DivisasCupApp(exchangeRateRepository: FakeExchangeRateRepository()),
    );
    await tester.pumpAndSettle();
    // The app boots on the CUP price home; go to the calculator tab.
    await tester.tap(find.text('Calculator'));
    await tester.pumpAndSettle();
  }

  testWidgets('converts the default amount USD -> CUP', (tester) async {
    await pumpApp(tester);

    expect(find.text('1.00 USD = 720.00 CUP'), findsOneWidget);
    expect(find.text('1 USD = 720 CUP'), findsOneWidget);
    expect(find.text('1 CUP = 0.001389 USD'), findsOneWidget);
  });

  testWidgets('recomputes when the amount changes', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), '100');
    await tester.pumpAndSettle();

    expect(find.text('100.00 USD = 72,000.00 CUP'), findsOneWidget);
  });

  testWidgets('swap flips currencies so the result uses the inverse rate',
      (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), '100');
    await tester.pumpAndSettle();
    expect(find.text('100.00 USD = 72,000.00 CUP'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();

    expect(find.text('100.00 CUP = 0.14 USD'), findsOneWidget);
    expect(find.text('100.00 USD = 72,000.00 CUP'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('changing to or from a currency updates the result',
      (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), '2');
    await tester.pumpAndSettle();
    expect(find.text('2.00 USD = 1,440.00 CUP'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}