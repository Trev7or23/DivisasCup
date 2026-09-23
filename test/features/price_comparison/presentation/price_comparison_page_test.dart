import 'package:divisas_cup/app.dart';
import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {FakeExchangeRateRepository? repo}) async {
    await tester.pumpWidget(
      DivisasCupApp(exchangeRateRepository: repo ?? FakeExchangeRateRepository()),
    );
    await tester.pumpAndSettle();
    // The app boots on the CUP price home; go to the comparator tab.
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
  }

  void expectRow(WidgetTester tester, String from, String to, double value) {
    expect(
      find.text('1.00 $from = ${value.toStringAsFixed(2)} $to'),
      findsOneWidget,
    );
  }

  testWidgets('shows every currency against CUP by default', (tester) async {
    await pumpApp(tester);

    expectRow(tester, 'CUP', 'USD', 1 / 720);
    expectRow(tester, 'CUP', 'MLC', 1 / 720);
    expectRow(tester, 'CUP', 'EUR', 1 / 777.6);
    expect(find.text('Base currency'), findsOneWidget);
  });

  testWidgets('switching the base reloads the comparison rows', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Currency>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();

    expect(find.text('Comparing from USD'), findsOneWidget);
    expectRow(tester, 'USD', 'CUP', 720);
    expectRow(tester, 'USD', 'MLC', 1);
    expectRow(tester, 'USD', 'EUR', 720 / 777.6);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('refresh shows a success snack bar and re-renders', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('Rates updated'), findsOneWidget);
    expectRow(tester, 'CUP', 'USD', 1 / 720);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('shows rate load errors instead of rows', (tester) async {
    await pumpApp(tester, repo: FakeExchangeRateRepository(failOnRates: true));

    expect(find.text("Couldn't load rates"), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });
}