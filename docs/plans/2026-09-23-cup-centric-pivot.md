# DivisasCUP — Giro CUP-céntrico (Implementación Plan)

> **For agentic workers:** Use `mobiai-mobile-executing-plans-with-subagents` (recommended) or
> `mobiai-mobile-executing-plans` to implement this plan task-by-task. Steps use checkbox syntax
> for tracking.
>
> **Nota:** el repo **no es un repositorio git** (`AGENTS.md`). No hay pasos de commit; cada tarea
> termina con un **checkpoint de verificación** (test/analyze). Si más adelante se inicializa git,
> revisar y commitear por agrupación lógica de tasks (1–8 = pivot de datos; 9–13 = features + wiring;
> 14–15 = docs + gate).

**Goal:** Re-anclar DivisasCUP al CUP (ancla interna CUP; set USD/MLC/EUR/CUP), agregar una home que
muestra el precio del CUP (actual vs. hace una semana) y un historial con gráfico fl_chart.

**Architecture:** Se respeta el Clean Architecture actual. El pivot mantiene la regla "un seed único +
pares derivados" (`FakeRates` = el seed, derivación `rate(A→B) = priceInCup(A)/priceInCup(B)`). La
serie temporal y los métodos nuevos viven en `core/domain` (contrato + entidad) y en
`features/price_comparison/data/` (el data stack); el nuevo feature `cup_price` es **presentation-only**
(consumidor fino del mismo repositorio). El historial es una ruta pushada fuera del ShellRoute.

**Tech Stack:** Flutter 3.47/Dart 3.13, Provider + ChangeNotifier, go_router, sqflite (v2 de esquema,
FFI en tests), fl_chart (nueva dep), flutter_localizations (es/en), `sqflite_common_ffi` en tests.

**Platform:** Flutter (Android/iOS).

---

## Mapa de archivos

**Create:**
- `lib/core/constants/fake_rates.dart` (rework completo del seed + serie)
- `lib/core/domain/entities/cup_price_point.dart`
- `lib/features/price_comparison/data/models/cup_price_point_model.dart`
- `lib/features/cup_price/presentation/providers/cup_price_provider.dart`
- `lib/features/cup_price/presentation/pages/cup_price_page.dart`
- `lib/features/cup_price/presentation/pages/cup_price_history_page.dart`
- `lib/features/cup_price/presentation/widgets/price_display_card.dart`
- `lib/features/cup_price/presentation/widgets/week_delta_chip.dart`
- `lib/features/cup_price/presentation/widgets/history_chart.dart`
- `test/core/constants/fake_rates_test.dart`
- `test/features/cup_price/presentation/cup_price_page_test.dart`
- `test/features/cup_price/presentation/cup_price_provider_test.dart`

**Modify:**
- `pubspec.yaml` — `fl_chart: ^1.0.0`
- `lib/core/domain/repositories/exchange_rate_repository.dart` — +3 métodos de serie
- `lib/features/price_comparison/data/datasources/exchange_rate_data_source.dart` — rename `getUnitsPerUsd`
  → `getPriceInCup`; +3 métodos de serie
- `lib/features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart` — mismo cambio
- `lib/features/price_comparison/data/datasources/local_exchange_rate_data_source.dart` — schema v2,
  serie, refresh, re-ancla CUP
- `lib/features/price_comparison/data/repositories/exchange_rate_repository_impl.dart` — nueva fórmula + métodos
- `test/helpers/fakes.dart` — nuevos métodos + flag `failOnSeries`
- `test/features/price_comparison/data/datasources/mock_exchange_rate_data_source_test.dart`
- `test/features/price_comparison/data/datasources/local_exchange_rate_data_source_test.dart`
- `test/features/price_comparison/data/repositories/exchange_rate_repository_impl_test.dart`
- `test/features/price_comparison/domain/usecases/usecases_test.dart`
- `test/features/currency_calculator/domain/usecases/convert_currency_test.dart`
- `lib/features/price_comparison/presentation/providers/price_comparison_provider.dart`
- `lib/features/currency_calculator/presentation/providers/currency_calculator_provider.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`
- `lib/core/router/app_router.dart`
- `lib/core/widgets/home_shell.dart`
- `lib/app.dart`
- `test/features/price_comparison/presentation/price_comparison_page_test.dart`
- `test/features/currency_calculator/presentation/currency_calculator_page_test.dart`
- `AGENTS.md`, `README.md`

**Unchanged:** `Currency`, `ExchangeRate`, `CurrencyFormatter`, `AppSnackBar`,
`AppTheme`, `CurrencyDropdownButton`, `ComparisonTile`, `AmountField`, `ResultCard`,
`CurrencySwapRow`, `test/core/domain/entities/exchange_rate_test.dart`,
`test/core/utils/currency_formatter_test.dart`.

---

## Task 0: Línea base (verificar que arranca verde)

- [ ] **Step 1: Correr análisis y suite completa**

Run: `flutter analyze && flutter test`
Expected: 0 issues, 30+ tests PASS.

---

## Task 1: Agregar `fl_chart`

**Files:**
- Modify: `pubspec.yaml` (dependencies block, tras `intl`)

- [ ] **Step 1: Editar dependencias**

```yaml
  go_router: ^16.0.0
  sqflite: ^2.4.0
  intl: ^0.20.3
  fl_chart: ^1.0.0
```

- [ ] **Step 2: Instalar y verificar**

Run: `flutter pub get && flutter analyze`
Expected: `flutter pub get` resuelve `fl_chart ^1.0.0`; `flutter analyze` sin issues.

---

## Task 2: Entidad `CupPricePoint`

**Files:**
- Create: `lib/core/domain/entities/cup_price_point.dart`

- [ ] **Step 1: Escribir la entidad**

```dart
/// One point in the CUP price history: how many CUP one USD buys on [date].
///
/// Immutable value object, same pattern as [Currency]/[ExchangeRate]; equality
/// compares `date + cupPerUsd` so points built in different layers compare equal.
class CupPricePoint {
  const CupPricePoint({required this.date, required this.cupPerUsd});

  /// Day the price was sampled (local midnight when synthetic).
  final DateTime date;

  /// CUP needed to buy 1 USD that day.
  final double cupPerUsd;

  @override
  bool operator ==(Object other) =>
      other is CupPricePoint &&
      other.date == date &&
      other.cupPerUsd == cupPerUsd;

  @override
  int get hashCode => Object.hash(date, cupPerUsd);

  @override
  String toString() => 'CupPricePoint(${date.toIso8601String()}, $cupPerUsd)';
}
```

- [ ] **Step 2: Verificar compilación**

Run: `flutter analyze`
Expected: sin issues.

---

## Task 3: Seed CUP-anchored + serie determinística (`FakeRates`)

**Files:**
- Modify: `lib/core/constants/fake_rates.dart` (reemplazo completo)

- [ ] **Step 1: Escribir el seed nuevo**

