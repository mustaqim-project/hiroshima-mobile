// @req FSD-11, BR-15

import 'package:intl/intl.dart';
import 'trusted_clock.dart';

/// Centralized WIB (UTC+7 / Asia/Jakarta) time normalization and formatting utilities.
/// Guarantees 100% consistent date & time representation across all devices,
/// regardless of the physical tablet's system time zone settings.
class WibTime {
  static const Duration wibOffset = Duration(hours: 7);

  /// Convert any DateTime (UTC or local) to WIB clock time.
  /// The returned DateTime has .year, .month, .day, .hour, .minute, .second
  /// matching the WIB (UTC+7) clock.
  static DateTime toWib(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return utc.add(wibOffset);
  }

  /// Parse an ISO-8601 string or date string into a standard UTC physical moment.
  /// If the string does not specify a timezone offset or Z, it is assumed to be in WIB (+07:00).
  static DateTime parse(String dateStr) {
    final trimmed = dateStr.trim();
    if (trimmed.isEmpty) {
      return TrustedClock().now;
    }

    final hasZ = trimmed.endsWith('Z') || trimmed.endsWith('z');
    final hasOffset = RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(trimmed);

    if (hasZ || hasOffset) {
      return DateTime.parse(trimmed).toUtc();
    }

    // If no timezone offset is provided (e.g. '2026-11-02 19:30:00' from DB),
    // treat the value as WIB (UTC+7).
    final normalized = trimmed.contains('T')
        ? '${trimmed}+07:00'
        : '${trimmed.replaceFirst(' ', 'T')}+07:00';
    return DateTime.parse(normalized).toUtc();
  }

  /// Try parsing a dynamic value (DateTime, String, null) into a UTC physical instant.
  static DateTime tryParse(dynamic dateRaw, [DateTime? fallback]) {
    if (dateRaw == null) {
      return fallback ?? TrustedClock().now;
    }
    if (dateRaw is DateTime) {
      return dateRaw.toUtc();
    }
    try {
      return parse(dateRaw.toString());
    } catch (_) {
      return fallback ?? TrustedClock().now;
    }
  }

  /// Format any DateTime in WIB using a DateFormat pattern.
  /// Default pattern: 'dd/MM/yyyy HH:mm'.
  static String format(DateTime? dateTime, [String pattern = 'dd/MM/yyyy HH:mm']) {
    final target = dateTime ?? TrustedClock().now;
    final wib = toWib(target);
    return DateFormat(pattern).format(wib);
  }

  /// Format any DateTime into an ISO-8601 string with explicit +07:00 offset.
  /// Example: '2026-11-02T19:30:00+07:00'
  static String toIso8601String(DateTime? dateTime) {
    final target = dateTime ?? TrustedClock().now;
    final wib = toWib(target);
    final y = wib.year.toString().padLeft(4, '0');
    final m = wib.month.toString().padLeft(2, '0');
    final d = wib.day.toString().padLeft(2, '0');
    final h = wib.hour.toString().padLeft(2, '0');
    final min = wib.minute.toString().padLeft(2, '0');
    final s = wib.second.toString().padLeft(2, '0');
    return '$y-$m-${d}T$h:$min:$s+07:00';
  }

  /// Get current business date in 'YYYY-MM-DD' (WIB).
  static String toBusinessDate([DateTime? dateTime]) {
    final target = dateTime ?? TrustedClock().now;
    final wib = toWib(target);
    final y = wib.year.toString().padLeft(4, '0');
    final m = wib.month.toString().padLeft(2, '0');
    final d = wib.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
