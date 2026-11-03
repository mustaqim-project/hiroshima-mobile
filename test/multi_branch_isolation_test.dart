import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/sync/outbox_manager.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OutboxManager().clearForTesting();
  });

  group('Multi-Branch POS Data Isolation Tests', () {
    test('Transactions and shift reports of Branch A NEVER leak into Branch B', () async {
      final sync = PosSyncService.instance;
      sync.resetForTesting();

      // 1. Setup Multi-Branch Owner User
      sync.setMockUser({
        'id': 99,
        'name': 'Super Admin Owner',
        'role': 'owner',
        'can_switch_branch': true,
        'branch': {'id': 1, 'name': 'Hiroshima Pusat (Cabang A)', 'code': 'HRS-A'},
        'accessible_branches': [
          {'id': 1, 'name': 'Hiroshima Pusat (Cabang A)', 'code': 'HRS-A'},
          {'id': 2, 'name': 'Hiroshima Tebet (Cabang B)', 'code': 'HRS-B'},
        ],
      });

      // 2. Open Shift on Branch A
      await sync.openShift(100000);
      expect(sync.hasActiveShift, isTrue);
      expect(sync.hasCrossBranchActiveShift, isFalse);

      // 3. Submit Transaction on Branch A
      final orderBranchA = {
        'uuid': 'order-branch-a-001',
        'order_no': 'HRS-A-20261102-0001',
        'branch_id': 1,
        'status': 'completed',
        'subtotal': 50000,
        'total_amount': 50000,
        'client_created_at': DateTime.now().toIso8601String(),
        'items': [
          {'name': 'Ramen A', 'price': 50000, 'qty': 1, 'subtotal': 50000}
        ],
        'payments': [
          {'payment_method_name': 'Tunai', 'amount': 50000}
        ],
      };
      await sync.submitOrder(orderBranchA);

      // Verify order is present in Branch A's recent orders
      expect(sync.localRecentOrders.length, equals(1));
      expect(sync.localRecentOrders.first['order_no'], equals('HRS-A-20261102-0001'));

      // 4. Also Hold a Bill on Branch A
      await sync.holdOrder({
        'shift_id': sync.currentShift?['id'],
        'branch_id': 1,
        'order_type_id': 1,
        'hold_reference': 'Open Bill Meja A1',
        'items': [
          {'product_id': 10, 'product_name': 'Gyoza', 'quantity': 1, 'unit_price': 25000}
        ],
        'total_amount': 25000,
      });
      expect(sync.heldOrders.length, equals(1));
      expect(sync.heldOrders.first['hold_reference'], equals('Open Bill Meja A1'));

      // 5. Generate local report for Branch A shift -> reflects Branch A's transaction
      final reportA = sync.generateLocalReport(sync.currentShift, 150000);
      expect(reportA['transaction_summary']['completed_transaction_count'], equals(1));
      expect(reportA['transaction_summary']['gross_sales'], equals(50000));

      // 6. NOW SWITCH TO BRANCH B (ID: 2)
      await sync.switchBranch({
        'id': 2,
        'name': 'Hiroshima Tebet (Cabang B)',
        'code': 'HRS-B',
      });

      // 7. STRICT ISOLATION ASSERTIONS ON BRANCH B:
      // a) In-memory recent orders must be empty (Branch A's orders removed)
      expect(sync.localRecentOrders.isEmpty, isTrue);

      // b) In-memory held orders must be empty (Branch A's held bill removed)
      expect(sync.heldOrders.isEmpty, isTrue);

      // c) hasActiveShift on Branch B must be false (since shift was opened on Branch A)
      // d) hasCrossBranchActiveShift must indicate active shift on Branch A
      // Simulate that server returned Branch A's active shift with is_other_branch = true
      sync.setMockCurrentShift({
        'id': 101,
        'branch_id': 1,
        'branch_name': 'Hiroshima Pusat (Cabang A)',
        'is_other_branch': true,
        'status': 'open',
        'opened_at': DateTime.now().toIso8601String(),
        'starting_cash': 100000,
      });

      expect(sync.hasActiveShift, isFalse, reason: 'Branch B cannot treat Branch A shift as active');
      expect(sync.hasCrossBranchActiveShift, isTrue, reason: 'Must detect active shift on another branch');

      // e) Local report generation for Branch B must strictly ignore Branch A's orders
      final reportB = sync.generateLocalReport(
        {'id': 202, 'branch_id': 2, 'opened_at': DateTime.now().toIso8601String(), 'starting_cash': 200000},
        200000,
        isOpenShift: true,
      );
      expect(reportB['transaction_summary']['completed_transaction_count'], equals(0));
      expect(reportB['transaction_summary']['gross_sales'], equals(0));
      expect(reportB['menu_summary']['items'], isEmpty);

      // 8. SWITCH BACK TO BRANCH A:
      // Branch A's data must be safely restored from its isolated cache key!
      await sync.switchBranch({
        'id': 1,
        'name': 'Hiroshima Pusat (Cabang A)',
        'code': 'HRS-A',
      });

      // ignore: avoid_print
      // print('DEBUG localRecentOrders: ${sync.localRecentOrders.map((e) => "${e['order_no']} / ${e['uuid']}").toList()}');
      expect(sync.localRecentOrders.length, equals(1));
      expect(sync.localRecentOrders.first['order_no'], equals('HRS-A-20261102-0001'));
      expect(sync.heldOrders.length, equals(1));
      expect(sync.heldOrders.first['hold_reference'], equals('Open Bill Meja A1'));
    });
  });
}
