# AGENTS.md

DivisasCUP — Flutter (Android/iOS) app: local-first CUP price tracking, currency comparison & conversion.
Clean Architecture, feature-first, fully offline (SQLite); Supabase is a future seam only.
Dev box: Flutter stable ~3.47.2, Dart ~3.13.

## Commands & verification gate

Gate order when touching loc/UI: edit `.arb` → `flutter gen-l10n` → `flutter analyze` → tests for the touched feature.

- `flutter pub get` — deps. `intl` is pinned (^0.20.3) to match `flutter_localizations`; never bump `intl` on its own.
- `flutter gen-l10n` — regenerates `lib/l10n/generated/` after ARB edits. Also runs during builds (`generate: true`).
- `flutter analyze` — repo-wide; fast. Run before finishing any work.
- `flutter test` — full suite (~20s). Focused: `flutter test test/features/<feature>/...` or `flutter test <file> --plain-name "<name>"`.
- `flutter build apk --debug` — the only local check that sqflite's Android plugin integration works.

Dependency policy: minimal bumps only; after bumping anything, `flutter pub get && flutter analyze && flutter test` (full suite).

## Localization

- Every user-facing string must be added to **both** `lib/l10n/app_en.arb` (template) and `app_es.arb` — same key. Placeholders need `@key` metadata in `app_en.arb`.
- `es` is first in `supportedLocales` (`lib/app.dart`) → any other device locale falls back to Spanish. Widget tests resolve to `en`.
- Generated files under `lib/l10n/generated/` are **gitignored** — never hand-edit; regenerate instead.
- Access via `AppLocalizations.of(context)`, never hard-coded literals in widgets.
- The `cup_price` feature added six keys: `priceLabel`, `cupPriceTitle`, `historyTitle`, `currentPrice`, `lastWeek`, `viewHistory`.

## Architecture

- Shared domain (`Currency`, `ExchangeRate`, `CupPricePoint`, `ExchangeRateRepository`) lives in `lib/core/domain/`; all features import it. Put cross-feature types there, not inside a feature.
- The data stack exists only under `features/price_comparison/data/` (`datasources/`, `models/`, `repositories/`). `currency_calculator` is a thin consumer and `cup_price` is presentation-only — neither has a data layer; don't duplicate data code per feature.
- Rates are **CUP-anchored**: `lib/core/constants/fake_rates.dart` (`FakeRates.seed`) is the single source of truth — each tuple's `priceInCup` is how many CUP one unit of that currency buys (CUP 1 / USD 720 / MLC 720 / EUR 777.6; MXN/CAD/BRL no longer exist). `ExchangeRateRepositoryImpl` derives every pair via `rate(A→B) = priceInCup(A)/priceInCup(B)`. Never write hand-authored pairs; adding a currency = one tuple in the seed (+ test math).
- The CUP price history is a `CupPricePoint` series: `FakeRates.series()` is a deterministic 90-point daily CUP-price series (`FakeRates.seriesDays`), seeded into the `cup_price_series` SQLite table (schema v2 — the upgrade migration purges `currencies`/`exchange_rates` and re-seeds them). `ExchangeRateRepository`/`ExchangeRateDataSource` add `getCurrentCupPrice`, `getCupPriceHistory`, `refreshCupPrice`; `refreshCupPrice()` upserts today's point (deterministic per-day jitter) and re-anchors the CUP→USD/MLC/EUR rows.
- `fl_chart` is a direct dependency — it renders the price-history chart under `features/cup_price`.
- `RemoteExchangeRateDataSource` (`.../datasources/remote_exchange_rate_data_source.dart`) is an intentionally unimplemented Supabase seam — don't wire it, and don't let domain/presentation reference it.
- Money is `double` (accepted simplification); user formatting goes through `CurrencyFormatter` (`lib/core/utils`).
- One `ChangeNotifier` provider per screen, created from the repository in `lib/app.dart`; pages read via `context.watch`. Don't invent alternate provider wiring for test pumps.

## Testing

- SQLite tests use `sqflite_common_ffi`: `sqfliteFfiInit()` in `setUpAll`, then `LocalExchangeRateDataSource(seedSource: …, factoryOverride: databaseFactoryFfi, databasePath: inMemoryDatabasePath)`. Never hit the real `getDatabasesPath()` on the host. Reference: `test/features/price_comparison/data/datasources/local_exchange_rate_data_source_test.dart`.
- Widget tests inject `FakeExchangeRateRepository` from `test/helpers/fakes.dart` into `DivisasCupApp` — never touch SQLite there.
- The app boots on `/cup-price` (go_router `ShellRoute`); history is pushed at `/cup-price/history` (over the shell, no bottom bar). Comparator/calculator widget tests must tap the "Compare"/"Calculator" nav destination first — the bar has 3 destinations (Price / Compare / Calculator).
- Widget tests that trigger a snackbar end with `await tester.pump(const Duration(seconds: 6))` to drain the auto-hide timer — keep that pattern.
- Amount/rate assertions encode the seed (CUP 1 / USD 720 / MLC 720 / EUR 777.6); changing the seed breaks test math.

## Gotchas

- `DropdownButtonFormField.value` is deprecated on this Flutter — use `initialValue` (it re-syncs via `didUpdateWidget`).
- `synthetic-package` in `l10n.yaml` is a no-op/warns on pub get — don't re-add.
- `web/`, `linux/`, `macos/`, `windows/` are out of scope: `sqflite` is mobile-plugin only, those targets won't build.
- Repo is not a git repository yet (no commits, no CI).