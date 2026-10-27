import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/printing/receipt_builder.dart';

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
  });
}
