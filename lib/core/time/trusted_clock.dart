// @req FSD-11, FR-OFF-07

import 'wib_time.dart';

/// TrustedClock manages tamper-resistant time synchronization for the POS tablet.
/// It anchors to the last confirmed server time WIB and advances via a monotonic stopwatch,
/// avoiding reliance on user-modifiable device system clock.
class TrustedClock {
  static final TrustedClock _instance = TrustedClock._internal();
  factory TrustedClock() => _instance;
  TrustedClock._internal();

  DateTime? _anchorServerUtc;
  final Stopwatch _stopwatch = Stopwatch();

  /// Synchronize with verified server time (WIB UTC+7)
  void syncWithServer(DateTime serverTime) {
    _anchorServerUtc = serverTime.toUtc();
    _stopwatch.reset();
    _stopwatch.start();
  }

  /// Get current trusted physical instant in UTC
  DateTime get nowUtc {
    if (_anchorServerUtc == null) {
      return DateTime.now().toUtc();
    }
    return _anchorServerUtc!.add(_stopwatch.elapsed);
  }

  /// Get current trusted physical instant (UTC)
  DateTime get now => nowUtc;

  /// Get current trusted business time in WIB (UTC+7)
  DateTime get nowWib => WibTime.toWib(nowUtc);

  /// Get ISO 8601 string representation with explicit +07:00 offset
  String get nowIso => WibTime.toIso8601String(nowUtc);

  /// Check if device clock deviates by more than 5 minutes from trusted time.
  /// Compares absolute UTC physical moments, immune to tablet local timezone drift.
  bool isClockSkewDetected() {
    if (_anchorServerUtc == null) return false;
    final deviceUtc = DateTime.now().toUtc();
    final diff = deviceUtc.difference(nowUtc).abs();
    return diff.inMinutes > 5;
  }

  /// Get diff in minutes between device clock and server time
  int getClockSkewMinutes() {
    if (_anchorServerUtc == null) return 0;
    return DateTime.now().toUtc().difference(nowUtc).abs().inMinutes;
  }
}