```dart
import 'dart:math' as math;

import '../domain/entities/cup_price_point.dart';

/// Sample anchored rates used for the fully-offline first phase.
///
/// The anchor is the Cuban Peso: [seed] holds each currency's `priceInCup`,
/// i.e. how many CUP one unit of that currency buys. Cross-rates are derived
/// at the repository level
/// (`rate A->B = priceInCup(A) / priceInCup(B)`), so the seed can never
/// contain conflicting hand-written pairs and adding a currency is a
/// single-line change.
class FakeRates {
  const FakeRates._();

  /// `(code, name, symbol, decimalDigits, priceInCup)`.
  static const List<(String, String, String, int, double)> seed = [
    ('CUP', 'Cuban Peso', r'$', 2, 1.0),
    ('USD', 'US Dollar', r'$', 2, 720.0),
    ('MLC', 'MLC', r'$', 2, 720.0),
    ('EUR', 'Euro', r'€', 2, 777.6),
  ];

  static Map<String, double> get priceInCup => {
        for (final (code, _, _, _, price) in seed) code: price,
      };

  /// Length of the seeded daily CUP-price series.
  static const int seriesDays = 90;

  /// Deterministic ~90-day daily series ending exactly at the current USD
  /// price (720 CUP), so the "last week" point always lands on the day
  /// `today - 7 days`. No randomness: value(0) = 480 and value(seriesDays-1)
  /// = 720 exactly (sine term is 0 at both ends); slope + oscillation keep it
  /// monotonically increasing.
  static List<CupPricePoint> series({DateTime? relativeTo}) {
    final now = relativeTo ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final n = seriesDays - 1;
    return List.generate(seriesDays, (i) {
      final value = 480.0 +
          240.0 * (i / n) +
          6.0 * math.sin(math.pi * i / n * 3.0);
      return CupPricePoint(
        date: today.subtract(Duration(days: n - i)),
        cupPerUsd: value,
      );
    });
  }
}
```

- [ ] **Step 2: Escribir el test del seed**

Create: `test/core/constants/fake_rates_test.dart`

```dart
import 'package:divisas_cup/core/constants/fake_rates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeRates', () {
    test('seed exposes CUP-anchored prices for the Cuban set', () {
      expect(FakeRates.seed.map((s) => s.$1), ['CUP', 'USD', 'MLC', 'EUR']);
      expect(FakeRates.priceInCup['CUP'], 1);
      expect(FakeRates.priceInCup['USD'], 720);
      expect(FakeRates.priceInCup['MLC'], 720);
      expect(FakeRates.priceInCup['EUR'], closeTo(777.6, 1e-9));
      expect(FakeRates.priceInCup.containsKey('MXN'), isFalse);
    });

    test('series is deterministic, daily and ends at the current USD price',
        () {
      final today = DateTime(2026, 9, 23);
      final series = FakeRates.series(relativeTo: today);

      expect(series, hasLength(FakeRates.seriesDays));
      expect(series.first.date, DateTime(2026, 6, 26));
      expect(series.last.date, today);
      expect(series.first.cupPerUsd, 480);
      expect(series.last.cupPerUsd, closeTo(720, 1e-6));
      expect(series.map((p) => p.date).toSet().length, FakeRates.seriesDays);
    });

    test('series has a point on exactly today minus 7 days', () {
      final today = DateTime(2026, 9, 23);
      final series = FakeRates.series(relativeTo: today);
      final lastWeek = DateTime(2026, 9, 16);
      expect(series.where((p) => p.date == lastWeek), hasLength(1));
    });
  });
}
```

- [ ] **Step 3: Correr el test**

Run: `flutter test test/core/constants/fake_rates_test.dart`
Expected: 3 tests PASS. (Si `FakeRates.series` falla por 1e-6, revisar que el término seno del último
punto sea ~0.)

---

## Task 4: Contrato del data source + Mock (rename + serie)

**Files:**
- Modify: `lib/features/price_comparison/data/datasources/exchange_rate_data_source.dart` (reemplazo)
- Modify: `lib/features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart` (reemplazo)
- Create: `lib/features/price_comparison/data/models/cup_price_point_model.dart`

- [ ] **Step 1: Actualizar el contrato**

`exchange_rate_data_source.dart` reemplazo completo:

```dart
import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';

/// Low-level rate source contract.
///
/// Implementations only understand a single anchored question — "how many CUP
/// does one unit of X buy?" — plus the supported currency list. Cross-rate
/// derivation between two non-CUP currencies lives in the repository, so every
/// source stays impossible to seed inconsistently.
abstract interface class ExchangeRateDataSource {
  Future<List<Currency>> getSupportedCurrencies();

  /// CUP per single unit of [currencyCode] (how many CUP buy 1 unit).
  /// Throws [RateNotFoundException] when the currency has no anchored rate.
  Future<double> getPriceInCup(String currencyCode);

  /// Latest point of the CUP price series.
  Future<CupPricePoint> getCurrentCupPrice();

  /// Full CUP price series, oldest first.
  Future<List<CupPricePoint>> getCupPriceHistory();

  /// Appends (or updates) a new CUP price point for "today" and returns it.
  Future<CupPricePoint> refreshCupPrice();
}
```

- [ ] **Step 2: Writer el model de persistencia**

Create: `lib/features/price_comparison/data/models/cup_price_point_model.dart`

```dart
import '../../../../core/domain/entities/cup_price_point.dart';

/// Persistence mapping for [CupPricePoint] backed by the `cup_price_series`
/// table. Naturally a subtype of the domain entity.
class CupPricePointModel extends CupPricePoint {
  const CupPricePointModel({required super.date, required super.cupPerUsd});

  factory CupPricePointModel.fromMap(Map<String, Object?> map) =>
      CupPricePointModel(
        date: DateTime.fromMillisecondsSinceEpoch(map['sampled_at'] as int),
        cupPerUsd: (map['cup_per_usd'] as num).toDouble(),
      );

  Map<String, Object?> toMap() => {
        'sampled_at': date.millisecondsSinceEpoch,
        'cup_per_usd': cupPerUsd,
      };
}
```

- [ ] **Step 3: Actualizar el Mock**

`mock_exchange_rate_data_source.dart` reemplazo completo:

```dart
import '../../../../core/constants/fake_rates.dart';
import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/errors/failure.dart';
import 'exchange_rate_data_source.dart';

/// In-memory, synchronous-free fake source used for dev, widget tests and as
/// the seed provider for the SQLite source on first launch.
class MockExchangeRateDataSource implements ExchangeRateDataSource {
  const MockExchangeRateDataSource();

  @override
  Future<List<Currency>> getSupportedCurrencies() async =>
      FakeRates.seed
          .map(
            (s) => Currency(
              code: s.$1,
              name: s.$2,
              symbol: s.$3,
              decimalDigits: s.$4,
            ),
          )
          .toList();

  @override
  Future<double> getPriceInCup(String currencyCode) async {
    final price = FakeRates.priceInCup[currencyCode];
    if (price == null) {
      throw RateNotFoundException(
        'No CUP anchor rate for "$currencyCode"',
      );
    }
    return price;
  }

  @override
  Future<CupPricePoint> getCurrentCupPrice() async => FakeRates.series().last;

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async => FakeRates.series();

  @override
  Future<CupPricePoint> refreshCupPrice() async => FakeRates.series().last;
}
```

- [ ] **Step 4: Actualizar el test del mock**

`test/features/price_comparison/data/datasources/mock_exchange_rate_data_source_test.dart` reemplazo
completo:

```dart
import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockExchangeRateDataSource', () {
    const source = MockExchangeRateDataSource();

    test('exposes the seeded currencies in order', () async {
      final currencies = await source.getSupportedCurrencies();
      expect(
        currencies.map((c) => c.code),
        ['CUP', 'USD', 'MLC', 'EUR'],
      );
      expect(currencies.first.symbol, r'$');
      expect(currencies.last.symbol, r'€');
    });

    test('returns CUP-anchored prices', () async {
      expect(await source.getPriceInCup('CUP'), 1);
      expect(await source.getPriceInCup('USD'), 720);
      expect(await source.getPriceInCup('MLC'), 720);
      expect(await source.getPriceInCup('EUR'), closeTo(777.6, 1e-9));
    });

    test('exposes a deterministic CUP price history', () async {
      final history = await source.getCupPriceHistory();
      expect(history, hasLength(FakeRates.seriesDays));
      expect(history.first.cupPerUsd, 480);
      expect(history.last.cupPerUsd, closeTo(720, 1e-6));
    });

    test('throws RateNotFoundException for unknown codes', () {
      expect(
        source.getPriceInCup('XXX'),
        throwsA(isA<RateNotFoundException>()),
      );
    });
  });
}
```

