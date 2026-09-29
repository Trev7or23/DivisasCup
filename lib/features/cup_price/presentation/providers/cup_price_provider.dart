import 'package:flutter/foundation.dart';

import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/domain/repositories/exchange_rate_repository.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Holds the state of the CUP Price home screen: current price, last-week
/// price, computed delta and the full history. Thin consumer of the shared
/// [ExchangeRateRepository]; there is no data layer inside this feature.
class CupPriceProvider extends ChangeNotifier {
  CupPriceProvider({required this._repository});

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
    } catch (error) {
      _error = failureFrom(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetch() async {
    _currencies = await _repository.getSupportedCurrencies();
    _history = await _repository.getCupPriceHistory();
    _current = _history.isEmpty ? null : _history.last;
    final current = _current;
    _lastWeek = current == null
        ? null
        : _pointAt(CurrencyFormatter.dayShift(current.date, -7));
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