import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
import 'package:mobile/core/update/app_update_service.dart';
import 'package:mobile/features/pos/presentation/pos_tablet_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.resetForTesting();
    AppUpdateService.instance.resetForTesting();
  });

  tearDown(() {
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.resetForTesting();
  });

  testWidgets('Cashier Menu CupertinoActionSheet renders buttons in prioritized order with clean layout', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Setup authenticated user with multi-branch and active shift
    PosSyncService.instance.setMockUser({
      'id': 1,
      'name': 'Superadmin',
      'username': 'superadmin',
      'role': 'central_admin',
      'branch_id': 1,
      'branch': {'id': 1, 'name': 'Hiroshima Cilandak', 'code': 'HRSCLD'},
      'can_switch_branch': true,
      'accessible_branches': [
        {'id': 1, 'name': 'Hiroshima Cilandak', 'code': 'HRSCLD'},
        {'id': 2, 'name': 'Hiroshima Blok M', 'code': 'HRSBLM'},
      ],
    });

    PosSyncService.instance.setMockCurrentShift({
      'id': 7,
      'branch_id': 1,
      'user_id': 1,
      'status': 'open',
      'starting_cash': 100000,
      'opened_at': '2026-11-03T10:00:00Z',
    });

    await tester.pumpWidget(
      const CupertinoApp(
        home: PosTabletScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Find and tap Cashier User Menu Pill in top bar
    final cashierPill = find.byIcon(CupertinoIcons.person_crop_circle_fill);
    expect(cashierPill, findsOneWidget);
    await tester.tap(cashierPill);
    await tester.pumpAndSettle();

    // Verify ActionSheet Title and Message
    expect(find.text('Superadmin'), findsWidgets);
    expect(find.textContaining('Peran: Superadmin'), findsOneWidget);
    expect(find.textContaining('Cabang: Hiroshima Cilandak'), findsOneWidget);

    // Verify all 9 actions in expected operational order
    final shiftAction = find.text('Kelola Shift & Kas Drawer');
    final previewAction = find.text('Preview Transaksi Shift (X-Report)');
    final historyAction = find.text('Riwayat & Void Transaksi');
    final openBillAction = find.text('Daftar Open Bill');
    final printerAction = find.text('Printer Kasir Bluetooth');
    final branchAction = find.text('Ganti Cabang Operasional');
    final otaAction = find.text('Cek Pembaruan Aplikasi (OTA)');
    final switchUserAction = find.text('Ganti Akun Kasir');
    final logoutAction = find.text('Keluar Sesi POS');
    final cancelAction = find.text('Batal');

    expect(shiftAction, findsOneWidget);
    expect(previewAction, findsOneWidget);
    expect(historyAction, findsOneWidget);
    expect(openBillAction, findsOneWidget);
    expect(printerAction, findsOneWidget);
    expect(branchAction, findsOneWidget);
    expect(otaAction, findsOneWidget);
    expect(switchUserAction, findsOneWidget);
    expect(logoutAction, findsOneWidget);
    expect(cancelAction, findsOneWidget);

    // Verify vertical order (Y-coordinates strictly increasing top to bottom)
    final shiftY = tester.getTopLeft(shiftAction).dy;
    final previewY = tester.getTopLeft(previewAction).dy;
    final historyY = tester.getTopLeft(historyAction).dy;
    final openBillY = tester.getTopLeft(openBillAction).dy;
    final printerY = tester.getTopLeft(printerAction).dy;
    final branchY = tester.getTopLeft(branchAction).dy;
    final otaY = tester.getTopLeft(otaAction).dy;
    final switchUserY = tester.getTopLeft(switchUserAction).dy;
    final logoutY = tester.getTopLeft(logoutAction).dy;
    final cancelY = tester.getTopLeft(cancelAction).dy;

    expect(shiftY < previewY, isTrue, reason: 'Shift should be above Preview Shift');
    expect(previewY < historyY, isTrue, reason: 'Preview Shift should be above History & Void');
    expect(historyY < openBillY, isTrue, reason: 'History & Void should be above Open Bill');
    expect(openBillY < printerY, isTrue, reason: 'Open Bill should be above Printer');
    expect(printerY < branchY, isTrue, reason: 'Printer should be above Ganti Cabang');
    expect(branchY < otaY, isTrue, reason: 'Ganti Cabang should be above OTA update');
    expect(otaY < switchUserY, isTrue, reason: 'OTA update should be above Switch Cashier');
    expect(switchUserY < logoutY, isTrue, reason: 'Switch Cashier should be above Logout');
    expect(logoutY < cancelY, isTrue, reason: 'Logout should be above Batal');

    // Tap Batal and verify sheet closes smoothly
    await tester.tap(cancelAction);
    await tester.pumpAndSettle();

    expect(find.text('Kelola Shift & Kas Drawer'), findsNothing);
  });
}