El archivo importa `FakeRates` (agregar la línea `import
'package:divisas_cup/core/constants/fake_rates.dart';`).

- [ ] **Step 5: Correr el test** `flutter test test/features/price_comparison/data/datasources/mock_exchange_rate_data_source_test.dart`
Expected: 4 tests PASS.

---

## Task 5: Data source local (SQLite v2 + serie + refresh)

**Files:**
- Modify: `lib/features/price_comparison/data/datasources/local_exchange_rate_data_source.dart`
  (reemplazo completo del cuerpo de clase)
- Modify: `test/features/price_comparison/data/datasources/local_exchange_rate_data_source_test.dart`
  (reemplazo completo)

- [ ] **Step 1: Reescribir el data source local**

`local_exchange_rate_data_source.dart` reemplazo completo:

```dart
import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/fake_rates.dart';
import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/errors/failure.dart';
import '../models/cup_price_point_model.dart';
import '../models/currency_model.dart';
import 'exchange_rate_data_source.dart';

/// SQLite-backed source of truth once the app has launched at least once.
///
/// - Creates three tables (`currencies`, `exchange_rates`, `cup_price_series`)
///   on first open and **seeds them** from [seedSource], so the app is fully
///   functional offline from the very first run.
/// - `cup_price_series` seeds a deterministic ~90-day CUP/CLP price history.
/// - The database is opened lazily on the first read and then cached.
/// - Injectable [DatabaseFactory]/path make unit tests run with an in-memory
///   FFI database (no device or plugin needed).
class LocalExchangeRateDataSource implements ExchangeRateDataSource {
  LocalExchangeRateDataSource({
    required this.seedSource,
    this.factoryOverride,
    this.databasePath,
  });

  static const String _dbFileName = 'divisas_cup.db';
  static const int _dbVersion = 2;
  static const String _cupCode = 'CUP';
  static const double _eurToUsdFactor = 1.08;

  /// Source consulted on first launch to populate the SQLite seed tables.
  final ExchangeRateDataSource seedSource;

  /// Used by tests to point at an in-memory FFI factory instead of the
  /// platform plugin.
  final DatabaseFactory? factoryOverride;
  final String? databasePath;

  Database? _database;

  Future<Database> _open() async {
    final cached = _database;
    if (cached != null) return cached;

    final factory = factoryOverride ?? databaseFactory;
    final path = databasePath ??
        '${await factory.getDatabasesPath()}/$_dbFileName';

    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    _database = db;
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seed(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE cup_price_series (
          sampled_at INTEGER PRIMARY KEY,
          cup_per_usd REAL NOT NULL
        )
      ''');
      await db.delete('currencies');
      await db.delete('exchange_rates');
      await _seed(db);
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE currencies (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        symbol TEXT NOT NULL,
        decimal_digits INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE exchange_rates (
        base_code TEXT NOT NULL,
        quote_code TEXT NOT NULL,
        rate REAL NOT NULL,
        updated_at INTEGER,
        PRIMARY KEY (base_code, quote_code)
      )
    ''');
    await db.execute('''
      CREATE TABLE cup_price_series (
        sampled_at INTEGER PRIMARY KEY,
        cup_per_usd REAL NOT NULL
      )
    ''');
  }

  Future<void> _seed(Database db) async {
    final currencies = await seedSource.getSupportedCurrencies();
    final batch = db.batch();
    for (final currency in currencies) {
      final price = await seedSource.getPriceInCup(currency.code);
      batch.insert(
        'currencies',
        CurrencyModel.fromEntity(currency).toMap(),
      );
      batch.insert('exchange_rates', {
        'base_code': _cupCode,
        'quote_code': currency.code,
        'rate': price,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await batch.commit(noResult: true);
    await _seedSeries(db);
  }

  Future<void> _seedSeries(Database db) async {
    final batch = db.batch();
    for (final point in FakeRates.series()) {
      batch.insert(
        'cup_price_series',
        CupPricePointModel.fromPoint(point).toMap(),
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Currency>> getSupportedCurrencies() async {
    final db = await _open();
    try {
      final rows = await db.query('currencies');
      return rows.map(CurrencyModel.fromMap).toList();
    } catch (error) {
      throw _asFailure(error, 'Could not read currencies');
    }
  }

  @override
  Future<double> getPriceInCup(String currencyCode) async {
    final db = await _open();
    try {
      final rows = await db.query(
        'exchange_rates',
        where: 'base_code = ? AND quote_code = ?',
        whereArgs: [_cupCode, currencyCode],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw RateNotFoundException(
          'No CUP anchor rate for "$currencyCode"',
        );
      }
      return (rows.first['rate'] as num).toDouble();
    } on Failure {
      rethrow;
    } catch (error) {
      throw _asFailure(error, 'Could not read CUP anchor for "$currencyCode"');
    }
  }

  @override
  Future<CupPricePoint> getCurrentCupPrice() async {
    final db = await _open();
    try {
      final rows = await db.query(
        'cup_price_series',
        orderBy: 'sampled_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const RateNotFoundException('No CUP price series');
      }
      return CupPricePointModel.fromMap(rows.first);
    } on Failure {
      rethrow;
    } catch (error) {
      throw _asFailure(error, 'Could not read current CUP price');
    }
  }

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async {
    final db = await _open();
    try {
      final rows = await db.query('cup_price_series', orderBy: 'sampled_at ASC');
      return rows.map(CupPricePointModel.fromMap).toList();
    } catch (error) {
      throw _asFailure(error, 'Could not read CUP price history');
    }
  }

  @override
  Future<CupPricePoint> refreshCupPrice() async {
    final db = await _open();
    try {
      final current = await getCurrentCupPrice();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dayNum = today.millisecondsSinceEpoch ~/ 86400000;
      final sign = dayNum.isEven ? 1.0 : -1.0;
      final pct = 0.005 + (dayNum % 3) * 0.005;
      final next = (current.cupPerUsd * (1 + sign * pct)).clamp(1.0, 100000.0);
      final point = CupPricePoint(date: today, cupPerUsd: next);

      await db.insert(
        'cup_price_series',
        CupPricePointModel.fromPoint(point).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final batch = db.batch();
      batch.update(
        'exchange_rates',
        {'rate': next},
        where: 'base_code = ? AND quote_code = ?',
        whereArgs: [_cupCode, 'USD'],
      );
      batch.update(
        'exchange_rates',
        {'rate': next},
        where: 'base_code = ? AND quote_code = ?',
        whereArgs: [_cupCode, 'MLC'],
      );
      batch.update(
        'exchange_rates',
        {'rate': next * _eurToUsdFactor},
        where: 'base_code = ? AND quote_code = ?',
        whereArgs: [_cupCode, 'EUR'],
      );
      await batch.commit(noResult: true);
      return point;
    } on Failure {
      rethrow;
    } catch (error) {
      throw _asFailure(error, 'Could not refresh CUP price');
    }
  }

  Failure _asFailure(Object error, String fallback) =>
      error is Failure ? error : DataSourceFailure(fallback);

  /// Closes the cached connection; used mainly in tests.
  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
```

> **Nota plan (corregida en ejecución):** `CupPricePointModel` es un twin de **composición** (no
> extiende `CupPricePoint`); `fromMap/toPoint` lo convierten. Por eso `getCurrentCupPrice` retorna
> `CupPricePointModel.fromMap(rows.first).toPoint()` y `getCupPriceHistory` mapea con `.map((row) =>
> CupPricePointModel.fromMap(row).toPoint())`. (El fragmento original 701-713 pedía `extends`; quedó
> obsoleto tras la Task 4 — no modificar el modelo.)

