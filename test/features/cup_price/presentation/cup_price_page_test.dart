import 'package:divisas_cup/app.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fakes.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester,
      {FakeExchangeRateRepository? repo}) async {
    await tester.pumpWidget(
      DivisasCupApp(exchangeRateRepository: repo ?? FakeExchangeRateRepository()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('boots on the CUP price home showing today and last week',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('CUP Price'), findsOneWidget);
    expect(find.text('Current price'), findsOneWidget);
    expect(find.textContaining('720.00 CUP = 1.00 USD'), findsOneWidget);
    expect(find.text('Last week'), findsOneWidget);
    expect(find.text('View history'), findsOneWidget);
  });

  testWidgets('opens the history chart from the home screen', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('View history'));
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);

    // Pop back so the global router is left on the home route; otherwise the
    // next test in this file would boot on History instead of /cup-price.
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('refresh shows a success snack bar', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('Rates updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('shows the load error state when the price series fails',
      (tester) async {
    await pumpApp(tester, repo: FakeExchangeRateRepository(failOnSeries: true));

    expect(find.textContaining('Unexpected error'), findsOneWidget);
    expect(find.textContaining('720.00 CUP = 1.00 USD'), findsNothing);
  });

  testWidgets('history shows an error and retry instead of a stuck spinner'
      ' when the series fails', (tester) async {
    await pumpApp(tester, repo: FakeExchangeRateRepository(failOnSeries: true));

    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/cup-price/history');
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('History'), findsOneWidget);
    expect(find.textContaining('Unexpected error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/cup-price');
    await tester.pumpAndSettle();
  });
}