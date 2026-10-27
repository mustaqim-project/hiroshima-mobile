// @req FR-POS-17, FR-PRN-01, FR-PRN-02, FR-PRN-03, FSD-14

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/printing/receipt_builder.dart';

void main() {
  group('ReceiptBuilder Dual-Copy Printing Tests', () {
    final sampleItems = [
      {'name': 'Ramen Spesial', 'qty': 2, 'price': 45000, 'notes': 'Kurangi cabai'},
      {'name': 'Ocha Dingin', 'qty': 1, 'price': 10000, 'notes': 'Less ice'},
    ];

    test('Rangkap 1 (Customer) contains prices, taxes, and payment info', () {
      final receipt = ReceiptBuilder.buildCustomerReceipt(
        branchName: 'Hiroshima Pusat',
        branchAddress: 'Jl. Sudirman 88',
        branchPhone: '021-1234',
        orderNo: 'HRS01-POS-001',
        tableNo: 'Meja 05',
        orderTypeName: 'Dine In',
        cashierName: 'Siti',
        transactionTime: DateTime.parse('2026-10-23 12:30:00'),
        items: sampleItems,
        subtotal: 100000,
        totalDiscount: 10000,
        serviceChargeAmount: 0,
        taxAmount: 9900,
        roundingAmount: 0,
        totalAmount: 99900,
        payments: [{'method': 'Tunai', 'amount': 100000}],
        changeAmount: 100,
      );

      expect(receipt, contains('RANGKAP 1 - CUSTOMER'));
      expect(receipt, contains('TOTAL BAYAR'));
      expect(receipt, contains('Pajak (PB1)'));
      expect(receipt, contains('Tunai'));
      expect(receipt, contains('Kembalian'));
      expect(receipt, contains('Meja 05'));
    });

    test('Rangkap 2 (Dapur) omits all prices and payment information', () {
      final kitchenTicket = ReceiptBuilder.buildKitchenTicket(
        branchName: 'Hiroshima Pusat',
        orderNo: 'HRS01-POS-001',
        tableNo: 'Meja 05',
        orderTypeName: 'Dine In',
        transactionTime: DateTime.parse('2026-10-23 12:30:00'),
        items: sampleItems,
        targetStation: 'DAPUR',
      );

      expect(kitchenTicket, contains('RANGKAP 2 - DAPUR'));
      expect(kitchenTicket, contains('2x  Ramen Spesial'));
      expect(kitchenTicket, contains('Catatan: Kurangi cabai'));
      expect(kitchenTicket, contains('MEJA  : >> Meja 05 <<'));

      // STRICT INVARIANT: Kitchen copy must never leak prices or payment info
      expect(kitchenTicket, isNot(contains('Rp ')));
      expect(kitchenTicket, isNot(contains('TOTAL')));
      expect(kitchenTicket, isNot(contains('Tunai')));
      expect(kitchenTicket, isNot(contains('Kembalian')));
    });
  });
}
