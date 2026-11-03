// @req FSD-11, BR-15

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/printing/receipt_builder.dart';
import 'package:mobile/core/time/trusted_clock.dart';
import 'package:mobile/core/time/wib_time.dart';

void main() {
  group('WIB Timezone Compliance Tests (FSD-11, BR-15)', () {
    test('WibTime correctly maps UTC moments to UTC+7 WIB', () {
      final utcInstant = DateTime.utc(2026, 11, 2, 12, 30, 0); // 12:30 UTC
      final wib = WibTime.toWib(utcInstant);

      expect(wib.year, equals(2026));
      expect(wib.month, equals(11));
      expect(wib.day, equals(2));
      expect(wib.hour, equals(19)); // 12 + 7 = 19
      expect(wib.minute, equals(30));
    });

    test('WibTime formats ISO strings with explicit +07:00 offset', () {
      final utcInstant = DateTime.utc(2026, 11, 2, 12, 30, 0);
      final iso = WibTime.toIso8601String(utcInstant);

      expect(iso, equals('2026-11-02T19:30:00+07:00'));
    });

    test('WibTime resolves business date in WIB correctly across midnight', () {
      // 17:30 UTC = 00:30 WIB on the NEXT calendar day
      final midnightCrossingUtc = DateTime.utc(2026, 11, 2, 17, 30, 0);
      final businessDate = WibTime.toBusinessDate(midnightCrossingUtc);

      expect(businessDate, equals('2026-11-03'));
    });

    test('WibTime parses both +07:00 offset and Z formats identically to WIB', () {
      final wibInput = '2026-11-02T19:30:00+07:00';
      final utcInput = '2026-11-02T12:30:00.000000Z';

      final dtWib = WibTime.parse(wibInput);
      final dtUtc = WibTime.parse(utcInput);

      expect(WibTime.toWib(dtWib).hour, equals(19));
      expect(WibTime.toWib(dtUtc).hour, equals(19));
      expect(WibTime.format(dtWib), equals(WibTime.format(dtUtc)));
      expect(WibTime.format(dtWib), equals('02/11/2026 19:30'));
    });

    test('TrustedClock advances monotonic business time in WIB', () {
      final clock = TrustedClock();
      final serverTime = DateTime.parse('2026-11-02T19:00:00+07:00');
      clock.syncWithServer(serverTime);

      final nowWib = clock.nowWib;
      expect(nowWib.hour, equals(19));
      expect(clock.nowIso, contains('+07:00'));
      expect(clock.nowIso, contains('19:00:00'));
    });

    test('ReceiptBuilder outputs formatted time with WIB indicator matching 24h format', () {
      final transactionTime = DateTime.utc(2026, 11, 2, 12, 45, 0); // 19:45 WIB
      final receiptText = ReceiptBuilder.buildCustomerReceipt(
        branchName: 'Hiroshima Cikini',
        branchAddress: 'Jl. Cikini Raya No. 45',
        branchPhone: '081234567890',
        orderNo: 'CIK-POS-20261102-0001',
        tableNo: '05',
        orderTypeName: 'Dine In',
        cashierName: 'Budi',
        transactionTime: transactionTime,
        items: [
          {'name': 'Spicy Ramen', 'qty': 1, 'price': 35000, 'subtotal': 35000},
        ],
        subtotal: 35000,
        totalDiscount: 0,
        serviceChargeAmount: 0,
        taxAmount: 3850,
        roundingAmount: 0,
        totalAmount: 38850,
        payments: [
          {'method': 'QRIS', 'amount': 38850},
        ],
        changeAmount: 0,
      );

      expect(receiptText, contains('Waktu     : 02/11/2026 19:45 WIB'));
      expect(receiptText, isNot(contains('12:45 WIB')));
    });

    test('Kitchen Ticket outputs time in WIB format HH:mm:ss WIB', () {
      final transactionTime = DateTime.utc(2026, 11, 2, 12, 45, 30); // 19:45:30 WIB
      final kitchenTicket = ReceiptBuilder.buildKitchenTicket(
        branchName: 'Hiroshima Cikini',
        orderNo: 'CIK-POS-20261102-0001',
        orderTypeName: 'Dine In',
        tableNo: '05',
        transactionTime: transactionTime,
        items: [
          {'name': 'Spicy Ramen', 'qty': 1},
        ],
      );

      expect(kitchenTicket, contains('Waktu : 19:45:30 WIB'));
      expect(kitchenTicket, isNot(contains('12:45:30 WIB')));
    });
  });
}
