import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CurrencyFormatter {
  static const _englishIndiaLocale = 'en_IN';
  static const _hindiIndiaLocale = 'hi_IN';
  static const _arabicUaeLocale = 'ar_AE';
  static const _thaiThailandLocale = 'th_TH';

  static String currencyCodeForLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'ar':
        return 'AED';
      case 'th':
        return 'THB';
      case 'hi':
      case 'en':
      default:
        return 'INR';
    }
  }

  static String currencyCodeForContext(BuildContext context) {
    return currencyCodeForLocale(Localizations.localeOf(context));
  }

  static String currencyPrefixForContext(BuildContext context) {
    return '${currencyCodeForContext(context)} ';
  }

  static String formatAmount(
    num amount,
    Locale locale, {
    int decimalDigits = 0,
  }) {
    return NumberFormat.currency(
      locale: _numberFormatLocale(locale),
      symbol: currencyCodeForLocale(locale),
      decimalDigits: decimalDigits,
    ).format(amount);
  }

  static String formatAmountForContext(
    BuildContext context,
    num amount, {
    int decimalDigits = 0,
  }) {
    return formatAmount(
      amount,
      Localizations.localeOf(context),
      decimalDigits: decimalDigits,
    );
  }

  static String _numberFormatLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'ar':
        return _arabicUaeLocale;
      case 'th':
        return _thaiThailandLocale;
      case 'hi':
        return _hindiIndiaLocale;
      case 'en':
      default:
        return _englishIndiaLocale;
    }
  }
}
