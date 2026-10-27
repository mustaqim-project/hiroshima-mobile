import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';

void main() {
  group('Multi-Price per Order Type Tests (FR-PRICE-01, FR-PRICE-02)', () {
    test('getProductPrice returns different prices for Dine In, Take Away, and Delivery', () {
      final sync = PosSyncService.instance;

      // Simulate catalog with multi-pricing
      final mockCatalog = {
        'order_types': [
          {'id': 1, 'name': 'Dine In', 'code': 'dine_in'},
          {'id': 2, 'name': 'Take Away', 'code': 'take_away'},
          {'id': 3, 'name': 'Delivery', 'code': 'delivery'},
        ],
        'products': [
          {'id': 101, 'name': 'Hiroshima Spicy Ramen', 'sku': 'RMN-001', 'manual_cost': 15000},
          {'id': 102, 'name': 'Ocha Dingin', 'sku': 'MNM-001', 'manual_cost': 3000},
        ],
        'product_prices': [
          // Ramen: Dine In 30.000, Take Away 32.000 (biaya packaging), Delivery 35.000 (ojol margin)
          {'sellable_id': 101, 'order_type_id': 1, 'price': 30000},
          {'sellable_id': 101, 'order_type_id': 2, 'price': 32000},
          {'sellable_id': 101, 'order_type_id': 3, 'price': 35000},
          // Ocha: Dine In 5.000, Take Away 6.000, Delivery 7.000
          {'sellable_id': 102, 'order_type_id': 1, 'price': 5000},
          {'sellable_id': 102, 'order_type_id': 2, 'price': 6000},
          {'sellable_id': 102, 'order_type_id': 3, 'price': 7000},
        ],
      };

      sync.applyCatalogDataForTesting(mockCatalog);

      // Verify Ramen Prices per Order Type
      expect(sync.getProductPrice(101, 1), equals(30000), reason: 'Harga Dine In harus Rp 30.000');
      expect(sync.getProductPrice(101, 2), equals(32000), reason: 'Harga Take Away harus Rp 32.000');
      expect(sync.getProductPrice(101, 3), equals(35000), reason: 'Harga Delivery harus Rp 35.000');

      // Verify Ocha Prices per Order Type
      expect(sync.getProductPrice(102, 1), equals(5000), reason: 'Harga Dine In harus Rp 5.000');
      expect(sync.getProductPrice(102, 2), equals(6000), reason: 'Harga Take Away harus Rp 6.000');
      expect(sync.getProductPrice(102, 3), equals(7000), reason: 'Harga Delivery harus Rp 7.000');
    });
  });
}