- [ ] **Step 2: Reescribir el test del data source local**

`test/features/price_comparison/data/datasources/local_exchange_rate_data_source_test.dart` reemplazo
completo:

```dart
import 'dart:io';

import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/local_exchange_rate_data_source.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  LocalExchangeRateDataSource buildSource({String? path}) =>
      LocalExchangeRateDataSource(
        seedSource: const MockExchangeRateDataSource(),
        factoryOverride: databaseFactoryFfi,
        databasePath: path ?? inMemoryDatabasePath,
      );

  group('LocalExchangeRateDataSource', () {
    test('seeds currencies and CUP anchors on first open', () async {
      final source = buildSource();

      final currencies = await source.getSupportedCurrencies();
      expect(currencies.map((c) => c.code), ['CUP', 'USD', 'MLC', 'EUR']);

      expect(await source.getPriceInCup('CUP'), 1);
      expect(await source.getPriceInCup('USD'), 720);
      expect(await source.getPriceInCup('MLC'), 720);
      expect(await source.getPriceInCup('EUR'), closeTo(777.6, 1e-9));
    });

    test('seeds the CUP price series and exposes current + history', () async {
      final source = buildSource();

      final history = await source.getCupPriceHistory();
      expect(history, hasLength(90));
      expect(history, orderedEquals(
        [...history]..sort((a, b) => a.date.compareTo(b.date)),
      ));

      final current = await source.getCurrentCupPrice();
      expect(current, history.last);
      expect(current.cupPerUsd, closeTo(720, 1e-6));
    });

    test('throws RateNotFoundException for unknown codes', () async {
      final source = buildSource();
      expect(
        source.getPriceInCup('XXX'),
        throwsA(isA<RateNotFoundException>()),
      );
    });

    test('refresh inserts/updates today and re-anchors USD/MLC/EUR', () async {
      final source = buildSource();
      final before = await source.getCurrentCupPrice();

      final point = await source.refreshCupPrice();

      expect(point.date, DateTime.now().dateTruncated);
      expect(point.cupPerUsd,
          closeTo(before.cupPerUsd, before.cupPerUsd * 0.03));

      expect(await source.getPriceInCup('USD'), point.cupPerUsd);
      expect(await source.getPriceInCup('MLC'), point.cupPerUsd);
      expect(await source.getPriceInCup('EUR'),
          closeTo(point.cupPerUsd * 1.08, 1e-9));

      final history = await source.getCupPriceHistory();
      expect(history.last.cupPerUsd, point.cupPerUsd);

      await source.refreshCupPrice();
      expect(await source.getCupPriceHistory(), hasLength(history.length));
    });

    test('does not duplicate the seed when the same file is reopened', () async {
      final dir = await Directory.systemTemp.createTemp('divisas_cup_test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/seed.db';

      final first = buildSource(path: path);
      await first.getSupportedCurrencies();
      await first.close();

      final second = buildSource(path: path);
      final currencies = await second.getSupportedCurrencies();
      expect(currencies, hasLength(4));
      final history = await second.getCupPriceHistory();
      expect(history, hasLength(90));
      await second.close();
    });

    test('upgrades a v1 database adding the series table', () async {
      final dir = await Directory.systemTemp.createTemp('divisas_cup_test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/migrate.db';

      final factory = databaseFactoryFfi;
      final legacy = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE currencies (
                code TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                symbol TEXT NOT NULL,
                decimal_digits INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE exchange_rates (
                base_code TEXT NOT NULL,
                quote_code TEXT NOT NULL,
                rate REAL NOT NULL,
                updated_at INTEGER,
                PRIMARY KEY (base_code, quote_code)
              )
            ''');
            await db.insert('currencies',
                {'code': 'CUP', 'name': 'Cuban Peso', 'symbol': r'$', 'decimal_digits': 2});
          },
        ),
      );
      await legacy.close();

      final source = buildSource(path: path);
      final history = await source.getCupPriceHistory();
      expect(history, hasLength(90));
      await source.close();
    });
  });
}

extension on DateTime {
  DateTime get dateTruncated => DateTime(year, month, day);
}
```

(Si el helper `dateTruncated` te parece excesivo, compará `point.date` contra
`DateTime.now()` truncado localmente; el extracto de arriba es la forma canónica.)

- [ ] **Step 3: Correr el test** `flutter test test/features/price_comparison/data/datasources/local_exchange_rate_data_source_test.dart`
Expected: 6 tests PASS.

---

## Task 6: Repository impl (fórmula CUP + métodos de serie)

**Files:**
- Modify: `lib/features/price_comparison/data/repositories/exchange_rate_repository_impl.dart`
- Modify: `lib/core/domain/repositories/exchange_rate_repository.dart`
- Modify: `test/features/price_comparison/data/repositories/exchange_rate_repository_impl_test.dart`

- [ ] **Step 1: Extender el contrato**

`lib/core/domain/repositories/exchange_rate_repository.dart` — agregar import y métodos:

```dart
import '../entities/cup_price_point.dart';
import '../entities/currency.dart';
import '../entities/exchange_rate.dart';

abstract interface class ExchangeRateRepository {
  Future<List<Currency>> getSupportedCurrencies();

  Future<ExchangeRate> getRate({
    required Currency base,
    required Currency quote,
  });

  /// All rates from [base] to every other supported currency.
  Future<List<ExchangeRate>> getRatesForBase(Currency base);

  /// Latest CUP price point.
  Future<CupPricePoint> getCurrentCupPrice();

  /// Full CUP price series, oldest first.
  Future<List<CupPricePoint>> getCupPriceHistory();

  /// Appends (or updates) today's CUP price point and returns it.
  Future<CupPricePoint> refreshCupPrice();
}
```

- [ ] **Step 2: Actualizar el impl**

`lib/features/price_comparison/data/repositories/exchange_rate_repository_impl.dart` — cambiar
imports, fórmula `_derive` y agregar los 3 métodos:

```dart
import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/domain/entities/exchange_rate.dart';
import '../../../../core/domain/repositories/exchange_rate_repository.dart';
import '../../../../core/errors/failure.dart';
import '../datasources/exchange_rate_data_source.dart';
import '../models/exchange_rate_model.dart';

/// Bridge between the [ExchangeRateDataSource] implementations and the
/// [ExchangeRateRepository] contract consumed by use cases and widgets.
///
/// Derives `base -> quote` from the two CUP anchors:
/// `rate(A -> B) = priceInCup(A) / priceInCup(B)`.
class ExchangeRateRepositoryImpl implements ExchangeRateRepository {
  ExchangeRateRepositoryImpl({required this.dataSource});

  final ExchangeRateDataSource dataSource;

  // ... getSupportedCurrencies, getRate, getRatesForBase igual que antes ...

  Future<ExchangeRate> _derive({
    required Currency base,
    required Currency quote,
  }) async {
    final basePrice = await dataSource.getPriceInCup(base.code);
    final quotePrice = await dataSource.getPriceInCup(quote.code);
    return ExchangeRateModel(
      base: base,
      quote: quote,
      rate: basePrice / quotePrice,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<CupPricePoint> getCurrentCupPrice() async {
    try {
      return await dataSource.getCurrentCupPrice();
    } on Failure {
      rethrow;
    } catch (error) {
      throw DataSourceFailure('Could not read current CUP price ($error)');
    }
  }

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async {
    try {
      return await dataSource.getCupPriceHistory();
    } on Failure {
      rethrow;
    } catch (error) {
      throw DataSourceFailure('Could not read CUP price history ($error)');
    }
  }

  @override
  Future<CupPricePoint> refreshCupPrice() async {
    try {
      return await dataSource.refreshCupPrice();
    } on Failure {
      rethrow;
    } catch (error) {
      throw DataSourceFailure('Could not refresh CUP price ($error)');
    }
  }
}
```

