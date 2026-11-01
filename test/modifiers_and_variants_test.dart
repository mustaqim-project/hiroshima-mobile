import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/printing/receipt_builder.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
import 'package:mobile/features/pos/presentation/pos_modifier_dialog.dart';

void main() {
  group('Modifiers and Variants POS Printing Tests', () {
    final customItem = [
      {
        'id': 16,
        'name': 'CHICKEN KATSU (Jumbo)',
        'qty': 2,
        'price': 41000, // 35k variant + 6k extra mozzarella
        'notes': 'Level 2 (Pedas Mantap), Ekstra Keju Mozzarella',
        'modifiers': [
          {'name': 'Level 2 (Pedas Mantap)', 'price': 0},
          {'name': 'Ekstra Keju Mozzarella', 'price': 6000},
        ],
      },
    ];

    test('Customer receipt includes indented modifier items with their add-on prices', () {
      final receipt = ReceiptBuilder.buildCustomerReceipt(
        branchName: 'Hiroshima Cikini',
        branchAddress: 'Jl. Cikini Raya',
        branchPhone: '0812345678',
        orderNo: 'HRS-CKN-001',
        tableNo: null,
        orderTypeName: 'Dine In',
        cashierName: 'Kasir 1',
        transactionTime: DateTime.parse('2026-10-23 13:00:00'),
        items: customItem,
        subtotal: 82000,
        totalDiscount: 0,
        serviceChargeAmount: 0,
        taxAmount: 9020,
        roundingAmount: -20,
        totalAmount: 91000,
        payments: [{'method': 'Tunai', 'amount': 100000}],
        changeAmount: 9000,
      );

      expect(receipt, contains('CHICKEN KATSU (Jumbo)'));
      expect(receipt, contains('+ Level 2 (Pedas Mantap) (Rp 0)'));
      expect(receipt, contains('+ Ekstra Keju Mozzarella (Rp 6.000)'));
      expect(receipt, contains('TOTAL BAYAR'));
      expect(receipt, contains('Rp 91.000'));
    });

    test('Kitchen ticket includes modifiers for preparation without revealing prices', () {
      final kitchenTicket = ReceiptBuilder.buildKitchenTicket(
        branchName: 'Hiroshima Cikini',
        orderNo: 'HRS-CKN-001',
        tableNo: null,
        orderTypeName: 'Take Away',
        transactionTime: DateTime.parse('2026-10-23 13:00:00'),
        items: customItem,
        targetStation: 'DAPUR',
      );

      expect(kitchenTicket, contains('2x  CHICKEN KATSU (Jumbo)'));
      expect(kitchenTicket, contains('+ Level 2 (Pedas Mantap)'));
      expect(kitchenTicket, contains('+ Ekstra Keju Mozzarella'));
      expect(kitchenTicket, contains('Catatan: Level 2 (Pedas Mantap), Ekstra Keju Mozzarella'));

      // Ensure no price leak in kitchen ticket
      expect(kitchenTicket, isNot(contains('Rp ')));
      expect(kitchenTicket, isNot(contains('TOTAL')));
    });
    test('Receipt correctly formats variant_name when passed separately from product name', () {
      final itemWithSeparateVariant = [
        {
          'id': 16,
          'name': 'CHICKEN KATSU',
          'variant_name': 'Jumbo',
          'qty': 1,
          'price': 41000,
          'modifiers': [
            {'name': 'Ekstra Mozzarella', 'price': 6000},
          ],
        },
      ];

      final customerReceipt = ReceiptBuilder.buildCustomerReceipt(
        branchName: 'Hiroshima Cikini',
        branchAddress: 'Jl. Cikini Raya',
        branchPhone: '0812345678',
        orderNo: 'HRS-CKN-002',
        tableNo: null,
        orderTypeName: 'Dine In',
        cashierName: 'Kasir 1',
        transactionTime: DateTime.parse('2026-10-23 13:00:00'),
        items: itemWithSeparateVariant,
        subtotal: 41000,
        totalDiscount: 0,
        serviceChargeAmount: 0,
        taxAmount: 4510,
        roundingAmount: -10,
        totalAmount: 45500,
        payments: [{'method': 'Tunai', 'amount': 50000}],
        changeAmount: 4500,
      );

      expect(customerReceipt, contains('CHICKEN KATSU (Jumbo)'));
      expect(customerReceipt, contains('+ Ekstra Mozzarella (Rp 6.000)'));

      final kitchenTicket = ReceiptBuilder.buildKitchenTicket(
        branchName: 'Hiroshima Cikini',
        orderNo: 'HRS-CKN-002',
        tableNo: '05',
        orderTypeName: 'Dine In',
        transactionTime: DateTime.parse('2026-10-23 13:00:00'),
        items: itemWithSeparateVariant,
        targetStation: 'DAPUR',
      );

      expect(kitchenTicket, contains('1x  CHICKEN KATSU (Jumbo)'));
      expect(kitchenTicket, contains('+ Ekstra Mozzarella'));
    });

    testWidgets('PosModifierDialog renders variants, calculates add-on prices, and submits to cart', (tester) async {
      final product = {
        'id': 101,
        'name': 'Ramen Spesial',
        'category': 'Makanan',
        'has_variants': true,
        'variants': [
          {'id': 1, 'name': 'Porsi Regular', 'price': 30000},
          {'id': 2, 'name': 'Porsi Jumbo', 'price': 45000},
        ],
        'modifier_groups': [
          {
            'id': 10,
            'name': 'Level Pedas',
            'selection_type': 'single',
            'is_required': true,
            'min_select': 1,
            'modifiers': [
              {'id': 201, 'name': 'Level 0 (Gurih)', 'price': 0},
              {'id': 202, 'name': 'Level 3 (Extra Pedas)', 'price': 3000},
            ],
          },
          {
            'id': 20,
            'name': 'Ekstra Topping',
            'selection_type': 'multiple',
            'is_required': false,
            'modifiers': [
              {'id': 301, 'name': 'Ajitsuke Tamago', 'price': 5000},
            ],
          },
        ],
      };

      Map<String, dynamic>? selectedVariantResult;
      List<Map<String, dynamic>> selectedModifiersResult = [];

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (ctx) => CupertinoButton(
                child: const Text('Buka Dialog'),
                onPressed: () {
                  PosModifierDialog.show(
                    context: ctx,
                    product: product,
                    initialPrice: 30000,
                    onAddToCart: (variant, modifiers) {
                      selectedVariantResult = variant;
                      selectedModifiersResult = modifiers;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      // Verify product and variants are visible
      expect(find.text('Ramen Spesial'), findsOneWidget);
      expect(find.text('Porsi Regular'), findsOneWidget);
      expect(find.text('Porsi Jumbo'), findsOneWidget);
      expect(find.text('LEVEL PEDAS'), findsOneWidget);
      expect(find.text('EKSTRA TOPPING'), findsOneWidget);

      // Default selection: Porsi Regular (30.000) + Level 0 (0) = Rp 30.000
      expect(find.text('Rp 30.000'), findsWidgets);

      // Tap Porsi Jumbo (45.000)
      await tester.tap(find.text('Porsi Jumbo'));
      await tester.pumpAndSettle();

      // Total updates to Rp 45.000
      expect(find.text('Rp 45.000'), findsWidgets);

      // Tap Level 3 (+3.000)
      await tester.tap(find.text('Level 3 (Extra Pedas)'));
      await tester.pumpAndSettle();

      // Total updates to Rp 48.000 (45k + 3k)
      expect(find.text('Rp 48.000'), findsWidgets);

      // Tap Ajitsuke Tamago (+5.000)
      await tester.tap(find.text('Ajitsuke Tamago'));
      await tester.pumpAndSettle();

      // Total updates to Rp 53.000 (45k + 3k + 5k)
      expect(find.text('Rp 53.000'), findsWidgets);

      // Tap 'Tambahkan'
      await tester.tap(find.text('Tambahkan'));
      await tester.pumpAndSettle();

      // Verify callback returned correct variant and modifiers
      expect(selectedVariantResult?['id'], 2);
      expect(selectedVariantResult?['name'], 'Porsi Jumbo');
      expect(selectedModifiersResult.length, 2);
      expect(selectedModifiersResult.any((m) => m['id'] == 202), isTrue); // Level 3
      expect(selectedModifiersResult.any((m) => m['id'] == 301), isTrue); // Tamago
    });

    testWidgets('Chicken Katsu variant pricing displays 30k (Reguler) and 45k (Jumbo) without collision with Product 1 & 2', (tester) async {
      final sync = PosSyncService.instance;
      sync.stopAutoSync();
      sync.resetForTesting();

      final mockCatalog = {
        'order_types': [
          {'id': 1, 'name': 'Dine In', 'code': 'dine_in', 'is_default': true},
        ],
        'products': [
          {
            'id': 1,
            'name': 'PAKET HIRO 1',
            'price': 29000,
            'sku': 'HRS-001',
          },
          {
            'id': 2,
            'name': 'PAKET HIRO 2',
            'price': 70000,
            'sku': 'HRS-002',
          },
          {
            'id': 16,
            'name': 'CHICKEN KATSU',
            'price': 30000,
            'sku': 'HRS-016',
            'has_variants': true,
            'variants': [
              {
                'id': 1,
                'product_id': 16,
                'name': 'Porsi Reguler (1 Katsu Cutlet)',
                'price': 30000,
                'sku': 'HRS-016-REG',
              },
              {
                'id': 2,
                'product_id': 16,
                'name': 'Porsi Jumbo Double (2 Katsu Cutlet)',
                'price': 45000,
                'sku': 'HRS-016-JMB',
              },
            ],
            'modifier_groups': [],
          },
        ],
        'product_prices': [
          {'sellable_type': 'Product', 'sellable_id': 1, 'order_type_id': 1, 'price': 29000},
          {'sellable_type': 'Product', 'sellable_id': 2, 'order_type_id': 1, 'price': 70000},
          {'sellable_type': 'Product', 'sellable_id': 16, 'order_type_id': 1, 'price': 30000},
        ],
      };

      sync.applyCatalogDataForTesting(mockCatalog);

      // Verify PosSyncService.getProductPrice logic directly
      final v1Price = sync.getProductPrice(1, 1, sellableType: 'variant', defaultPrice: 30000);
      final v2Price = sync.getProductPrice(2, 1, sellableType: 'variant', defaultPrice: 45000);

      expect(v1Price, 30000, reason: 'Variant 1 price must be 30000, not Product 1 price (29000)');
      expect(v2Price, 45000, reason: 'Variant 2 price must be 45000, not Product 2 price (70000)');

      // Verify UI dialog rendering with orderTypeId = 1
      final chickenKatsu = (mockCatalog['products'] as List)[2] as Map<String, dynamic>;

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (ctx) => CupertinoButton(
                child: const Text('Buka Chicken Katsu'),
                onPressed: () {
                  PosModifierDialog.show(
                    context: ctx,
                    product: chickenKatsu,
                    initialPrice: 30000,
                    orderTypeId: 1,
                    onAddToCart: (variant, modifiers) {},
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Chicken Katsu'));
      await tester.pumpAndSettle();

      // Ensure dialog displays 30.000 and 45.000, NOT 29.000 or 70.000
      expect(find.text('Porsi Reguler (1 Katsu Cutlet)'), findsOneWidget);
      expect(find.text('Porsi Jumbo Double (2 Katsu Cutlet)'), findsOneWidget);
      expect(find.text('Rp 30.000'), findsWidgets);
      expect(find.text('Rp 45.000'), findsOneWidget);
      expect(find.text('Rp 29.000'), findsNothing);
      expect(find.text('Rp 70.000'), findsNothing);
    });
  });
}
