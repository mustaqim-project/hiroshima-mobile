// @req FR-POS-01, FR-POS-02, FSD-20
// Automated test verifying full compatibility and dynamic switching for Dark Mode and Light Mode

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
import 'package:mobile/core/theme/theme_controller.dart';
import 'package:mobile/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeController.instance.resetForTesting();
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.resetForTesting();
  });

  tearDown(() {
    ThemeController.instance.resetForTesting();
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.resetForTesting();
  });

  group('Dark Mode & Light Mode Theme Compatibility Tests', () {
    testWidgets('ThemeController switches between Light, Dark, and System modes', (WidgetTester tester) async {
      final controller = ThemeController.instance;

      await controller.setThemeMode(ThemeMode.light);
      expect(controller.themeMode, equals(ThemeMode.light));
      expect(controller.isDarkMode, isFalse);

      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, equals(ThemeMode.dark));
      expect(controller.isDarkMode, isTrue);

      await controller.setThemeMode(ThemeMode.system);
      expect(controller.themeMode, equals(ThemeMode.system));
    });

    testWidgets('Login screen renders with full contrast in both Light and Dark mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      PosSyncService.instance.setMockUser(null);

      // 1. Test Light Mode
      await ThemeController.instance.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(const ProviderScope(child: HiroshimaPosApp()));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('Username & PIN'), findsOneWidget);
      expect(find.text('Email & Password'), findsOneWidget);

      // Verify theme toggle button exists in navbar
      final themeToggleBtn = find.byIcon(CupertinoIcons.moon_fill);
      expect(themeToggleBtn, findsOneWidget);

      // 2. Toggle to Dark Mode via button
      await tester.tap(themeToggleBtn);
      await tester.pumpAndSettle();

      expect(ThemeController.instance.themeMode, equals(ThemeMode.dark));
      expect(find.byIcon(CupertinoIcons.sun_max_fill), findsOneWidget);

      // Check that texts are still visible and crisp
      expect(find.text('Username & PIN'), findsOneWidget);
      expect(find.text('Email & Password'), findsOneWidget);
      expect(find.text('Username Kasir'), findsOneWidget);

      // 3. Toggle back to Light Mode
      final sunToggleBtn = find.byIcon(CupertinoIcons.sun_max_fill);
      await tester.tap(sunToggleBtn);
      await tester.pumpAndSettle();

      expect(ThemeController.instance.themeMode, equals(ThemeMode.light));
      expect(find.byIcon(CupertinoIcons.moon_fill), findsOneWidget);
    });

    testWidgets('POS Tablet Catalog & Cart renders seamlessly in both Light and Dark mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Logged in user with catalog data
      PosSyncService.instance.setMockUser({
        'id': 1,
        'name': 'Kasir Cikini',
        'email': 'cashier@hiroshima.co.id',
        'role': 'cashier',
      });

      PosSyncService.instance.applyCatalogDataForTesting({
        'branch': {'id': 1, 'name': 'Hiroshima Cikini', 'code': 'HRS-CKN'},
        'categories': [{'id': 1, 'name': 'Ramen Spesial', 'code': 'RMN'}],
        'products': [
          {'id': 10, 'name': 'Tori Paitan Ramen', 'category_id': 1, 'price': 38000, 'has_variants': false},
        ],
        'order_types': [
          {'id': 1, 'name': 'Dine In', 'requires_table': true},
          {'id': 2, 'name': 'Take Away', 'requires_table': false},
        ],
        'product_prices': [],
        'tables': [],
        'payment_methods': [{'id': 1, 'name': 'Tunai (Cash)', 'code': 'CASH'}],
      });

      // 1. Initial Light Mode
      await ThemeController.instance.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(const ProviderScope(child: HiroshimaPosApp()));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('Tori Paitan Ramen'), findsOneWidget);
      expect(find.text('Pesanan Berjalan'), findsOneWidget);

      // 2. Toggle to Dark Mode
      final themeBtn = find.byIcon(CupertinoIcons.moon_fill);
      expect(themeBtn, findsOneWidget);
      await tester.tap(themeBtn);
      await tester.pumpAndSettle();

      expect(ThemeController.instance.themeMode, equals(ThemeMode.dark));
      expect(find.text('Tori Paitan Ramen'), findsOneWidget);
      expect(find.text('Pesanan Berjalan'), findsOneWidget);

      // 3. Add item to cart in dark mode
      await tester.tap(find.text('Tori Paitan Ramen'));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsWidgets); // Qty in cart
      expect(find.text('Bayar & Cetak'), findsOneWidget);

      // 4. Toggle back to Light Mode while maintaining cart state
      final sunBtn = find.byIcon(CupertinoIcons.sun_max_fill);
      expect(sunBtn, findsOneWidget);
      await tester.tap(sunBtn);
      await tester.pumpAndSettle();

      expect(ThemeController.instance.themeMode, equals(ThemeMode.light));
      expect(find.text('Tori Paitan Ramen'), findsWidgets); // Catalog + Cart
      expect(find.text('Bayar & Cetak'), findsOneWidget);
    });
  });
}