- [ ] **Step 3: Reescribir el test del repo**

`test/features/price_comparison/data/repositories/exchange_rate_repository_impl_test.dart` reemplazo
completo:

```dart
import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/exchange_rate_data_source.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/local_exchange_rate_data_source.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart';
import 'package:divisas_cup/features/price_comparison/data/repositories/exchange_rate_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const cup = Currency(code: 'CUP', name: 'Cuban Peso', symbol: r'$');
const usd = Currency(code: 'USD', name: 'US Dollar', symbol: r'$');
const mlc = Currency(code: 'MLC', name: 'MLC', symbol: r'$');
const eur = Currency(code: 'EUR', name: 'Euro', symbol: r'€');

void main() {
  setUpAll(sqfliteFfiInit);

  group('ExchangeRateRepositoryImpl', () {
    test('derives direct and cross rates from CUP anchors (mock source)',
        () async {
      final repo = ExchangeRateRepositoryImpl(
        dataSource: const MockExchangeRateDataSource(),
      );

      final usdToCup = await repo.getRate(base: usd, quote: cup);
      expect(usdToCup.rate, 720);

      final cupToUsd = await repo.getRate(base: cup, quote: usd);
      expect(cupToUsd.rate, closeTo(1 / 720, 1e-12));

      final usdToMlc = await repo.getRate(base: usd, quote: mlc);
      expect(usdToMlc.rate, 1);

      final usdToEur = await repo.getRate(base: usd, quote: eur);
      expect(usdToEur.rate, closeTo(720 / 777.6, 1e-9));
    });

    test('lists each non-base currency when given a base (local source)',
        () async {
      final local = LocalExchangeRateDataSource(
        seedSource: const MockExchangeRateDataSource(),
        factoryOverride: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(local.close);

      final repo = ExchangeRateRepositoryImpl(dataSource: local);
      final rates = await repo.getRatesForBase(usd);

      expect(rates, hasLength(3));
      expect(rates.every((r) => r.base == usd), isTrue);
      expect(
        rates.map((r) => r.quote.code).toSet(),
        {'CUP', 'MLC', 'EUR'},
      );
      final cupRate = rates.firstWhere((r) => r.quote == cup);
      expect(cupRate.rate, closeTo(720, 1e-9));
    });

    test('exposes the CUP price series', () async {
      final repo = ExchangeRateRepositoryImpl(
        dataSource: const MockExchangeRateDataSource(),
      );

      final history = await repo.getCupPriceHistory();
      expect(history, hasLength(90));
      expect((await repo.getCurrentCupPrice()).cupPerUsd, closeTo(720, 1e-6));
      expect((await repo.refreshCupPrice()).cupPerUsd, closeTo(720, 1e-6));
    });

    test('wraps raw backend errors into DataSourceFailure', () async {
      final repo = ExchangeRateRepositoryImpl(dataSource: _ThrowingSource());
      expect(
        repo.getSupportedCurrencies(),
        throwsA(isA<DataSourceFailure>()),
      );
      expect(
        repo.getRate(base: usd, quote: cup),
        throwsA(isA<DataSourceFailure>()),
      );
      expect(
        repo.getCupPriceHistory(),
        throwsA(isA<DataSourceFailure>()),
      );
    });

    test('propagates typed RateNotFoundException unchanged', () async {
      final repo = ExchangeRateRepositoryImpl(dataSource: _UnknownCodeSource());
      expect(
        repo.getRate(base: usd, quote: cup),
        throwsA(isA<RateNotFoundException>()),
      );
    });
  });
}

class _ThrowingSource implements ExchangeRateDataSource {
  @override
  Future<List<Currency>> getSupportedCurrencies() async =>
      throw StateError('boom');

  @override
  Future<double> getPriceInCup(String currencyCode) async =>
      throw StateError('boom');

  @override
  Future<CupPricePoint> getCurrentCupPrice() async => throw StateError('boom');

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async =>
      throw StateError('boom');

  @override
  Future<CupPricePoint> refreshCupPrice() async => throw StateError('boom');
}

class _UnknownCodeSource implements ExchangeRateDataSource {
  @override
  Future<List<Currency>> getSupportedCurrencies() async => const [cup, usd];

  @override
  Future<double> getPriceInCup(String currencyCode) async {
    if (currencyCode == 'USD') return 720;
    throw RateNotFoundException('No CUP anchor rate for "$currencyCode"');
  }

  @override
  Future<CupPricePoint> getCurrentCupPrice() async => throw StateError('boom');

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async =>
      throw StateError('boom');

  @override
  Future<CupPricePoint> refreshCupPrice() async => throw StateError('boom');
}
```

(agregar import `cup_price_point` al archivo de test).

- [ ] **Step 4: Correr el test** `flutter test test/features/price_comparison/data/repositories/exchange_rate_repository_impl_test.dart`
Expected: 5 tests PASS.

---

## Task 7: Fakes + tests de usecases y ConvertCurrency

**Files:**
- Modify: `test/helpers/fakes.dart`
- Modify: `test/features/price_comparison/domain/usecases/usecases_test.dart`
- Modify: `test/features/currency_calculator/domain/usecases/convert_currency_test.dart`

- [ ] **Step 1: Actualizar el fake**

`test/helpers/fakes.dart` — agregar import de `cup_price_point.dart`, flag `failOnSeries` y los 3
métodos:

```dart
import 'package:divisas_cup/core/domain/entities/cup_price_point.dart';
import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:divisas_cup/core/domain/entities/exchange_rate.dart';
import 'package:divisas_cup/core/domain/repositories/exchange_rate_repository.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart';
import 'package:divisas_cup/features/price_comparison/data/repositories/exchange_rate_repository_impl.dart';

/// Repository double used by widget/usecase tests. Success behaviour reuses
/// the real derivation logic on top of [MockExchangeRateDataSource] (no
/// SQLite/plugin needed); the `failOn*` flags simulate backend errors.
class FakeExchangeRateRepository implements ExchangeRateRepository {
  FakeExchangeRateRepository({
    this.failOnCurrencies = false,
    this.failOnRates = false,
    this.failOnSeries = false,
  }) : _delegate = ExchangeRateRepositoryImpl(
          dataSource: const MockExchangeRateDataSource(),
        );

  final bool failOnCurrencies;
  final bool failOnRates;
  final bool failOnSeries;
  final ExchangeRateRepositoryImpl _delegate;

  @override
  Future<List<Currency>> getSupportedCurrencies() async {
    if (failOnCurrencies) throw StateError('boom');
    return _delegate.getSupportedCurrencies();
  }

  @override
  Future<ExchangeRate> getRate({
    required Currency base,
    required Currency quote,
  }) async {
    if (failOnRates) throw StateError('boom');
    return _delegate.getRate(base: base, quote: quote);
  }

  @override
  Future<List<ExchangeRate>> getRatesForBase(Currency base) async {
    if (failOnRates) throw StateError('boom');
    return _delegate.getRatesForBase(base);
  }

  @override
  Future<CupPricePoint> getCurrentCupPrice() async {
    if (failOnSeries) throw StateError('boom');
    return _delegate.getCurrentCupPrice();
  }

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async {
    if (failOnSeries) throw StateError('boom');
    return _delegate.getCupPriceHistory();
  }

  @override
  Future<CupPricePoint> refreshCupPrice() async {
    if (failOnSeries) throw StateError('boom');
    return _delegate.refreshCupPrice();
  }
}
```

