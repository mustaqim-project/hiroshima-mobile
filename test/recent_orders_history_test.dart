import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('POS Recent Orders History & Void Offline-First Tests', () {
    test('submitOrder records order to local recent orders history immediately', () async {
      final sync = PosSyncService.instance;
      sync.setMockUser({
        'id': 1,
        'name': 'Kasir Utama',
        'role': 'cashier',
        'branch_id': 1,
        'branch': {'id': 1, 'name': 'Hiroshima Pusat'},
      });

      final orderPayload = {
        'uuid': 'test-uuid-order-1',
        'order_no': 'HRS-POS-20261028-0001',
        'branch_id': 1,
        'status': 'completed',
        'subtotal': 45000,
        'tax_amount': 4500,
        'total_amount': 49500,
        'client_created_at': DateTime.now().toIso8601String(),
        'table_no': 'A1',
        'order_type': {'name': 'Dine In'},
        'items': [
          {'name': 'Paket Hiro Satu', 'price': 35000, 'qty': 1},
          {'name': 'Ocha Tea', 'price': 10000, 'qty': 1},
        ],
        'payments': [
          {'payment_method_name': 'Tunai (Cash)', 'amount': 50000},
        ],
      };

      await sync.submitOrder(orderPayload);

      final recent = await sync.fetchRecentOrders();
      expect(recent.isNotEmpty, true);
      final found = recent.firstWhere((o) => o['uuid'] == 'test-uuid-order-1');
      expect(found['order_no'], 'HRS-POS-20261028-0001');
      expect(found['status'], 'completed');
      expect(found['total_amount'], 49500);
    });

    test('voidOrder updates status to voided in recent orders list', () async {
      final sync = PosSyncService.instance;

      final res = await sync.voidOrder('HRS-POS-20261028-0001', '123456', 'Salah input pesanan pelanggan');
      expect(res['success'], true);

      final recent = await sync.fetchRecentOrders();
      final found = recent.firstWhere((o) => o['order_no'] == 'HRS-POS-20261028-0001');
      expect(found['status'], 'voided');
      expect(found['void_reason'], 'Salah input pesanan pelanggan');
    });
  });
}
