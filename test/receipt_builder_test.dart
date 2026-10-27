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

    test('Close Shift Report receipt contains complete Sections A, B, and C', () {
      final sampleReport = {
        'shift_info': {
          'company_name': 'Hiroshima Japanese Street Food',
          'branch_name': 'Hiroshima Cilandak',
          'cashier_name': 'Budi Santoso',
          'shift_id': 42,
          'opened_at': '2026-10-27T10:00:00',
          'closed_at': '2026-10-27T22:00:00',
          'printed_at': '2026-10-27T22:01:00',
          'close_type': 'manual',
        },
        'menu_summary': {
          'items': [
            {'no': 1, 'menu': 'Tori Paitan Ramen', 'total_qty': 4, 'total_sales': 152000},
            {'no': 2, 'menu': 'Yakitori Skewers', 'total_qty': 3, 'total_sales': 75000},
          ],
          'total': {
            'total_qty': 7,
            'total_sales': 227000,
          },
        },
        'transaction_summary': {
          'completed_transaction_count': 5,
          'gross_sales': 227000,
          'total_discount': 20000,
          'tax_amount': 20700,
          'service_charge_amount': 10350,
          'rounding_amount': -50,
          'net_sales': 238000,
          'payments_by_method': [
            {'name': 'Tunai (Cash)', 'tx_count': 3, 'total_amount': 150000},
            {'name': 'QRIS', 'tx_count': 2, 'total_amount': 88000},
          ],
          'cash_reconciliation': {
            'starting_cash': 500000,
            'expected_cash': 650000,
            'actual_cash': 650000,
            'cash_difference': 0,
          },
        },
      };

      final receipt = ReceiptBuilder.buildCloseShiftReceipt(report: sampleReport);

      // Section C: Shift Info
      expect(receipt, contains('Hiroshima Japanese Street Food'));
      expect(receipt, contains('Hiroshima Cilandak'));
      expect(receipt, contains('LAPORAN TUTUP SHIFT'));
      expect(receipt, contains('Shift ID   : #42'));
      expect(receipt, contains('Kasir      : Budi Santoso'));
      expect(receipt, contains('MANUAL (KASIR)'));

      // Section A: Rekap Penjualan per Menu
      expect(receipt, contains('REKAP PENJUALAN PER MENU'));
      expect(receipt, contains('1. Tori Paitan Ramen'));
      expect(receipt, contains('4x'));
      expect(receipt, contains('2. Yakitori Skewers'));
      expect(receipt, contains('TOTAL MENU : 7 item'));

      // Section B: Ringkasan Transaksi
      expect(receipt, contains('RINGKASAN TRANSAKSI'));
      expect(receipt, contains('Trx Selesai   : 5'));
      expect(receipt, contains('Penj. Kotor'));
      expect(receipt, contains('PENJ. BERSIH'));

      // Payments & Cash Reconciliation
      expect(receipt, contains('Tunai (Cash) (3x)'));
      expect(receipt, contains('QRIS (2x)'));
      expect(receipt, contains('Modal Kas Awal'));
      expect(receipt, contains('Ekspektasi Kas'));
      expect(receipt, contains('Kas Fisik Akt.'));
      expect(receipt, contains('Selisih Kas'));
      expect(receipt, contains('(Pas)'));
    });
  });
}

