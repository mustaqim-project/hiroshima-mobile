// @req FR-POS-01, FR-POS-02, FSD-20
// Comprehensive Responsiveness Tests: Mobile Phone (360x780) vs Tablet (1280x800)

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/pricing/order_calculator.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
import 'package:mobile/features/auth/presentation/pos_login_screen.dart';
import 'package:mobile/features/auth/presentation/pos_preload_screen.dart';
import 'package:mobile/features/pos/presentation/pos_modifier_dialog.dart';
import 'package:mobile/features/pos/presentation/pos_payment_sheet.dart';
import 'package:mobile/features/pos/presentation/pos_shift_sheet.dart';
import 'package:mobile/features/pos/presentation/pos_tablet_screen.dart';
import 'package:mobile/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.resetForTesting();
  });

  tearDown(() {
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.resetForTesting();
  });

  group('Mobile Phone Screen Responsiveness (Compact 360x780)', () {
    const phoneSize = Size(360, 780);

    testWidgets('PosLoginScreen renders on phone without overflow or clipping', (WidgetTester tester) async {
      tester.view.physicalSize = phoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      PosSyncService.instance.setMockUser(null);

      await tester.pumpWidget(const CupertinoApp(home: PosLoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PosLoginScreen), findsOneWidget);
      expect(find.textContaining('HIROSHIMA'), findsWidgets);
      expect(find.text('Username & PIN'), findsOneWidget);
      expect(find.text('Email & Password'), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('PosTabletScreen renders in phone mode with bottom cart bar', (WidgetTester tester) async {
      tester.view.physicalSize = phoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      PosSyncService.instance.setMockUser({
        'id': 1,
        'name': 'Kasir Cikini',
        'role': 'cashier',
      });

      // Populate sample products for testing
      PosSyncService.instance.applyCatalogDataForTesting({
        'branch': {'id': 1, 'name': 'Hiroshima Cikini', 'code': 'HRS-CKN'},
        'categories': [{'id': 1, 'name': 'Ramen', 'code': 'RMN'}],
        'products': [
          {'id': 10, 'name': 'Tori Paitan Ramen', 'category_id': 1, 'price': 38000, 'has_variants': false},
        ],
        'order_types': [{'id': 1, 'name': 'Dine In', 'requires_table': true}],
        'product_prices': [],
        'tables': [],
        'payment_methods': [{'id': 1, 'name': 'Tunai', 'code': 'CASH'}],
      });

      await tester.pumpWidget(const CupertinoApp(home: PosTabletScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PosTabletScreen), findsOneWidget);
      expect(find.textContaining('HIROSHIMA'), findsWidgets);
      expect(find.text('Tori Paitan Ramen'), findsOneWidget);

      // Tap product to add to cart
      await tester.tap(find.text('Tori Paitan Ramen'));
      await tester.pump();

      // On phone, bottom floating bar should appear
      expect(find.text('Bayar'), findsOneWidget);
      expect(find.text('1 item • Dine In'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('PosTabletScreen renders category menu in left vertical rail on compact phone', (WidgetTester tester) async {
      tester.view.physicalSize = phoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      PosSyncService.instance.setMockUser({
        'id': 1,
        'name': 'Kasir Cikini',
        'role': 'cashier',
      });

      PosSyncService.instance.applyCatalogDataForTesting({
        'branch': {'id': 1, 'name': 'Hiroshima Cikini', 'code': 'HRS-CKN'},
        'categories': [
          {'id': 1, 'name': 'Makanan', 'code': 'MKN'},
          {'id': 2, 'name': 'Minuman', 'code': 'MNM'},
        ],
        'products': [
          {'id': 10, 'name': 'Tori Paitan Ramen', 'category_id': 1, 'price': 38000, 'has_variants': false},
        ],
        'order_types': [{'id': 1, 'name': 'Dine In', 'requires_table': true}],
        'product_prices': [],
        'tables': [],
        'payment_methods': [{'id': 1, 'name': 'Tunai', 'code': 'CASH'}],
      });

      await tester.pumpWidget(const CupertinoApp(home: PosTabletScreen()));
      await tester.pumpAndSettle();

      // Check category rail elements
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Makanan'), findsWidgets);
      expect(find.text('Minuman'), findsOneWidget);

      // Verify categories are arranged in a vertical list view (axis: vertical)
      final categoryRailListView = tester.widget<ListView>(
        find.ancestor(
          of: find.text('Semua'),
          matching: find.byType(ListView),
        ).first,
      );
      expect(categoryRailListView.scrollDirection, Axis.vertical);

      // Switching category works smoothly
      await tester.tap(find.text('Minuman'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('PosShiftSheet renders on phone without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = phoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: PosShiftSheet(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Buka Shift Kasir Baru'), findsOneWidget);
      expect(find.text('Buka Shift Sekarang'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PosPaymentSheet renders on phone without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = phoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final calc = OrderCalculator.calculate(
        subtotal: 50000,
        promoDiscount: 0,
        voucherDiscount: 0,
        loyaltyDiscount: 0,
        manualDiscount: 0,
        taxPercent: 11.0,
        serviceChargePercent: 0.0,
        taxIncluded: false,
        roundingMode: 'round_nearest_100',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: PosPaymentSheet(
              cart: const [
                {'id': 1, 'name': 'Tori Paitan', 'price': 50000, 'qty': 1}
              ],
              calculation: calc,
              orderType: 'Dine In',
              orderTypeId: 1,
              tableNo: '1',
              onPaymentSuccess: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Penyelesaian Pembayaran'), findsOneWidget);
      expect(find.text('Konfirmasi Bayar & Cetak Struk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PosModifierDialog renders on phone without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = phoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: PosModifierDialog(
              product: const {
                'id': 1,
                'name': 'Gyoza Panggang',
                'category': 'Appetizer',
                'variants': [
                  {'id': 101, 'name': 'Porsi 4 pcs', 'price': 25000},
                  {'id': 102, 'name': 'Porsi 8 pcs', 'price': 45000},
                ],
                'modifier_groups': [
                  {
                    'id': 201,
                    'name': 'Saus Tambahan',
                    'selection_type': 'single',
                    'is_required': true,
                    'modifiers': [
                      {'id': 301, 'name': 'Chili Oil', 'price': 0},
                      {'id': 302, 'name': 'Sweet Mayo', 'price': 2000},
                    ],
                  }
                ],
              },
              initialPrice: 25000,
              onAddToCart: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Gyoza Panggang'), findsOneWidget);
      expect(find.text('Tambahkan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Tablet Screen Responsiveness (Wide 1280x800)', () {
    const tabletSize = Size(1280, 800);

    testWidgets('PosLoginScreen renders centered card on tablet', (WidgetTester tester) async {
      tester.view.physicalSize = tabletSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      PosSyncService.instance.setMockUser(null);

      await tester.pumpWidget(const CupertinoApp(home: PosLoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PosLoginScreen), findsOneWidget);
      expect(find.textContaining('HIROSHIMA'), findsWidgets);
      expect(find.text('Username & PIN'), findsOneWidget);
      expect(find.text('Email & Password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PosTabletScreen renders split-view (catalog + cart pane) on tablet', (WidgetTester tester) async {
      tester.view.physicalSize = tabletSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      PosSyncService.instance.setMockUser({
        'id': 1,
        'name': 'Kasir Cikini',
        'role': 'cashier',
      });

      PosSyncService.instance.applyCatalogDataForTesting({
        'branch': {'id': 1, 'name': 'Hiroshima Cikini', 'code': 'HRS-CKN'},
        'categories': [{'id': 1, 'name': 'Ramen', 'code': 'RMN'}],
        'products': [
          {'id': 10, 'name': 'Tori Paitan Ramen', 'category_id': 1, 'price': 38000, 'has_variants': false},
        ],
        'order_types': [
          {'id': 1, 'name': 'Dine In', 'requires_table': true},
          {'id': 2, 'name': 'Take Away', 'requires_table': false},
        ],
        'product_prices': [],
        'tables': [],
        'payment_methods': [{'id': 1, 'name': 'Tunai', 'code': 'CASH'}],
      });

      await tester.pumpWidget(const CupertinoApp(home: PosTabletScreen()));
      await tester.pumpAndSettle();

      // Both catalog and split cart pane are visible simultaneously
      expect(find.textContaining('HIROSHIMA'), findsWidgets);
      expect(find.text('Pesanan Berjalan'), findsOneWidget);
      expect(find.text('Dine In'), findsOneWidget);
      expect(find.text('Take Away'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PosTabletScreen maintains category menu horizontally on top on tablet', (WidgetTester tester) async {
      tester.view.physicalSize = tabletSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      PosSyncService.instance.setMockUser({
        'id': 1,
        'name': 'Kasir Cikini',
        'role': 'cashier',
      });

      PosSyncService.instance.applyCatalogDataForTesting({
        'branch': {'id': 1, 'name': 'Hiroshima Cikini', 'code': 'HRS-CKN'},
        'categories': [
          {'id': 1, 'name': 'Makanan', 'code': 'MKN'},
          {'id': 2, 'name': 'Minuman', 'code': 'MNM'},
        ],
        'products': [
          {'id': 10, 'name': 'Tori Paitan Ramen', 'category_id': 1, 'price': 38000, 'has_variants': false},
        ],
        'order_types': [{'id': 1, 'name': 'Dine In', 'requires_table': true}],
        'product_prices': [],
        'tables': [],
        'payment_methods': [{'id': 1, 'name': 'Tunai', 'code': 'CASH'}],
      });

      await tester.pumpWidget(const CupertinoApp(home: PosTabletScreen()));
      await tester.pumpAndSettle();

      // On tablet, categories are inside horizontal ListView
      final tabletCategoryListView = tester.widget<ListView>(
        find.ancestor(
          of: find.text('Semua'),
          matching: find.byType(ListView),
        ).first,
      );
      expect(tabletCategoryListView.scrollDirection, Axis.horizontal);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PosPreloadScreen launches and transitions into PosLoginScreen', (WidgetTester tester) async {
      PosSyncService.instance.setMockUser(null);

      await tester.pumpWidget(const ProviderScope(child: HiroshimaPosApp()));
      expect(find.byType(PosPreloadScreen), findsOneWidget);
      expect(find.text('HIROSHIMA POS'), findsWidgets);

      // Fast forward past the preload animation & delay
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.byType(PosLoginScreen), findsOneWidget);
    });
  });
}
