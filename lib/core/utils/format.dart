import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../constants/categories.dart';

/// Money / date formatting helpers. All formatting is locale-aware through
/// `intl`, falling back to en-US formatting when no specific locale is given.
class Format {
  Format._();

  static String money(double amount, String currency, {Locale? locale}) {
    final code = locale?.languageCode ?? 'en';
    final fmt = NumberFormat.currency(
      locale: code,
      name: currency,
      symbol: _symbolFor(currency, code),
      decimalDigits: 2,
    );
    return fmt.format(amount);
  }

  static String moneyShort(double amount, String currency, {Locale? locale}) {
    final code = locale?.languageCode ?? 'en';
    final fmt = NumberFormat.currency(
      locale: code,
      name: currency,
      symbol: _symbolFor(currency, code),
      decimalDigits: 0,
    );
    return fmt.format(amount);
  }

  static String date(DateTime d, {Locale? locale}) {
    final code = locale?.languageCode ?? 'en';
    return DateFormat.yMMMd(code).format(d);
  }

  static String monthYear(DateTime d, {Locale? locale}) {
    final code = locale?.languageCode ?? 'en';
    return DateFormat.yMMMM(code).format(d);
  }

  static String _symbolFor(String currency, String localeCode) {
    switch (currency) {
      case AppConstants.currencyEgp:
        return localeCode == 'ar' ? 'ج.م' : 'EGP';
      case AppConstants.currencyUsd:
        return localeCode == 'ar' ? 'د.إ' : '\$';
      default:
        return currency;
    }
  }
}

/// Resolves a [CategoryDef] by id, falling back to a synthetic one for
/// user-defined categories (whose metadata is stored in the DB).
class CategoryResolver {
  CategoryResolver._();

  /// Returns the predefined [CategoryDef] or null if not predefined.
  static CategoryDef? predefined(String id) => PredefinedCategories.byId(id);
}