- [ ] **Step 2: Actualizar usecases_test**

`test/features/price_comparison/domain/usecases/usecases_test.dart` — reemplazar la expectativa del
set y los rates:

```dart
    test('returns the supported currency list', () async {
      final usecase =
          GetSupportedCurrencies(FakeExchangeRateRepository());
      final currencies = await usecase();
      expect(
        currencies.map((c) => c.code),
        ['CUP', 'USD', 'MLC', 'EUR'],
      );
    });
```

```dart
  group('GetRatesForBase', () {
    test('derives every non-base pair', () async {
      final usecase = GetRatesForBase(FakeExchangeRateRepository());
      const usd = Currency(code: 'USD', name: 'US Dollar', symbol: r'$');
      final rates = await usecase(usd);
      expect(rates.length, 3);
      expect(rates.every((r) => r.base == usd), isTrue);
      expect(
        rates.map((r) => r.quote.code).toSet(),
        {'CUP', 'MLC', 'EUR'},
      );
      expect(rates.firstWhere((r) => r.quote.code == 'CUP').rate, closeTo(720, 1e-9));
    });
  });
```

- [ ] **Step 3: Actualizar convert_currency_test**

`test/features/currency_calculator/domain/usecases/convert_currency_test.dart` reemplazo completo:

```dart
import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/currency_calculator/domain/usecases/convert_currency.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fakes.dart';

void main() {
  group('ConvertCurrency', () {
    const usd = Currency(code: 'USD', name: 'US Dollar', symbol: r'$');
    const cup = Currency(code: 'CUP', name: 'Cuban Peso', symbol: r'$');

    test('returns the direct base->quote rate and converts correctly', () async {
      final usecase = ConvertCurrency(FakeExchangeRateRepository());
      final rate = await usecase(from: usd, to: cup);
      expect(rate.rate, 720);
      expect(rate.convert(10), 7200);
    });

    test('returns the inverse rate when bases are swapped', () async {
      final usecase = ConvertCurrency(FakeExchangeRateRepository());
      final rate = await usecase(from: cup, to: usd);
      expect(rate.rate, closeTo(1 / 720, 1e-12));
    });

    test('wraps backend errors into UnexpectedFailure', () async {
      final usecase = ConvertCurrency(
        FakeExchangeRateRepository(failOnRates: true),
      );
      expect(usecase(from: usd, to: cup), throwsA(isA<UnexpectedFailure>()));
    });
  });
}
```

- [ ] **Step 4: Correr ambos tests**

Run: `flutter test test/features/price_comparison/domain/usecases/usecases_test.dart test/features/currency_calculator/domain/usecases/convert_currency_test.dart`
Expected: 5 tests PASS en total.

---

## Task 8: Defaults de los providers existentes

**Files:**
- Modify: `lib/features/price_comparison/presentation/providers/price_comparison_provider.dart`
- Modify: `lib/features/currency_calculator/presentation/providers/currency_calculator_provider.dart`

- [ ] **Step 1: Comparador — base por defecto CUP**

En `price_comparison_provider.dart`, reemplazar el body de `load()` para elegir CUP:

```dart
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _currencies = await _getCurrencies();
      _base ??= _pick(_currencies, 'CUP');
      if (_base != null) {
        await _loadRates();
      }
    } on Failure catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Currency? _pick(List<Currency> list, String code) {
    for (final currency in list) {
      if (currency.code == code) return currency;
    }
    return list.isEmpty ? null : list.first;
  }
```

- [ ] **Step 2: Calculadora — defaults USD→CUP**

En `currency_calculator_provider.dart`, reemplazar las dos líneas de `_from`/`_to` en `load()`:

```dart
      _currencies = await _getCurrencies();
      _from ??= _pick(_currencies, 'USD');
      _to ??= _pick(_currencies, 'CUP');
```

- [ ] **Step 3: Compilar**

Run: `flutter analyze`
Expected: sin issues.

---

## Task 9: i18n (ARB + gen-l10n)

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_es.arb`

- [ ] **Step 1: Agregar claves EN (template)**

En `app_en.arb`, tras `"footerHint"` agregar (mantener JSON válido — comas):

```json
  "priceLabel": "Price",
  "cupPriceTitle": "CUP Price",
  "historyTitle": "History",
  "currentPrice": "Current price",
  "lastWeek": "Last week",
  "viewHistory": "View history"
```

- [ ] **Step 2: Agregar claves ES**

En `app_es.arb`:

```json
  "priceLabel": "Precio",
  "cupPriceTitle": "Precio del CUP",
  "historyTitle": "Histórico",
  "currentPrice": "Precio actual",
  "lastWeek": "Semana pasada",
  "viewHistory": "Ver histórico"
```

- [ ] **Step 3: Regenerar**

Run: `flutter gen-l10n && flutter analyze`
Expected: `lib/l10n/generated/app_localizations.dart` regenerado; analyze sin issues.

---

## Task 10: Feature `cup_price` — provider y widgets

**Files:**
- Create: `lib/features/cup_price/presentation/providers/cup_price_provider.dart`
- Create: `lib/features/cup_price/presentation/widgets/price_display_card.dart`
- Create: `lib/features/cup_price/presentation/widgets/week_delta_chip.dart`
- Create: `lib/features/cup_price/presentation/widgets/history_chart.dart`
- Create: `test/features/cup_price/presentation/cup_price_provider_test.dart`

- [ ] **Step 1: Escribir el provider**

```dart
import 'package:flutter/foundation.dart';

import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/domain/repositories/exchange_rate_repository.dart';
import '../../../../core/errors/failure.dart';

/// Holds the state of the CUP Price home screen: current price, last-week
/// price, computed delta and the full history. Thin consumer of the shared
/// [ExchangeRateRepository]; there is no data layer inside this feature.
class CupPriceProvider extends ChangeNotifier {
  CupPriceProvider({required ExchangeRateRepository repository})
      : _repository = repository;

  final ExchangeRateRepository _repository;

  List<Currency> _currencies = const [];
  CupPricePoint? _current;
  CupPricePoint? _lastWeek;
  double? _deltaCup;
  double? _deltaPercent;
  List<CupPricePoint> _history = const [];
  bool _isLoading = true;
  Failure? _error;

  Currency? get cupCurrency => _pick('CUP');
  Currency? get usdCurrency => _pick('USD');
  CupPricePoint? get current => _current;
  CupPricePoint? get lastWeek => _lastWeek;
  double? get deltaCup => _deltaCup;
  double? get deltaPercent => _deltaPercent;
  List<CupPricePoint> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;
  Failure? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _fetch();
    } on Failure catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Appends today's point and reloads. Returns `true` on success so the page
  /// can show the matching snack bar.
  Future<bool> refresh() async {
    _error = null;
    notifyListeners();
    try {
      await _repository.refreshCupPrice();
      await _fetch();
      return true;
    } on Failure catch (error) {
      _error = error;
      notifyListeners();
      return false;
    }
  }

  Future<void> _fetch() async {
    _currencies = await _repository.getSupportedCurrencies();
    _history = await _repository.getCupPriceHistory();
    _current = _history.isEmpty ? null : _history.last;
    _lastWeek = _pointAt(todayMinusDays(7));
    _recomputeDelta();
  }

  CupPricePoint? _pointAt(DateTime exactDay) {
    for (final point in _history) {
      if (point.date == exactDay) return point;
    }
    return null;
  }

  void _recomputeDelta() {
    final current = _current;
    final lastWeek = _lastWeek;
    if (current == null ||
        lastWeek == null ||
        lastWeek.cupPerUsd == 0) {
      _deltaCup = null;
      _deltaPercent = null;
      return;
    }
    final delta = current.cupPerUsd - lastWeek.cupPerUsd;
    _deltaCup = delta;
    _deltaPercent = (delta / lastWeek.cupPerUsd) * 100;
  }

  Currency? _pick(String code) {
    for (final currency in _currencies) {
      if (currency.code == code) return currency;
    }
    return null;
  }
}
```

En `lib/core/utils` agregar el helper compartido (usado por provider y tests), o definirlo en el
provider. Para DRY, agregar a `lib/core/utils/currency_formatter.dart`:

```dart
  /// Local-midnight date shifted by [days] (negative = past).
  static DateTime dayShift(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day).add(Duration(days: days));
