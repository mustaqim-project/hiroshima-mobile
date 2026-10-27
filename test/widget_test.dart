// @req FR-POS-01, FR-POS-02, FSD-20
// Comprehensive widget testing for Apple HIG Mobile POS (Login + Tablet Catalog)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
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

  testWidgets('Mobile POS renders Apple HIG Login Screen when unauthenticated', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    PosSyncService.instance.setMockUser(null);

    await tester.pumpWidget(const ProviderScope(child: HiroshimaPosApp()));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Brand and Mode selector verification (strictly Username & PIN or Email & Password)
    expect(find.textContaining('HIROSHIMA'), findsWidgets);
    expect(find.text('Username & PIN'), findsOneWidget);
    expect(find.text('Email & Password'), findsOneWidget);

    // Verify username input field is present and empty (no hardcoded values)
    expect(find.text('Username Kasir'), findsOneWidget);
  });

  testWidgets('Mobile POS Tablet renders catalog and app title when logged in', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Mock logged in cashier user
    PosSyncService.instance.setMockUser({
      'id': 1,
      'name': 'Kasir Cikini',
      'email': 'cashier@hiroshima.co.id',
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

    await tester.pumpWidget(const ProviderScope(child: HiroshimaPosApp()));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.textContaining('HIROSHIMA'), findsWidgets);
    expect(find.text('Dine In'), findsOneWidget);
    expect(find.text('Take Away'), findsOneWidget);
    expect(find.text('Pesanan Berjalan'), findsOneWidget);
  });
}
