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

    test('getProductPrice handles branch override priority over central price', () {
      final sync = PosSyncService.instance;

      final mockCatalog = {
        'branch': {'id': 5, 'name': 'Hiroshima Cikini'},
        'order_types': [
          {'id': 1, 'name': 'Dine In', 'code': 'dine_in', 'is_default': true},
          {'id': 2, 'name': 'Take Away', 'code': 'take_away'},
        ],
        'products': [
          {'id': 201, 'name': 'Gyoza Panggang', 'sku': 'GYZ-01', 'manual_cost': 10000},
        ],
        'product_prices': [
          // Central price (branch_id null): 20.000
          {'sellable_id': 201, 'order_type_id': 1, 'branch_id': null, 'price': 20000},
          // Branch override for branch 5: 24.000
          {'sellable_id': 201, 'order_type_id': 1, 'branch_id': 5, 'price': 24000},
        ],
      };

      sync.applyCatalogDataForTesting(mockCatalog);

      // Should prioritize branch override (24.000) over central price (20.000)
      expect(sync.getProductPrice(201, 1), equals(24000));
    });

    test('getProductPrice handles embedded product prices and type resilience (String and int)', () {
      final sync = PosSyncService.instance;

      final mockCatalog = {
        'order_types': [
          {'id': 1, 'name': 'Dine In', 'code': 'dine_in', 'is_default': true},
          {'id': 3, 'name': 'Delivery', 'code': 'delivery'},
        ],
        'products': [
          {
            'id': 301,
            'name': 'Karaage Bowl',
            'sku': 'KB-01',
            'prices': [
              {'order_type_id': 1, 'price': 25000},
              {'order_type_id': 3, 'price': 29000},
            ],
          },
        ],
        'product_prices': [],
      };

      sync.applyCatalogDataForTesting(mockCatalog);

      // Eager loaded embedded prices
      expect(sync.getProductPrice(301, 1), equals(25000));
      expect(sync.getProductPrice('301', '3'), equals(29000), reason: 'Type resilience: String id should match int');
    });

    test('getProductPrice falls back to default order type price when specific order type is unconfigured', () {
      final sync = PosSyncService.instance;

      final mockCatalog = {
        'order_types': [
          {'id': 1, 'name': 'Dine In', 'code': 'dine_in', 'is_default': true},
          {'id': 99, 'name': 'Event Catering', 'code': 'catering', 'is_default': false},
        ],
        'products': [
          {'id': 401, 'name': 'Takoyaki 6 pcs', 'sku': 'TKO-01'},
        ],
        'product_prices': [
          {'sellable_id': 401, 'order_type_id': 1, 'price': 18000},
        ],
      };

      sync.applyCatalogDataForTesting(mockCatalog);

      // When order_type_id 99 is queried, falls back to default order type (id 1) price 18000
      expect(sync.getProductPrice(401, 99), equals(18000));
    });
  });
}