```

y usar en el provider `_pointAt(CurrencyFormatter.dayShift(DateTime.now(), -7))` (import del utils).

- [ ] **Step 2: Escribir los widgets**

`price_display_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/domain/entities/currency.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Big "720.00 CUP = 1.00 USD" card shown on the CUP home screen.
class PriceDisplayCard extends StatelessWidget {
  const PriceDisplayCard({
    super.key,
    required this.label,
    required this.cupPerUsd,
    required this.cup,
    required this.usd,
  });

  final String label;
  final double cupPerUsd;
  final Currency cup;
  final Currency usd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Text(
              '${CurrencyFormatter.amount(cupPerUsd, cup)} = '
              '${CurrencyFormatter.amount(1, usd)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`week_delta_chip.dart`:

```dart
import 'package:flutter/material.dart';

/// Colored chip showing how the CUP price moved in the last 7 days. Positive
/// delta (dollar got more expensive) = red (the peso lost value); negative =
/// green. Always carries text, never color alone.
class WeekDeltaChip extends StatelessWidget {
  const WeekDeltaChip({
    super.key,
    required this.deltaCup,
    required this.deltaPercent,
  });

  final double? deltaCup;
  final double? deltaPercent;

  @override
  Widget build(BuildContext context) {
    final delta = deltaCup;
    final percent = deltaPercent;
    if (delta == null || percent == null) return const SizedBox.shrink();

    final rising = delta > 0;
    final color = rising
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF2E7D32);
    final arrow = rising ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(arrow, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${rising ? '▲' : '▼'} '
            '${delta.abs().toStringAsFixed(2)} CUP · '
            '${percent.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

`history_chart.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/entities/cup_price_point.dart';

/// Line chart of the CUP price over time (X = day index, Y = CUP per USD).
class HistoryChart extends StatelessWidget {
  const HistoryChart({super.key, required this.points});

  final List<CupPricePoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].cupPerUsd),
    ];
    final minY = points.map((p) => p.cupPerUsd).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.cupPerUsd).reduce((a, b) => a > b ? a : b);

    return AspectRatio(
      aspectRatio: 1.6,
      child: LineChart(
        LineChartData(
          minY: minY * 0.97,
          maxY: maxY * 1.03,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: scheme.primary,
              isCurved: true,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: _leftTitle,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: points.length / 5,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final date = points[i].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _leftTitle(double value, TitleMeta meta) =>
    Text('${value.toStringAsFixed(0)}', textAlign: TextAlign.right);
```

- [ ] **Step 3: Escribir el test del provider**

Create: `test/features/cup_price/presentation/cup_price_provider_test.dart`

```dart
import 'package:divisas_cup/core/constants/fake_rates.dart';
import 'package:divisas_cup/features/cup_price/presentation/providers/cup_price_provider.dart';
import 'package:divisas_cup/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('CupPriceProvider', () {
    test('loads current, last week and computes the delta', () async {
      final provider =
          CupPriceProvider(repository: FakeExchangeRateRepository());
      await provider.load();

      final today = DateTime.now();
      final series = FakeRates.series(relativeTo: today);
      final lastWeekPoint = series.firstWhere(
        (p) => p.date == CurrencyFormatter.dayShift(today, -7),
      );

      expect(provider.isLoading, isFalse);
      expect(provider.current!.cupPerUsd, closeTo(720, 1e-6));
      expect(provider.lastWeek!.cupPerUsd, lastWeekPoint.cupPerUsd);
      expect(
        provider.deltaCup!,
        closeTo(provider.current!.cupPerUsd - lastWeekPoint.cupPerUsd, 1e-6),
      );
      expect(
        provider.deltaPercent!,
        closeTo(
          (provider.current!.cupPerUsd - lastWeekPoint.cupPerUsd) /
              lastWeekPoint.cupPerUsd *
              100,
          1e-6,
        ),
      );
      expect(provider.history, hasLength(FakeRates.seriesDays));
      expect(provider.cupCurrency?.code, 'CUP');
      expect(provider.usdCurrency?.code, 'USD');
    });

    test('refresh reports success and reloads', () async {
      final provider =
          CupPriceProvider(repository: FakeExchangeRateRepository());
      await provider.load();

      final ok = await provider.refresh();
      expect(ok, isTrue);
      expect(provider.error, isNull);
    });

    test('surfaces failures and keeps the loading flag false', () async {
      final provider = CupPriceProvider(
        repository: FakeExchangeRateRepository(failOnSeries: true),
      );
      await provider.load();

      expect(provider.error, isNotNull);
      expect(provider.isLoading, isFalse);
    });
  });
}
```

- [ ] **Step 4: Correr el test** `flutter test test/features/cup_price/presentation/cup_price_provider_test.dart`
Expected: 3 tests PASS.

---

## Task 11: Páginas del feature `cup_price`

**Files:**
- Create: `lib/features/cup_price/presentation/pages/cup_price_page.dart`
- Create: `lib/features/cup_price/presentation/pages/cup_price_history_page.dart`

- [ ] **Step 1: Escribir la home**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/cup_price_provider.dart';
import '../widgets/price_display_card.dart';
import '../widgets/week_delta_chip.dart';

/// CUP home screen: current dollar price in CUP against last week, plus a
/// shortcut to the full history.
class CupPricePage extends StatelessWidget {
  const CupPricePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CupPriceProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cupPriceTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final ok = await provider.refresh();
              if (!context.mounted) return;
              ok
                  ? AppSnackBar.showSuccess(context, l10n.refreshSuccess)
                  : AppSnackBar.showError(context, l10n.loadError);
            },
          ),
        ],
      ),
      body: _buildBody(context, provider, l10n),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CupPriceProvider provider,
    AppLocalizations l10n,
  ) {
    final current = provider.current;
    final cup = provider.cupCurrency;
    final usd = provider.usdCurrency;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (current == null || cup == null || usd == null) {
      return _MessageView(
        message: provider.error?.message ?? l10n.loadError,
        onRetry: () => unawaited(provider.load()),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PriceDisplayCard(
          label: l10n.currentPrice,
          cupPerUsd: current.cupPerUsd,
          cup: cup,
          usd: usd,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.lastWeek, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                if (provider.lastWeek != null)
                  Text(
                    '${provider.lastWeek!.cupPerUsd.toStringAsFixed(2)} CUP',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                const SizedBox(height: 12),
                Center(
                  child: WeekDeltaChip(
                    deltaCup: provider.deltaCup,
                    deltaPercent: provider.deltaPercent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () => context.push(AppRoutes.history),
          icon: const Icon(Icons.show_chart),
          label: Text(l10n.viewHistory),
        ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Escribir la página de historial**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../providers/cup_price_provider.dart';
import '../widgets/history_chart.dart';

/// CUP price history screen: line chart pushed over the home screen.
class CupPriceHistoryPage extends StatelessWidget {
  const CupPriceHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CupPriceProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: provider.history.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                HistoryChart(points: provider.history),
                const SizedBox(height: 12),
                Text(
                  l10n.footerHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 3: Compilar** `flutter analyze` → sin issues.

---

## Task 12: Wiring — router, shell, app

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/core/widgets/home_shell.dart`
- Modify: `lib/app.dart`

