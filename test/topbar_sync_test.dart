import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
import 'package:mobile/core/sync/outbox_manager.dart';
import 'package:mobile/features/pos/presentation/pos_tablet_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.resetForTesting();
    OutboxManager().clearForTesting();
  });

  tearDown(() {
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.resetForTesting();
    OutboxManager().clearForTesting();
  });

  testWidgets('Top bar sync badge triggers syncAll and persists all data and caches', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Setup authenticated user
    PosSyncService.instance.setMockUser({
      'id': 1,
      'name': 'Superadmin',
      'username': 'superadmin',
      'role': 'central_admin',
      'branch_id': 1,
      'branch': {'id': 1, 'name': 'Hiroshima Cilandak', 'code': 'HRSCLD'},
      'can_switch_branch': true,
    });

    PosSyncService.instance.setMockCurrentShift({
      'id': 7,
      'branch_id': 1,
      'user_id': 1,
      'status': 'open',
      'starting_cash': 100000,
      'opened_at': '2026-11-03T10:00:00Z',
    });

    final mockCatalog = {
      'server_time': '2026-11-03T15:30:00+07:00',
      'branch': {'id': 1, 'name': 'Hiroshima Cilandak', 'code': 'HRSCLD'},
      'categories': [{'id': 1, 'name': 'Sushi'}],
      'products': [
        {
          'id': 1,
          'category_id': 1,
          'category': 'Sushi',
          'name': 'Salmon Nigiri',
          'base_price': 35000,
          'prices': [],
          'variants': [],
          'modifierGroups': [],
        }
      ],
      'order_types': [{'id': 1, 'name': 'Dine In', 'requires_table': false}],
      'tables': [],
      'payment_methods': [{'id': 1, 'name': 'Tunai (Cash)', 'code': 'cash'}],
    };

    // Pre-populate catalog cache in disk & memory
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PosSyncService.prefKeyCatalogCache, jsonEncode(mockCatalog));
    PosSyncService.instance.applyCatalogDataForTesting(mockCatalog);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosTabletScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify product rendered from catalog
    expect(find.text('Salmon Nigiri'), findsOneWidget);

    // Verify Top Bar Sync Badge is visible (in test env without HTTP server, it enters Offline mode)
    final syncBadge = find.textContaining('Offline');
    expect(syncBadge, findsOneWidget);

    // Tap Top Bar Sync Badge to trigger manual syncAll
    await tester.tap(syncBadge);
    await tester.pump(); // Start sync frame
    await tester.pumpAndSettle();

    // Verify SnackBar feedback appears
    expect(find.textContaining('Koneksi ke backend terputus'), findsOneWidget);

    // Verify catalog cache in SharedPreferences remains preserved & available
    expect(prefs.containsKey(PosSyncService.prefKeyCatalogCache), isTrue);
  });
}
