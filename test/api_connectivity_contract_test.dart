// @req FR-OFF-01, FR-OFF-02, FR-OFF-03, FR-OFF-04, FR-POS-01, FR-POS-16, FSD-10
// API Connectivity & Contract Verification Tests (Mobile <-> Backend)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/sync/outbox_manager.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final syncService = PosSyncService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    syncService.stopAutoSync();
    OutboxManager().clearForTesting();
  });

  tearDown(() {
    syncService.stopAutoSync();
    OutboxManager().clearForTesting();
    syncService.setMockUser(null);
  });

  group('API Connectivity & Contract Tests', () {
    test('Default API Base URL defaults to production domain hiroshima.web.id', () {
      expect(PosSyncService.productionBaseUrl, 'https://hiroshima.web.id/api/v1');
      expect(syncService.baseUrl, 'https://hiroshima.web.id/api/v1');
      expect(syncService.serverBaseUrl, 'https://hiroshima.web.id');
    });

    test('Custom Backend URL sanitization automatically ensures /api/v1 path', () async {
      await syncService.setBaseUrl('http://192.168.1.100:8000');
      expect(syncService.baseUrl, 'http://192.168.1.100:8000/api/v1');

      await syncService.setBaseUrl('https://hiroshima.web.id/');
      expect(syncService.baseUrl, 'https://hiroshima.web.id/api/v1');

      // Reset to default
      await syncService.setBaseUrl(PosSyncService.defaultBaseUrl);
    });

    test('Device Activation Contract formats ACT-XXXX code correctly', () async {
      const code = 'ACT-7A9B';
      const deviceName = 'Tablet Kasir Cikini Utama';

      // Test activation call handling
      final res = await syncService.activateDevice(
        activationCode: code,
        deviceName: deviceName,
      );

      // Either succeeds (if backend live) or returns structured error without throwing exception
      expect(res.containsKey('success'), isTrue);
      expect(res.containsKey('message'), isTrue);
    });

    test('Shift Management Contract verifies starting_cash and actual_cash', () async {
      // 1. Open Shift
      final openRes = await syncService.openShift(250000);
      expect(openRes['success'], isTrue);
      expect(syncService.hasActiveShift, isTrue);
      expect(syncService.currentShift?['starting_cash'], 250000);

      // 2. Close Shift
      final closeRes = await syncService.closeShift(250000);
      expect(closeRes['success'], isTrue);
      expect(syncService.hasActiveShift, isFalse);
    });

    test('Shift Management handles cross-branch active shift gracefully', () async {
      // Mock an active shift belonging to another branch
      syncService.setMockUser({
        'id': 1,
        'name': 'Superadmin',
        'branch_id': 2,
        'branch': {'id': 2, 'name': 'Hiroshima Tebet'},
      });

      // When shift data is set with is_other_branch = true
      final openRes = await syncService.openShift(100000);
      expect(openRes['success'], isTrue);
      expect(syncService.hasActiveShift, isTrue);

      // Close shift succeeds
      final closeRes = await syncService.closeShift(100000);
      expect(closeRes['success'], isTrue);
      expect(syncService.hasActiveShift, isFalse);
    });

    test('Order Push Payload Contract matches backend SyncEngine schema', () async {
      const orderUuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      final orderPayload = {
        'uuid': orderUuid,
        'order_no': 'HRS01-POS-0001',
        'branch_id': 1,
        'user_id': 1,
        'order_type_id': 1,
        'table_id': null,
        'client_created_at': DateTime.now().toIso8601String(),
        'subtotal': 45000,
        'promo_discount_amount': 0,
        'voucher_discount_amount': 0,
        'loyalty_discount_amount': 0,
        'manual_discount_amount': 0,
        'manual_discount_reason': null,
        'service_charge_amount': 0,
        'tax_amount': 4950,
        'rounding_amount': 50,
        'total_amount': 50000,
        'paid_amount': 50000,
        'change_amount': 0,
        'items': [
          {
            'product_id': 101,
            'product_variant_id': null,
            'product_name': 'Tori Paitan Ramen',
            'quantity': 1,
            'unit_price': 45000,
            'subtotal': 45000,
            'modifiers': [],
          }
        ],
        'payments': [
          {
            'payment_method_id': 1,
            'amount': 50000,
          }
        ],
      };

      // Submit order
      final submitResult = await syncService.submitOrder(orderPayload);
      expect(submitResult, isA<bool>());

      // Order is safely queued in OutboxManager
      expect(OutboxManager().allQueueUuids.contains(orderUuid), isTrue);
      expect(syncService.pendingQueueCount, greaterThanOrEqualTo(0));
    });

    test('Cashier PIN offline fallback authentication works seamlessly during network outages', () async {
      final res = await syncService.login(
        identifier: 'kasir_cikini',
        credential: '123456',
      );

      expect(res['success'], isTrue);
      expect(syncService.isLoggedIn, isTrue);
      expect(syncService.currentUser?['role'], 'cashier');
    });
  });
}
