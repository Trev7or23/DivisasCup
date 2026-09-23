# DivisasCUP

Local-first **CUP price** app (Flutter, Android/iOS): current price vs last
week, a 90-day price-history chart, currency **comparison**, and
**conversion** — all offline from the first run. A Supabase backend is
designed-for but **not** implemented yet.

## Stack

| Concern       | Choice                                          |
|---------------|-------------------------------------------------|
| Framework     | Flutter (stable)                                |
| State         | Provider + `ChangeNotifier`                     |
| Local DB      | SQLite via `sqflite` (seeded on first launch)   |
| Architecture  | Clean Architecture, feature-first               |
| Navigation    | `go_router` (shell with Material 3 nav bar)     |
| i18n          | `flutter_localizations` + `intl` (`es`, `en`)   |
| Theme         | Material 3 (`ColorScheme.fromSeed`)             |
| Linter        | `flutter_lints`                                 |
| Tests         | Unit (`test/…`) + widget (`test/…`)             |
| Future cloud  | Supabase — abstraction only                     |

## Structure

```
lib/
├── main.dart                 # bootstrap: build repo, runApp
├── app.dart                  # providers + MaterialApp.router
├── core/
│   ├── constants/fake_rates.dart          # single seed of fake rates (CUP-anchored)
│   ├── domain/                            # SHARED domain types
│   │   ├── entities/{currency,exchange_rate,cup_price_point}.dart
│   │   └── repositories/exchange_rate_repository.dart
│   ├── errors/failure.dart                # sealed Failure hierarchy
│   ├── router/app_router.dart             # go_router routes
│   ├── theme/app_theme.dart               # M3 light/dark from one seed color
│   ├── utils/currency_formatter.dart      # intl formatting for amounts/rates
│   └── widgets/{app_snack_bar,currency_dropdown_button,home_shell}.dart
├── features/
│   ├── cup_price/                         # CUP price home screen (presentation-only)
│   │   └── presentation/{providers,pages,widgets}/   # incl. history chart (fl_chart)
│   ├── price_comparison/                  # owns the exchange-rate data stack
│   │   ├── data/datasources/              # ExchangeRateDataSource + Mock + Local + Remote(placeholder)
│   │   ├── data/models/                   # CurrencyModel, ExchangeRateModel, CupPricePointModel
│   │   ├── data/repositories/             # ExchangeRateRepositoryImpl
│   │   ├── domain/usecases/               # GetSupportedCurrencies, GetRatesForBase
│   │   └── presentation/{providers,pages,widgets}/
│   └── currency_calculator/               # thin consumer of the same data stack
│       ├── domain/usecases/               # ConvertCurrency
│       └── presentation/{providers,pages,widgets}/
└── l10n/                      # app_en.arb, app_es.arb (+ generated/)
```

## Architectural decisions

- **Shared domain in `core/domain`.** `Currency`, `ExchangeRate`,
  `CupPricePoint` and `ExchangeRateRepository` are used by *every* feature.
  Placing them once in `core/domain` avoids cross-feature imports and
  duplication; each feature keeps its own `domain/usecases` and (where it
  exists) `data/` below it. The data stack lives under `price_comparison`
  (the feature that "owns" rates); the calculator is a thin UI over the same
  repository, and `cup_price` is presentation-only.
- **Repository pattern.** Domain defines the contract; `data/` provides the
  implementation. UI/usecases never touch SQLite or (later) Supabase.
- **CUP-anchored data + derived cross-rates.** A single seed holds each
  currency's `priceInCup` (how many CUP one unit buys);
  `rate(A→B) = priceInCup(A) / priceInCup(B)` (see
  `ExchangeRateRepositoryImpl`). No hand-written pairs → the data can
  never be self-contradictory, and adding a currency is one line in
  `FakeRates.seed`.
- **Deterministic ~90-day CUP price series + local refresh.**
  `FakeRates.series()` seeds a 90-point daily history into the
  `cup_price_series` table (schema v2; the upgrade migration purges and
  re-seeds `currencies`/`exchange_rates`). `refreshCupPrice()` appends
  today's point with deterministic jitter and re-anchors the CUP→USD/MLC/EUR
  rows; `fl_chart` renders the history.
- **`ExchangeRateDataSource` as the single Supabase seam.** Mock and Local
  implement it; `RemoteExchangeRateDataSource` is an intentionally unimplemented
  interface (with a commented wiring sketch). When Supabase arrives, only
  `main.dart` wiring changes — domain and presentation are untouched.
- **SQLite seeds itself on first launch** (`onCreate` in
  `LocalExchangeRateDataSource`), so the app works offline from run one; the
  mock source is only a seed fallback/dev/test double, never the runtime path.
- **Provider, not Riverpod/Bloc.** Matches your chosen stack; one
  `ChangeNotifier` per screen, constructed in `app.dart` from the repository.
- **go_router `ShellRoute`** renders a single Material 3 `NavigationBar`
  (`HomeShell`) for the three top-level screens (Price / Compare /
  Calculator); `/cup-price/history` is pushed over the shell without the
  bottom bar, and routes are centralized in `AppRoutes`.
- **i18n.** `l10n.yaml` + ARB files; `es` first in `supportedLocales` so any
  non-ES/EN device falls back to Spanish.
- **Snack bars** go through the reusable `AppSnackBar`
  (`showSuccess/Error/Info`) — one feedback mechanism, no ad-hoc styling.
- **Known simplification:** rates/amounts use `double` (Dart has no built-in
  decimal). Display precision is handled by `CurrencyFormatter`. This is
  acceptable for a comparison app; revisit with `decimal`/BigDecimal if
  money-exact arithmetic becomes a requirement.
- **Scope note:** `web/`, `linux/`, `windows/`, `macos/` folders exist but are
  out of scope — `sqflite` is a mobile-plugin dependency.

## Getting started

```bash
flutter pub get
flutter gen-l10n
flutter run          # boots on /cup-price; uses SQLite (seeded on first launch)
flutter test         # 45 unit + widget tests (in-memory FFI DB for SQLite tests)
flutter analyze
```

Sample currencies (`FakeRates.seed`, CUP-anchored `priceInCup`): CUP 1.0 ·
USD 720.0 · MLC 720.0 · EUR 777.6.