// @req FR-OFF-01, FR-OFF-02, FR-POS-01, FR-POS-02, FSD-10
// Tests verifying 100% dynamic backend catalog ingestion and URL configuration

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic Backend Data Ingestion Tests', () {
    final syncService = PosSyncService.instance;

    test('Catalog data is populated dynamically from backend pull payload', () {
      final backendPayload = {
        'server_time': '2026-10-24T12:00:00+07:00',
        'branch': {
          'id': 2,
          'name': 'Hiroshima Cikini Premium',
          'code': 'HRS-CKN',
          'tax_percent': '11.0',
          'service_charge_percent': '5.0',
          'tax_included': false,
          'rounding_mode': 'round_nearest_100',
          'pin_void_hash': '654321',
          'pin_discount_hash': '123456',
        },
        'categories': [
          {'id': 10, 'name': 'RAMEN SPESIAL', 'code': 'RMN', 'is_active': true},
          {'id': 11, 'name': 'YAKITORI & SKEWERS', 'code': 'YKT', 'is_active': true},
        ],
        'products': [
          {
            'id': 101,
            'name': 'Hiroshima Tori Paitan Ramen',
            'category_id': 10,
            'sku': 'RMN-001',
            'has_variants': true,
            'variants': [
              {'id': 201, 'name': 'Regular Bowl', 'price': 38000},
              {'id': 202, 'name': 'Jumbo Chashu Bowl', 'price': 52000},
            ],
            'modifier_groups': [
              {
                'id': 301,
                'name': 'Pilihan Mi',
                'selection_type': 'single',
                'is_required': true,
                'modifiers': [
                  {'id': 401, 'name': 'Mi Lurus Keriting', 'price': 0},
                  {'id': 402, 'name': 'Mi Tebal Udon', 'price': 3000},
                ],
              },
            ],
          },
        ],
        'order_types': [
          {'id': 1, 'name': 'Dine In', 'is_active': true},
          {'id': 2, 'name': 'Take Away', 'is_active': true},
          {'id': 3, 'name': 'GoFood', 'is_active': true},
        ],
        'product_prices': [
          {'sellable_id': 101, 'order_type_id': 1, 'price': 38000},
          {'sellable_id': 101, 'order_type_id': 3, 'price': 45000},
        ],
        'tables': [
          {'id': 1, 'table_number': 'T-01', 'capacity': 4, 'is_active': true},
          {'id': 2, 'table_number': 'T-02', 'capacity': 2, 'is_active': true},
        ],
        'payment_methods': [
          {'id': 1, 'name': 'Tunai', 'code': 'CASH', 'is_active': true},
          {'id': 2, 'name': 'QRIS Dinamis', 'code': 'QRIS', 'is_active': true},
          {'id': 3, 'name': 'BCA Debit EDC', 'code': 'EDC_BCA', 'is_active': true},
        ],
      };

      syncService.applyCatalogDataForTesting(backendPayload);

      // Verify dynamic branch metadata
      expect(syncService.branch['name'], equals('Hiroshima Cikini Premium'));
      expect(syncService.branch['code'], equals('HRS-CKN'));
      expect(syncService.branch['service_charge_percent'], equals('5.0'));

      // Verify dynamic categories
      expect(syncService.categories.length, equals(2));
      expect(syncService.categories.first['name'], equals('RAMEN SPESIAL'));

      // Verify dynamic products & nested variants/modifiers
      expect(syncService.products.length, equals(1));
      final prod = syncService.products.first;
      expect(prod['name'], equals('Hiroshima Tori Paitan Ramen'));
      expect((prod['variants'] as List).length, equals(2));
      expect((prod['modifier_groups'] as List).length, equals(1));

      // Verify dynamic multi-price for order types (Dine In vs GoFood)
      expect(syncService.getProductPrice(101, 1), equals(38000));
      expect(syncService.getProductPrice(101, 3), equals(45000));

      // Verify tables and payment methods
      expect(syncService.tables.length, equals(2));
      expect(syncService.paymentMethods.length, equals(3));
      expect(syncService.paymentMethods[1]['name'], equals('QRIS Dinamis'));
    });
  });
}
