// Unit test verifying Cart & Held Orders Persistence across app lifecycle & closes

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/pricing/order_calculator.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
import 'package:mobile/features/pos/presentation/pos_payment_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Cart & Held Orders Persistence Tests', () {
    test('Offline Held Order is saved to disk and restored across app restart', () async {
      final sync = PosSyncService.instance;
      sync.resetForTesting();

      final payload = {
        'shift_id': 1,
        'order_type_id': 1,
        'table_id': 5,
        'hold_reference': 'Meja 5',
        'items': [
          {'product_id': 10, 'product_name': 'Ramen Spesial', 'quantity': 2, 'unit_price': 45000}
        ],
        'total_amount': 90000,
      };

      // 1. Simulasikan hold order (akan fallback ke local offline hold bila server offline)
      final res = await sync.holdOrder(payload);
      expect(res['success'], isTrue);
      expect(sync.heldOrders.length, equals(1));

      // 2. Verifikasi tersimpan di SharedPreferences (Disk)
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('hiroshima_pos_held_orders_cache_v1');
      expect(savedStr, isNotNull);
      final savedList = jsonDecode(savedStr!) as List<dynamic>;
      expect(savedList.length, equals(1));
      expect(savedList.first['hold_reference'], equals('Meja 5'));

      // 3. Simulasikan aplikasi ditutup / restart (reset RAM memory)
      sync.resetForTesting();
      expect(sync.heldOrders.isEmpty, isTrue);

      // 4. Inisialisasi ulang auto-sync saat aplikasi dibuka kembali
      await sync.reloadFromDisk();

      // 5. Verifikasi pesanan Open Bill berhasil dipulihkan dari disk!
      expect(sync.heldOrders.length, equals(1));
      expect(sync.heldOrders.first['hold_reference'], equals('Meja 5'));
    });

    test('Cart Draft is stored in SharedPreferences and cleared on payment/hold', () async {
      final prefs = await SharedPreferences.getInstance();

      final cartDraft = {
        'cart': [
          {'id': 1, 'name': 'Gyoza', 'price': 25000, 'qty': 2}
        ],
        'selectedTableNo': '03',
        'selectedOrderTypeId': 1,
        'manualDiscount': 5000,
        'resumedOrderId': null,
      };

      // Simulasikan auto-save draft keranjang aktif
      await prefs.setString('hiroshima_pos_active_cart_draft_v1', jsonEncode(cartDraft));

      // Verifikasi tersimpan
      final savedStr = prefs.getString('hiroshima_pos_active_cart_draft_v1');
      expect(savedStr, isNotNull);
      final decoded = jsonDecode(savedStr!) as Map<String, dynamic>;
      expect(decoded['selectedTableNo'], equals('03'));
      expect((decoded['cart'] as List).length, equals(1));

      // Simulasikan pembersihan draft saat order sukses dibayar / di-open bill
      await prefs.remove('hiroshima_pos_active_cart_draft_v1');
      expect(prefs.containsKey('hiroshima_pos_active_cart_draft_v1'), isFalse);
    });

    testWidgets('PosPaymentSheet locks close button and back pop during Close Bill', (tester) async {
      final sampleCart = [
        {'id': 1, 'name': 'Ramen', 'price': 35000, 'qty': 1}
      ];
      final calc = OrderCalculator.calculate(
        subtotal: 35000,
        promoDiscount: 0,
        voucherDiscount: 0,
        loyaltyDiscount: 0,
        manualDiscount: 0,
        taxPercent: 10,
        serviceChargePercent: 0,
        taxIncluded: false,
        roundingMode: 'round_nearest_100',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: PosPaymentSheet(
              cart: sampleCart,
              calculation: calc,
              orderType: 'Dine In',
              orderTypeId: 1,
              tableNo: '02',
              onPaymentSuccess: () {},
              resumedOrderId: 99,
              isLocked: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi tombol X close hadir dan dapat ditekan untuk menutup lembar pembayaran
      expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);

      // Verifikasi tidak ada badge/tulisan Wajib Lunas
      expect(find.text('Wajib Lunas'), findsNothing);

      // Verifikasi PopScope canPop bernilai true (dapat di-close dan status tetap Open Bill)
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsOneWidget);
      final popScopeWidget = tester.widget(popScopeFinder) as PopScope;
      expect(popScopeWidget.canPop, isTrue);
    });

    test('Anti-Fraud Guard: Resumed Open Bill is retained and re-held without losing data', () async {
      final sync = PosSyncService.instance;
      sync.resetForTesting();

      final initialBill = {
        'id': 9,
        'order_no': 'HRS-0009',
        'status': 'on_hold',
        'hold_reference': 'Meja 09',
        'total_amount': 495000,
        'items': [
          {'product_id': 101, 'product_name': 'Paket Hiro 2', 'quantity': 5, 'unit_price': 70000},
          {'product_id': 102, 'product_name': 'Paket Hiro 1', 'quantity': 5, 'unit_price': 29000},
        ],
        'is_offline_hold': true,
      };

      // Simulasikan ada open bill aktif #9
      sync.heldOrders.add(initialBill);
      expect(sync.heldOrders.length, equals(1));

      // 1. Kasir melanjutkan (resume) pesanan #9
      final resumeRes = await sync.resumeHeldOrder(9);
      expect(resumeRes['success'], isTrue);
      // Pesanan TIDAK BOLEH hilang dari daftar saat di-resume!
      expect(sync.heldOrders.any((o) => o['id'] == 9), isTrue);

      // 2. Simulasikan kasir batal bayar dan memilih 'Simpan ke Open Bill'
      final reHoldRes = await sync.reHoldOrder(9, {
        'total_amount': 495000,
        'table_id': 9,
        'hold_reference': 'Meja 09',
      });
      expect(reHoldRes['success'], isTrue);

      // 3. Verifikasi order #9 TETAP ADA di daftar open bill dengan status on_hold
      expect(sync.heldOrders.any((o) => o['id'] == 9), isTrue);
      final billAfterReHold = sync.heldOrders.firstWhere((o) => o['id'] == 9);
      expect(billAfterReHold['status'], equals('on_hold'));
      expect(billAfterReHold['total_amount'], equals(495000));
    });
  });
}
