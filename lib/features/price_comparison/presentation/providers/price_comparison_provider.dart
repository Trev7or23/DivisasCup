import 'package:flutter/foundation.dart';

import '../../../../core/domain/entities/currency.dart';
import '../../../../core/domain/entities/exchange_rate.dart';
import '../../../../core/domain/repositories/exchange_rate_repository.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/usecases/get_rates_for_base.dart';
import '../../domain/usecases/get_supported_currencies.dart';

/// Holds the state of the Currency Comparator screen: selected base currency
/// and the currently-displayed comparison list.
///
/// Consumed by [PriceComparisonPage] via `context.watch`. Method/field
/// naming keeps the page free of repository/use-case wiring.
class PriceComparisonProvider extends ChangeNotifier {
  PriceComparisonProvider({required ExchangeRateRepository repository})
      : _getCurrencies = GetSupportedCurrencies(repository),
        _getRatesForBase = GetRatesForBase(repository);

  final GetSupportedCurrencies _getCurrencies;
  final GetRatesForBase _getRatesForBase;

  List<Currency> _currencies = const [];
  List<ExchangeRate> _rates = const [];
  Currency? _base;
  bool _isLoading = true;
  Failure? _error;

  List<Currency> get currencies => List.unmodifiable(_currencies);
  List<ExchangeRate> get rates => List.unmodifiable(_rates);
  Currency? get base => _base;
  bool get isLoading => _isLoading;
  Failure? get error => _error;

  /// First load: currencies, default base (CUP) and its comparison.
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

  /// Re-reads rates for the current base. Returns `true` on success so the
  /// caller can show the matching snack bar.
  Future<bool> refresh() async {
    _error = null;
    notifyListeners();
    try {
      await _loadRates();
      return true;
    } on Failure catch (error) {
      _error = error;
      notifyListeners();
      return false;
    }
  }

  /// Changes the base currency and reloads the comparison list.
  Future<void> selectBase(Currency currency) async {
    _base = currency;
    _error = null;
    notifyListeners();
    try {
      await _loadRates();
    } on Failure catch (error) {
      _error = error;
      notifyListeners();
    }
  }

  Future<void> _loadRates() async {
    final base = _base;
    if (base == null) return;
    _rates = await _getRatesForBase(base);
    notifyListeners();
  }
}