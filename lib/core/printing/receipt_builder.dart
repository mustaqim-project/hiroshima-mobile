// @req FR-POS-17, FR-PRN-01, FR-PRN-02, FR-PRN-03, FSD-14

import 'package:intl/intl.dart';

/// ReceiptBuilder creates ESC/POS byte commands or text representation for thermal printer.
/// Enforces dual-copy printing: Rangkap 1 (Customer) and Rangkap 2 (Dapur/Bar without prices).
class ReceiptBuilder {
  static final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  /// Rangkap 1: Customer Receipt (Full financial details)
  static String buildCustomerReceipt({
    required String branchName,
    required String branchAddress,
    required String branchPhone,
    required String orderNo,
    required String? tableNo,
    required String orderTypeName,
    required String cashierName,
    required DateTime transactionTime,
    required List<Map<String, dynamic>> items,
    required int subtotal,
    required int totalDiscount,
    required int serviceChargeAmount,
    required int taxAmount,
    required int roundingAmount,
    required int totalAmount,
    required List<Map<String, dynamic>> payments,
    required int changeAmount,
    bool isDuplicateCopy = false,
  }) {
    final buffer = StringBuffer();
    final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(transactionTime);

    buffer.writeln('================================');
    buffer.writeln('        $branchName        ');
    buffer.writeln('  $branchAddress  ');
    buffer.writeln('        Telp: $branchPhone        ');
    buffer.writeln('================================');
    buffer.writeln('     *** RANGKAP 1 - CUSTOMER ***    ');
    if (isDuplicateCopy) {
      buffer.writeln('             [SALINAN]             ');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('No. Struk : $orderNo');
    buffer.writeln('Waktu     : $timeStr WIB');
    buffer.writeln('Kasir     : $cashierName');
    buffer.writeln('Tipe      : $orderTypeName');
    if (tableNo != null && tableNo.isNotEmpty) {
      buffer.writeln('Meja      : $tableNo');
    }
    buffer.writeln('--------------------------------');

    for (final item in items) {
      final name = item['name'] as String;
      final qty = item['qty'] as int;
      final price = item['price'] as int;
      final itemSubtotal = qty * price;

      buffer.writeln(name);
      buffer.writeln('  ${qty}x ${_currencyFormat.format(price).padRight(12)} ${_currencyFormat.format(itemSubtotal).padLeft(12)}');

      final modifiers = item['modifiers'] as List<dynamic>?;
      if (modifiers != null && modifiers.isNotEmpty) {
        for (final mod in modifiers) {
          buffer.writeln('  + ${mod['name']} (${_currencyFormat.format(mod['price'])})');
        }
      }
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('Subtotal      : ${_currencyFormat.format(subtotal).padLeft(14)}');

    if (totalDiscount > 0) {
      buffer.writeln('Diskon        : -${_currencyFormat.format(totalDiscount).padLeft(13)}');
    }

    if (serviceChargeAmount > 0) {
      buffer.writeln('Service       : ${_currencyFormat.format(serviceChargeAmount).padLeft(14)}');
    }

    buffer.writeln('Pajak (PB1)   : ${_currencyFormat.format(taxAmount).padLeft(14)}');

    if (roundingAmount != 0) {
      final sign = roundingAmount > 0 ? '+' : '-';
      buffer.writeln('Pembulatan    : $sign${_currencyFormat.format(roundingAmount.abs()).padLeft(13)}');
    }

    buffer.writeln('================================');
    buffer.writeln('TOTAL BAYAR   : ${_currencyFormat.format(totalAmount).padLeft(14)}');
    buffer.writeln('================================');

    for (final p in payments) {
      final method = p['method'] as String;
      final amount = p['amount'] as int;
      buffer.writeln('${method.padRight(16)}: ${_currencyFormat.format(amount).padLeft(14)}');
    }

    if (changeAmount > 0) {
      buffer.writeln('Kembalian     : ${_currencyFormat.format(changeAmount).padLeft(14)}');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('  Terima kasih atas kunjungan Anda  ');
    buffer.writeln('      Selamat menikmati hidangan      ');
    buffer.writeln('\n\n\n[CUT]\n');

    return buffer.toString();
  }

  /// Rangkap 2: Kitchen / Bar Ticket (NO PRICES, NO PAYMENTS)
  static String buildKitchenTicket({
    required String branchName,
    required String orderNo,
    required String? tableNo,
    required String orderTypeName,
    required DateTime transactionTime,
    required List<Map<String, dynamic>> items,
    String targetStation = 'DAPUR', // 'DAPUR' or 'BAR'
    bool isAdditionalItemsOnly = false,
  }) {
    final buffer = StringBuffer();
    final timeStr = DateFormat('HH:mm:ss').format(transactionTime);

    buffer.writeln('================================');
    if (isAdditionalItemsOnly) {
      buffer.writeln('      *** TIKET TAMBAHAN ***    ');
    } else {
      buffer.writeln('    *** RANGKAP 2 - $targetStation ***   ');
    }
    buffer.writeln('================================');
    buffer.writeln('Order : $orderNo');
    buffer.writeln('Waktu : $timeStr WIB');
    buffer.writeln('Tipe  : $orderTypeName');
    if (tableNo != null && tableNo.isNotEmpty) {
      buffer.writeln('MEJA  : >> $tableNo <<');
    }
    buffer.writeln('--------------------------------');

    for (final item in items) {
      final name = item['name'] as String;
      final qty = item['qty'] as int;
      buffer.writeln('${qty}x  $name');

      final notes = item['notes'] as String?;
      if (notes != null && notes.isNotEmpty) {
        buffer.writeln('    Catatan: $notes');
      }

      final modifiers = item['modifiers'] as List<dynamic>?;
      if (modifiers != null && modifiers.isNotEmpty) {
        for (final mod in modifiers) {
          buffer.writeln('    + ${mod['name']}');
        }
      }
    }

    buffer.writeln('================================');
    buffer.writeln('\n\n\n[CUT]\n');

    return buffer.toString();
  }
}
