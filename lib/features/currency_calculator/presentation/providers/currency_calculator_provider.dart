import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/domain/entities/currency.dart';
import '../../../../core/domain/entities/exchange_rate.dart';
import '../../../../core/domain/repositories/exchange_rate_repository.dart';
import '../../../../core/errors/failure.dart';
import '../../../../features/price_comparison/domain/usecases/get_supported_currencies.dart';
import '../../domain/usecases/convert_currency.dart';

/// State for the 1-to-1 Currency Calculator: amount, from/to currencies and
/// the resulting rate. The "inverse" requirement is covered by [swap], which
/// flips from/to (and therefore uses the inverse rate on the next recalc).
class CurrencyCalculatorProvider extends ChangeNotifier {
  CurrencyCalculatorProvider({required ExchangeRateRepository repository})
    : _getCurrencies = GetSupportedCurrencies(repository),
      _convert = ConvertCurrency(repository);

  final GetSupportedCurrencies _getCurrencies;
  final ConvertCurrency _convert;

  List<Currency> _currencies = const [];
  Currency? _from;
  Currency? _to;
  double _amount = 10;
  ExchangeRate? _rate;
  bool _isLoading = true;
  Failure? _error;

  List<Currency> get currencies => List.unmodifiable(_currencies);
  Currency? get from => _from;
  Currency? get to => _to;
  double get amount => _amount;
  String get amountText {
    final sanitized = _amount == _amount.roundToDouble()
        ? _amount.toInt().toString()
        : _amount.toString();
    return sanitized;
  }

  bool get isLoading => _isLoading;
  Failure? get error => _error;

  /// Result of converting [_amount] from [_from] to [_to], or null when no
  /// rate is loaded yet.
  double? get result => _rate?.convert(_amount);

  /// The current `from -> to` rate, or its inverted companion, for display.
  ExchangeRate? get rate => _rate;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _currencies = await _getCurrencies();
      _from ??= _pick(_currencies, 'USD');
      _to ??= _pick(_currencies, 'CUP');
      await _recalc();
    } on Failure catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setAmount(double amount) {
    _amount = amount;
    unawaited(_recalc());
  }

  void selectFrom(Currency currency) {
    _from = currency;
    unawaited(_recalc());
  }

  void selectTo(Currency currency) {
    _to = currency;
    unawaited(_recalc());
  }

  /// Swaps from/to. Because the next recalc derives `to -> from`, the result
  /// immediately uses the inverse rate while keeping the entered amount.
  Future<void> swap() async {
    final nextFrom = _to ?? _from;
    final nextTo = _from ?? _to;
    _from = nextFrom;
    _to = nextTo;
    await _recalc();
  }

  Currency? _pick(List<Currency> list, String code) {
    for (final currency in list) {
      if (currency.code == code) return currency;
    }
    return list.isEmpty ? null : list.first;
  }

  Future<void> _recalc() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null || from == to) {
      _rate = null;
      notifyListeners();
      return;
    }
    try {
      _rate = await _convert(from: from, to: to);
      _error = null;
    } on Failure catch (error) {
      _rate = null;
      _error = error;
    }
    notifyListeners();
  }
}
