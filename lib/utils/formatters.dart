// lib/utils/formatters.dart
// Helpers for formatting currency, dates and a decimal TextInputFormatter

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Currency and number formatting helper
class Formatters {
  // Default locale uses device locale — you can pass specific locale if needed
  static String formatCurrency(
    double amount, {
    String? locale,
    String symbol = '₹',
  }) {
    final fmt = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 2,
    );
    return fmt.format(amount);
  }

  /// Format number with commas (no currency symbol)
  static String formatNumber(double amount, {String? locale}) {
    final fmt = NumberFormat.decimalPattern(locale);
    return fmt.format(amount);
  }

  /// Format DateTime to readable string
  static String formatDateTime(DateTime dateTime, {String? locale}) {
    final fmt = DateFormat.yMMMd(locale).add_jm();
    return fmt.format(dateTime);
  }

  /// Format Date only
  static String formatDate(DateTime dateTime, {String? locale}) {
    final fmt = DateFormat.yMMMd(locale);
    return fmt.format(dateTime);
  }

  /// Format relative time (e.g., "2 hours ago", "Just now")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
}

/// A TextInputFormatter that allows only numeric input with optional decimal point.
/// It enforces at most [decimalRange] digits after decimal point.
class DecimalTextInputFormatter extends TextInputFormatter {
  final int decimalRange;
  final bool allowNegative;

  DecimalTextInputFormatter({this.decimalRange = 2, this.allowNegative = false})
    : assert(decimalRange >= 0);

  final _decimalRegExp = RegExp(r'^[0-9]+(\.[0-9]*)?$');
  final _negativeRegExp = RegExp(r'^-?[0-9]+(\.[0-9]*)?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    if (text == '-') {
      // if user types only '-' allow if negatives allowed
      if (allowNegative) return newValue;
      return oldValue;
    }

    if (text.isEmpty) return newValue;

    final reg = allowNegative ? _negativeRegExp : _decimalRegExp;
    if (!reg.hasMatch(text)) {
      return oldValue;
    }

    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length > 2) return oldValue; // multiple dots
      final fraction = parts[1];
      if (fraction.length > decimalRange) {
        // trim to allowed decimals
        final truncated = '${parts[0]}.${fraction.substring(0, decimalRange)}';
        final selectionIndex = truncated.length;
        return TextEditingValue(
          text: truncated,
          selection: TextSelection.collapsed(offset: selectionIndex),
        );
      }
    }

    return newValue;
  }
}
