# DivisasCUP — Giro CUP-céntrico

> Fecha: 2026-09-23 · Estado: aprobado por el usuario · Tipo: refactor + 2 features

## Contexto

DivisasCUP es una app Flutter local-first de comparación/conversión de divisas
pensada para cubanos. Hoy el ancla interna de tasas es el **USD** (`FakeRates`
guarda `unitsPerUsd`) y el público objetivo pide que la app gire en torno al
**CUP**, con dos features nuevas: una pantalla principal que muestra el precio
del CUP (actual vs. hace una semana) y un historial de su evolución.

Decisiones acordadas con el usuario (D1–D5):

| # | Decisión | Elección |
|---|---|---|
| D1 | Métrica protagonista | `X CUP = 1 USD` (el CUP primero) |
| D2 | Origen del precio e histórico | Seed con serie temporal + refresh local que appendea |
| D3 | Navegación | Precio CUP = home de arranque; historial empujado |
| D4 | Alcance del giro | Pivot total + set reformulado |
| D5 | Visualización del historial | Gráfico de línea con `fl_chart` |

## 1. Objetivos

1. Que la app **gire en torno al CUP**: ancla interna CUP, mayoría de screens
   con CUP como base por defecto.
2. Nueva **home**: precio actual del dólar en CUP + precio de hace una semana
   con delta (en CUP y %).
3. **Historial**: gráfico de línea con la evolución del precio del CUP,
   empujado desde la home.
4. Mantener la filosofía local-first y las reglas de arquitectura existentes
   (dominio compartido en `core/domain`, data stack solo en
   `price_comparison/data`, seed único, repository pattern, i18n completa).

## 2. Alcance

### Incluido

- Re-ancla del seed de USD a CUP con set de monedas CUP/USD/MLC/EUR.
- Nueva entidad de dominio `CupPricePoint` y nuevos métodos en el contrato de
  `ExchangeRateRepository`.
- Nueva tabla SQLite `cup_price_series` + migración de esquema v1 → v2.
- Nuevo feature `cup_price` (solo presentación: provider, home, historial,
  widgets) con fl_chart.
- Cambios de defaults en Comparador (base CUP) y Calculadora (USD→CUP).
- Router y shell a 3 destinos; arranque en `/cup-price`.
- i18n nueva (ambos ARB) y regeneración.
- Tests: actualización del seed/matemática, fakes, nuevos tests unit/widget.
- Documentos: `AGENTS.md` y `README.md` actualizados.

### Excluido (fuera de alcance)

- Integración real de datos (API / Supabase). Sigue siendo la costura
  `RemoteExchangeRateDataSource`, no implementada.
- Entrada manual de precios (se descartó en D2 por ahora).
- Soporte web/desktop (ya fuera de alcance por `sqflite`).

## 3. Modelo de datos

### 3.1 Re-ancla del seed (`lib/core/constants/fake_rates.dart`)

Hoy: `seed` = lista de tuplas `(code, name, symbol, decimalDigits, unitsPerUsd)`
y el repo deriva `rate(A→B) = unitsPerUsd(B) / unitsPerUsd(A)`.

Nuevo: el campo pasa a **`priceInCup`** (cuántos CUP compran 1 unidad de X —
valor que un cubano entiende y edita a mano). La derivación se invierte:
`rate(A→B) = priceInCup(A) / priceInCup(B)`.

Valores de muestra acordados:

| Currency | code | symbol | decimals | priceInCup |
|---|---|---|---|---|
| Cuban Peso | CUP | `$` | 2 | 1.0 |
| US Dollar | USD | `$` | 2 | 720.0 |
| MLC | MLC | `$` | 2 | 720.0 (paridad de muestra con USD) |
| Euro | EUR | `€` | 2 | 777.6 (= 720 × 1.08, factor estático) |

Se retiran MXN, CAD y BRL. Propiedades derivadas del seed (`unitsPerUsd`,
`priceInCup`, etc.) se renombran/adaptan; los tests que codifican la
matemática del seed se actualizan.

### 3.2 Nueva entidad `CupPricePoint` (`lib/core/domain/entities/cup_price_point.dart`)

```dart
class CupPricePoint {
  final DateTime date;       // fecha del punto
  final double cupPerUsd;    // cuántos CUP compran 1 USD ese día
}
```

Value object inmutable; igualdad por `date` + `cupPerUsd` (consistente con el
patrón de `Currency`/`ExchangeRate`).

### 3.3 Serie temporal de muestra

Generada **determinísticamente** (sin azar no reproducible) en el seed:

- ~90 puntos diarios, ascendentes, terminando en el valor actual de USD (720).
- El punto "hace una semana" cae en el día exacto `hoy − 7d` (la serie es
  diaria, no semanal — decisión vetable).
