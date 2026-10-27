// @req FSD-11, FR-OFF-07

/// TrustedClock manages tamper-resistant time synchronization for the POS tablet.
/// It anchors to the last confirmed server time WIB and advances via a monotonic stopwatch,
/// avoiding reliance on user-modifiable device system clock.
class TrustedClock {
  static final TrustedClock _instance = TrustedClock._internal();
  factory TrustedClock() => _instance;
  TrustedClock._internal();

  DateTime? _lastServerTime;
  final Stopwatch _stopwatch = Stopwatch();

  /// Synchronize with verified server time (WIB UTC+7)
  void syncWithServer(DateTime serverTime) {
    _lastServerTime = serverTime;
    _stopwatch.reset();
    _stopwatch.start();
  }

  /// Get reliable current business time
  DateTime get now {
    if (_lastServerTime == null) {
      return DateTime.now().toUtc().add(const Duration(hours: 7));
    }
    return _lastServerTime!.add(_stopwatch.elapsed);
  }

  /// Check if device clock deviates by more than 5 minutes from trusted time
  bool isClockSkewDetected() {
    if (_lastServerTime == null) return false;
    final deviceNow = DateTime.now();
    final reliable = now;
    final diff = deviceNow.difference(reliable).abs();
    return diff.inMinutes > 5;
  }

  /// Get diff in minutes between device clock and server time
  int getClockSkewMinutes() {
    if (_lastServerTime == null) return 0;
    return DateTime.now().difference(now).abs().inMinutes;
  }
}