- [ ] **Step 1: Router**

`lib/core/router/app_router.dart` reemplazo completo:

```dart
import 'package:go_router/go_router.dart';

import '../../features/currency_calculator/presentation/pages/currency_calculator_page.dart';
import '../../features/cup_price/presentation/pages/cup_price_history_page.dart';
import '../../features/cup_price/presentation/pages/cup_price_page.dart';
import '../../features/price_comparison/presentation/pages/price_comparison_page.dart';
import '../widgets/home_shell.dart';

/// Central route table. The CUP price screen is the boot destination; both
/// other features share one shell that renders the Material 3 [NavigationBar]
/// (see [HomeShell]). The history is pushed over the shell (no bottom bar).
abstract final class AppRoutes {
  static const String home = '/cup-price';
  static const String history = '/cup-price/history';
  static const String comparator = '/comparator';
  static const String calculator = '/calculator';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const CupPricePage(),
        ),
        GoRoute(
          path: AppRoutes.comparator,
          builder: (context, state) => const PriceComparisonPage(),
        ),
        GoRoute(
          path: AppRoutes.calculator,
          builder: (context, state) => const CurrencyCalculatorPage(),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (context, state) => const CupPriceHistoryPage(),
    ),
  ],
);
```

- [ ] **Step 2: Shell a 3 destinos**

`lib/core/widgets/home_shell.dart` — adaptar imports y el `build`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../router/app_router.dart';

const _routes = [AppRoutes.home, AppRoutes.comparator, AppRoutes.calculator];

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = GoRouterState.of(context).uri.path;
    final index = _routes.indexWhere((r) => path == r);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(_routes[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments),
            label: l10n.priceLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.compare_arrows_outlined),
            selectedIcon: const Icon(Icons.compare_arrows),
            label: l10n.homeLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            label: l10n.calculatorLabel,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: App — wire del provider**

En `lib/app.dart`, importar el `CupPriceProvider` y agregarlo al `MultiProvider`:

```dart
import 'features/cup_price/presentation/providers/cup_price_provider.dart';
```

```dart
        ChangeNotifierProvider(
          create: (_) =>
              CupPriceProvider(repository: exchangeRateRepository)..load(),
        ),
```

(después del provider de calculadora).

- [ ] **Step 4: Compilar** `flutter analyze` → sin issues.

---

## Task 13: Tests de widget — boot nuevo + seed nuevo

**Files:**
- Modify: `test/features/price_comparison/presentation/price_comparison_page_test.dart`
- Modify: `test/features/currency_calculator/presentation/currency_calculator_page_test.dart`
- Create: `test/features/cup_price/presentation/cup_price_page_test.dart`

- [ ] **Step 1: Comparador — navegar desde la home y seed CUP**

`price_comparison_page_test.dart` reemplazo completo:

```dart
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

> **Nota plan (corregida en ejecución, Task 13):** `rate(CUP→MLC)` es `1/720` (MLC `priceInCup`
> = 720, igual que USD), NO `1` como figuraba en esta línea; con 2 decimales de
> `CurrencyFormatter` la fila renderiza `1.00 CUP = 0.00 MLC`.

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
```

- [ ] **Step 2: Calculadora — navegar y seed USD→CUP**

`currency_calculator_page_test.dart` reemplazo completo:

```dart
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
```

- [ ] **Step 3: Widget test de la home + historial**

Create: `test/features/cup_price/presentation/cup_price_page_test.dart`

```dart
import 'package:divisas_cup/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {FakeExchangeRateRepository? repo}) async {
    await tester.pumpWidget(
      DivisasCupApp(exchangeRateRepository: repo ?? FakeExchangeRateRepository()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('boots on the CUP price home showing today and last week',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('CUP Price'), findsOneWidget);
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
  });

  testWidgets('refresh shows a success snack bar', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('Rates updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
```

Nota: `LineChart` viene de `package:fl_chart/fl_chart.dart`; importarlo en el test.

- [ ] **Step 4: Correr la suite completa**

Run: `flutter test`
Expected: suite completa PASS (aprox. 45+ tests).

---

## Task 14: Documentación (AGENTS.md, README.md)

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`

- [ ] **Step 1: Actualizar AGENTS.md** — puntos a tocar:

1. `lib/core/constants/fake_rates.dart` es el seed **CUP-anchored** (campo `priceInCup` =
   cuántos CUP compran 1 X); `ExchangeRateRepositoryImpl` deriva
   `rate(A→B) = priceInCup(A)/priceInCup(B)`. Agregar una moneda = un tuple en el seed.
2. El set de monedas es `CUP / USD / MLC / EUR` (dejaron de existir MXN/CAD/BRL). Seed de ejemplo:
   CUP 1 / USD 720 / MLC 720 / EUR 777.6. Tests que codifiquen el seed actualizan la matemática.
3. La app **bootea en `/cup-price`** (no `/comparator`); widget tests de comparador/calculadora
   navegan por la barra (Compare/Calculator) tras `pumpAndSettle`. La barra tiene 3 destinos.
4. `ExchangeRateRepository`/`ExchangeRateDataSource` ahora tienen además `getCurrentCupPrice`,
   `getCupPriceHistory`, `refreshCupPrice`. La serie vive en la tabla `cup_price_series`
   (schema v2). `refreshCupPrice` appendea el punto de hoy (jitter determinístico por día) y
   re-ancla las filas CUP→USD/MLC/EUR.
5. `fl_chart` es dependencia (gráfico del historial).
6. El data stack sigue solo bajo `features/price_comparison/data/`; `cup_price` es
   presentation-only.
7. Patrón snackbar: los widget tests que disparan snackbar terminan con `tester.pump(6s)` (se
   mantiene).

- [ ] **Step 2: Actualizar README.md** — secciones a tocar:

1. Diagrama de `lib/` (agregar `features/cup_price/`, entidad `cup_price_point.dart`, modelo
   `cup_price_point_model.dart`).
2. "Architectural decisions": ancla **CUP** en lugar de USD; `rate(A→B) = priceInCup(A)/priceInCup(B)`;
   serie temporal de muestra determinística (~90 días) + refresh local que appendea.
3. "Getting started": boot en `/cup-price`; set de monedas de ejemplo CUP/USD/MLC/EUR.

- [ ] **Step 3: Correr análisis** `flutter analyze` → sin issues.

---

## Task 15: Gate de verificación final

- [ ] **Step 1: Suite completa + análisis**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: 0 issues, suite completa PASS.

- [ ] **Step 2: Build Android debug (verifica sqflite plugin + fl_chart)**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL.

---

## Self-Review del plan

**Spec coverage:** ancla CUP (T3, T5, T6) · set CUP/USD/MLC/EUR (T3) · métrica "X CUP = 1 USD"
(T10-T11, T13) · home con actual + semana pasada + delta (T10-T11) · historial con fl_chart (T10-T11)
· refresh local (T5, T10) · navegación home/historial/barra 3 destinos (T12) · defaults
comparador/calculadora (T8) · i18n (T9) · testing completo (T0-T13) · docs de los archivos de la
regla (T14) · build/deps (T1, T15).

**Placeholders:** ninguno — todo paso tiene código o comando con resultado esperado.

**Consistencia de tipos:** `getPriceInCup` renombrado de `getUnitsPerUsd` en contrato/mock/local/impl/
tests (T4-T7); `CupPricePoint` en dominio; `CupPricePointModel.fromPoint/fromMap/toMap` en data
(T4-T5); contratos de repositorio y datasource con los mismos 3 métodos de serie (T4, T6).