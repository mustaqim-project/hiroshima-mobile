// @req FR-POS-01, FR-POS-01a, FR-POS-01b, FR-POS-13, FSD-09
// Tests verifying Cashier Shift Persistence across App Restarts, Lifecycles, and Offline Fallbacks

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Shift Persistence & Lifecycle Resilience Tests', () {
    test('Offline Open Shift is persisted to SharedPreferences disk cache', () async {
      final sync = PosSyncService.instance;
      sync.resetForTesting();

      // Open shift in offline mode (dummy/offline fallback)
      final res = await sync.openShift(150000);
      expect(res['success'], isTrue);
      expect(sync.hasActiveShift, isTrue);
      expect(sync.currentShift?['starting_cash'], equals(150000));
      expect(sync.currentShift?['status'], equals('open'));

      // Check SharedPreferences disk key
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('hiroshima_pos_current_shift_cache_v1');
      expect(savedStr, isNotNull);
      final savedJson = jsonDecode(savedStr!) as Map<String, dynamic>;
      expect(savedJson['starting_cash'], equals(150000));
      expect(savedJson['status'], equals('open'));
    });

    test('Active shift is restored from SharedPreferences across app restart / reloadFromDisk', () async {
      final sync = PosSyncService.instance;
      sync.resetForTesting();

      // Pre-seed disk cache simulating previous active shift
      final preSeedShift = {
        'id': 999,
        'branch_id': 1,
        'branch_name': 'Hiroshima Pusat',
        'starting_cash': 200000,
        'expected_cash': 200000,
        'opened_at': DateTime.now().toIso8601String(),
        'status': 'open',
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hiroshima_pos_current_shift_cache_v1', jsonEncode(preSeedShift));

      // Reload from disk simulating fresh app startup
      await sync.reloadFromDisk();

      expect(sync.hasActiveShift, isTrue);
      expect(sync.currentShift?['id'], equals(999));
      expect(sync.currentShift?['starting_cash'], equals(200000));
      expect(sync.currentShift?['branch_name'], equals('Hiroshima Pusat'));
    });

    test('Closing shift clears shift state and removes disk cache', () async {
      final sync = PosSyncService.instance;
      sync.resetForTesting();

      // Pre-seed shift
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hiroshima_pos_current_shift_cache_v1', jsonEncode({
        'id': 888,
        'status': 'open',
        'starting_cash': 100000,
      }));
      await sync.reloadFromDisk();
      expect(sync.hasActiveShift, isTrue);

      // Close shift
      final res = await sync.closeShift(100000);
      expect(res['success'], isTrue);
      expect(sync.hasActiveShift, isFalse);
      expect(sync.currentShift, isNull);

      // Verify removed from disk
      final diskStr = prefs.getString('hiroshima_pos_current_shift_cache_v1');
      expect(diskStr, isNull);
    });

    test('Logout clears active shift and removes shift disk cache', () async {
      final sync = PosSyncService.instance;
      sync.resetForTesting();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hiroshima_pos_current_shift_cache_v1', jsonEncode({
        'id': 777,
        'status': 'open',
        'starting_cash': 50000,
      }));
      await sync.reloadFromDisk();
      expect(sync.hasActiveShift, isTrue);

      await sync.logout();
      expect(sync.hasActiveShift, isFalse);
      expect(sync.currentShift, isNull);

      final diskStr = prefs.getString('hiroshima_pos_current_shift_cache_v1');
      expect(diskStr, isNull);
    });

    test('Network error during fetchCurrentShift does not wipe locally cached active shift', () async {
      final sync = PosSyncService.instance;
      sync.resetForTesting();

      // Seed active shift
      await sync.openShift(100000);
      expect(sync.hasActiveShift, isTrue);

      // Set baseUrl to invalid port to trigger network error/timeout
      sync.baseUrl = 'http://127.0.0.1:54321/api/v1';

      final res = await sync.fetchCurrentShift();
      expect(res['success'], isFalse);
      // Crucial: currentShift MUST remain intact and not wiped to null
      expect(sync.hasActiveShift, isTrue);
      expect(sync.currentShift?['starting_cash'], equals(100000));
    });
  });
}