- Implementación recomendada: un generador que parte de un valor inicial
  (≈ 480 hace ~90 días) y aplica deltas diarios fijos de una lista corta
  (periodicidad), aterrizando justo en 720. El generador resultante alimenta
  tanto al mock como al seed inicial de SQLite.

MLC replica la serie del USD (paridad 1:1 de muestra). EUR se deriva
`cupPerUsd × 1.08` en cada punto.

### 3.4 SQLite (`lib/features/price_comparison/data/datasources/local_exchange_rate_data_source.dart`)

Versión de esquema: `_dbVersion` 1 → **2**.

`onCreate` (instalaciones nuevas) crea las 2 tablas existentes + la nueva y
siembra todo. `onUpgrade` de 1 → 2 crea `cup_price_series` y la siembra (para
instalaciones dev existentes; no hay release).

```sql
CREATE TABLE cup_price_series (
  sampled_at INTEGER PRIMARY KEY,   -- epoch millis (UTC)
  cup_per_usd REAL NOT NULL
);
```

Las filas ancladas de `exchange_rates` cambian de base `USD` a base **CUP**
(se inserta una fila por moneda: CUP=1.0, USD, MLC, EUR).

### 3.5 Refresh

`refreshCupPrice()` en data source + repo:

- Calcula el nuevo valor = `clamp(actual ± jitter, min/max)`, con jitter
  determinista (±0.5–2%) para que los tests sigan siendo estables.
- Inserta el punto con fecha `hoy` (si ya existe hoy, lo actualiza en vez de
  duplicar).
- Actualiza las filas ancladas CUP→{USD, MLC, EUR} en `exchange_rates`
  (MLC = nuevo valor; EUR = nuevo × 1.08) para que Comparador y Calculadora
  queden coherentes tras refrescar.
- Devuelve el `CupPricePoint` nuevo para que la UI muestre el snackbar.

## 4. Dominio y contrato (`lib/core/domain/`)

`ExchangeRateRepository` (contrato compartido) suma:

```dart
Future<CupPricePoint> getCurrentCupPrice();        // último punto de la serie
Future<List<CupPricePoint>> getCupPriceHistory();  // serie completa ascendente
Future<CupPricePoint> refreshCupPrice();           // appendea/actualiza hoy y devuelve
```

Los 3 métodos existentes (`getSupportedCurrencies`, `getRate`, `getRatesForBase`)
se mantienen sin cambios de firma (su implementación interna pasa a derivar del
ancla CUP). `ExchangeRateDataSource` suma los mismos 3 métodos de serie; el
resto del data stack (models, repos) vive bajo `features/price_comparison/data/`
respetando la regla de arquitectura.

## 5. Nuevo feature `lib/features/cup_price/` (presentation-only)

```
cup_price/
└── presentation/
    ├── providers/cup_price_provider.dart
    ├── pages/cup_price_page.dart
    ├── pages/cup_price_history_page.dart
    └── widgets/
        ├── price_display_card.dart
        ├── week_delta_chip.dart
        └── history_chart.dart
```

### `CupPriceProvider` (ChangeNotifier)

- Estado: `current` (CupPricePoint), `lastWeek` (CupPricePoint), `deltaCup`,
  `deltaPercent`, `history`, `isLoading`, `error`.
  - `deltaCup = current.cupPerUsd − lastWeek.cupPerUsd`
  - `deltaPercent = deltaCup / lastWeek.cupPerUsd × 100`
- `load()`: pide current + lastWeek + history.
- `refresh()`: `refreshCupPrice()`, luego re-carga; devuelve `true/false` para
  que la página decida el snackbar (mismo patrón que `PriceComparisonProvider.refresh`).
- Métodos de cómputo para que la página no haga lógica.

### `CupPricePage` (home, ruta `/cup-price`)

- Card principal: **"720.00 CUP = $1.00 USD"** (formato vía `CurrencyFormatter`;
  se usa `rate(USD→CUP)` = `priceInCup(USD)` = 720, renderizada con el CUP
  primero).
- Card secundaria: **"Semana pasada: 700.00 CUP"** con `WeekDeltaChip`
  (▲ +20 CUP · +2,9% ó ▼ −15 CUP · −2,1%, con color y texto, no solo color).
- Botón/ícono **"Ver histórico"** → `context.push('/cup-price/history')`.
- `IconButton` refresh reusando `AppSnackBar` (éxito/error).
- Estados de loading/error igual patrón que las páginas existentes
  (`CircularProgressIndicator`, mensaje + retry).

### `CupPriceHistoryPage` (ruta `/cup-price/history`)

- Fuera del ShellRoute: Scaffold con AppBar y back.
- `LineChart` de **fl_chart**: X = fecha de cada punto, Y = `cupPerUsd`,
  tooltips, footer "Ver histórico" / pista de que los datos son de ejemplo
  (mismo tono que `footerHint` actual).
