// @req FSD-11, FR-OFF-07

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/time/trusted_clock.dart';

void main() {
  group('TrustedClock Tests', () {
    test('Synchronizes with verified server time and tracks elapsed time', () {
      final clock = TrustedClock();
      final serverTime = DateTime.parse('2026-10-23T10:00:00+07:00');

      clock.syncWithServer(serverTime);

      final reliableNow = clock.now;
      expect(reliableNow.isAfter(serverTime) || reliableNow.isAtSameMomentAs(serverTime), isTrue);
    });

    test('Detects clock skew when device clock is altered by > 5 minutes', () {
      final clock = TrustedClock();
      // Server is anchored at 2 hours ago
      final oldServerTime = DateTime.now().subtract(const Duration(hours: 2));
      clock.syncWithServer(oldServerTime);

      // Now diff is ~2 hours, which is > 5 minutes
      expect(clock.isClockSkewDetected(), isTrue);
      expect(clock.getClockSkewMinutes(), greaterThan(5));
    });
  });
}
