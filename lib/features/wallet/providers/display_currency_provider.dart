import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplayCurrencyProvider extends ChangeNotifier {
  static const _storageKey = 'wallet_display_currency';
  static const supported = <String>[
    'USD',
    'EUR',
    'GBP',
    'NGN',
    'GHS',
    'KES',
    'ZAR',
    'CAD',
    'AUD',
  ];

  static const labels = <String, String>{
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'NGN': 'Nigerian Naira',
    'GHS': 'Ghanaian Cedi',
    'KES': 'Kenyan Shilling',
    'ZAR': 'South African Rand',
    'CAD': 'Canadian Dollar',
    'AUD': 'Australian Dollar',
  };

  static const symbols = <String, String>{
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'NGN': '₦',
    'GHS': 'GH₵',
    'KES': 'KSh',
    'ZAR': 'R',
    'CAD': 'CA\$',
    'AUD': 'A\$',
  };

  static const _fallbackRates = <String, double>{
    'USD': 1,
    'EUR': .92,
    'GBP': .79,
    'NGN': 1550,
    'GHS': 15.5,
    'KES': 129,
    'ZAR': 18.2,
    'CAD': 1.36,
    'AUD': 1.51,
  };

  String _currency = 'USD';
  final Map<String, double> _rates = Map<String, double>.from(_fallbackRates);

  DisplayCurrencyProvider() {
    _load();
  }

  String get currency => _currency;
  String get label => labels[_currency] ?? _currency;
  String get symbol => symbols[_currency] ?? _currency;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null && supported.contains(saved)) {
      _currency = saved;
      notifyListeners();
    }
  }

  Future<void> setCurrency(String value) async {
    if (!supported.contains(value) || value == _currency) return;
    _currency = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value);
    notifyListeners();
  }

  String formatUsd(num? usd, {bool unitPrice = false}) {
    if (usd == null) return '—';
    final converted = usd.toDouble() * (_rates[_currency] ?? 1);
    final absolute = converted.abs();
    final decimals = unitPrice
        ? absolute >= 1
              ? 2
              : absolute >= .0001
              ? 4
              : absolute >= .000001
              ? 6
              : 8
        : 2;
    final fixed = converted.toStringAsFixed(decimals).split('.');
    final whole = fixed.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '$symbol$whole.${fixed[1]}';
  }

  double usdToDisplay(num usd) => usd.toDouble() * (_rates[_currency] ?? 1);

  double? displayToUsd(num? value) {
    if (value == null) return null;
    final rate = _rates[_currency];
    return rate == null || rate <= 0 ? null : value.toDouble() / rate;
  }
}
