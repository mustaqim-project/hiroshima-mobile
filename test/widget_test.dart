// @req FR-POS-01, FR-POS-02, FSD-20
// Comprehensive widget testing for Apple HIG Mobile POS (Login + Tablet Catalog)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
import 'package:mobile/main.dart';

void main() {
  setUp(() {
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.setMockUser(null);
  });

  tearDown(() {
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.setMockUser(null);
  });

  testWidgets('Mobile POS renders Apple HIG Login Screen when unauthenticated', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    PosSyncService.instance.setMockUser(null);

    await tester.pumpWidget(const ProviderScope(child: HiroshimaPosApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Brand and Mode selector verification
    expect(find.text('HIROSHIMA'), findsOneWidget);
    expect(find.text('PIN Kasir'), findsOneWidget);
    expect(find.text('Email & Sandi'), findsOneWidget);
    expect(find.text('Aktivasi'), findsOneWidget);
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

    await tester.pumpWidget(const ProviderScope(child: HiroshimaPosApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('HIROSHIMA POS'), findsOneWidget);
    expect(find.text('Dine In'), findsOneWidget);
    expect(find.text('Take Away'), findsOneWidget);
    expect(find.text('Pesanan Berjalan'), findsOneWidget);
  });
}