- `HistoryChart` extraído como widget reutilizable para tests.

### Colores del delta (decisión vetable)

- Subió el precio del dólar (más CUP por USD) → **rojo** (el CUP pierde valor).
- Bajó → **verde**.
- Siempre acompañado de texto, nunca solo color.

## 6. Cambios en features existentes

### `price_comparison`

- `PriceComparisonProvider.load()`: base por defecto pasa a buscar `CUP` en la
  lista (fallback: primer elemento). Comparador muestra
  `1 CUP = X USD` / `1 CUP = X MLC` / `1 CUP = X EUR`.
- `ComparisonTile` sin cambios (ya es agnóstico de moneda).

### `currency_calculator`

- `CurrencyCalculatorProvider.load()`: `from = USD`, `to = CUP`
  (`_pick('USD')` / `_pick('CUP')`).

## 7. Navegación y shell

`lib/core/router/app_router.dart`:

- `AppRoutes.home = '/cup-price'` → `CupPricePage` (nuevo `initialLocation`).
- `AppRoutes.history = '/cup-price/history'` → `CupPriceHistoryPage`,
  **fuera** del `ShellRoute` (push con back, sin barra inferior).
- Se mantienen `/comparator` y `/calculator` dentro del `ShellRoute`.

`lib/core/widgets/home_shell.dart`:

- 3 `NavigationDestination`: Precio (índice 0) · Comparar (1) · Calcular (2)
  — mapeo de ruta→índice actualizado.

`lib/app.dart`: se agrega `CupPriceProvider` al `MultiProvider` (con `.load()`).

`pubspec.yaml`: agregar `fl_chart` (última estable compatible con Flutter
3.47/Dart 3.13). El policy de deps aplica: `flutter pub get && flutter analyze
&& flutter test` completo.

## 8. i18n

Nuevas claves en `app_en.arb` (template) y `app_es.arb` (misma key):

- `cupPriceTitle` — "Precio del CUP"
- `lastWeek` — "Semana pasada"
- `viewHistory` — "Ver histórico"
- `historyTitle` — "Histórico"
- `currentPrice` — "Precio actual"
- `weekChange` — "Cambio en 7 días" (o similar)
- Reuso de `refresh`, `refreshSuccess`, `loadError`.

Gate: editar ARB → `flutter gen-l10n` → `flutter analyze` → tests.

## 9. Testing

- **Seed/matemática**: todos los tests que subían la matemática vieja
  (USD 1 / MXN 24 / CUP 700 / CAD 1.35 / BRL 5.2) se re-escriben al nuevo seed
  (CUP 1 / USD 720 / MLC 720 / EUR 777.6). Referencias: `test/helpers/fakes.dart`,
  `exchange_rate_repository_impl_test.dart`, etc.
- **Fakes**: `FakeExchangeRateRepository` implementa `getCurrentCupPrice`,
  `getCupPriceHistory`, `refreshCupPrice` con una serie fija y determinista.
- **Data**: `local_exchange_rate_data_source_test.dart` — serie + refresh
  (inserta/actualiza hoy, jitter acotado) + migración v1→v2 (FFI en memoria).
- **Repo**: derivación CUP (`USD→CUP = 720`, `CUP→USD = 1/720`,
  `USD→EUR ≈ 0.926`, `USD→MLC = 1`).
- **Providers**: `CupPriceProvider` deltas (+, −, sin cambio), refresh;
  defaults CUP en comparador y USD→CUP en calculadora.
- **Widget tests**:
  - Home bootea en `/cup-price` (cambia el supuesto actual de "/comparator").
  - Historial se abre con push y muestra el chart.
  - La calculadora ahora requiere tapear el destino "Calculator" en la barra de
    3 destinos (se mantiene el patrón de `tester.pump(6s)` para snackbars).
- **Gate completo**: `flutter gen-l10n && flutter analyze && flutter test`.

## 10. Documentación

- `AGENTS.md`: actualizar — arranque en `/cup-price`, seed CUP-anchored
  (`priceInCup`), ordering de navegación en widget tests, nuevos métodos del
  contrato, tabla `cup_price_series`, dependencia `fl_chart`.
- `README.md`: sección "Estructura" (nuevo feature cup_price), decisiones
  (ancla CUP), y notas de navegación.

## 11. Fuera de alcance / notas

- `double` para montos/tasas se mantiene (simplificación aceptada).
- `RemoteExchangeRateDataSource` permanece como costura futura sin
  implementación; el refresh de hoy es local/de muestra.
- No hay release previo, por lo que la migración v1→v2 es principalmente para
  entornos dev. Si antes del release se decide otro esquema, puede simplificarse.