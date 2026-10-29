// @req FR-POS-17, FR-PRN-01, FR-PRN-02, FR-PRN-03, FSD-14

import 'package:intl/intl.dart';

/// ReceiptBuilder creates ESC/POS byte commands or text representation for thermal printer.
/// Enforces dual-copy printing: Rangkap 1 (Customer) and Rangkap 2 (Dapur/Bar without prices).
class ReceiptBuilder {
  static final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  /// Rangkap 1: Customer Receipt (Struk Resmi Pembayaran LUNAS - Full financial details)
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

    // 1. LOGO LANDSCAPE HIROSHIMA
    buffer.writeln('================================');
    buffer.writeln('       H I R O S H I M A        ');
    buffer.writeln('  JAPANESE STREET FOOD & SUSHI  ');
    buffer.writeln('================================');

    // 2. INFORMASI CABANG & ALAMAT
    buffer.writeln('Cabang    : $branchName');
    if (branchAddress.isNotEmpty) {
      buffer.writeln('Alamat    : $branchAddress');
    }
    if (branchPhone.isNotEmpty) {
      buffer.writeln('No. Telp  : $branchPhone');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('  *** STRUK PEMBAYARAN LUNAS ***  ');
    if (isDuplicateCopy) {
      buffer.writeln('             [SALINAN]             ');
    }
    buffer.writeln('--------------------------------');

    // 3. INFORMASI STRUK & METADATA
    buffer.writeln('No. Struk : $orderNo');
    buffer.writeln('Waktu     : $timeStr WIB');
    buffer.writeln('Kasir     : $cashierName');
    buffer.writeln('Tipe      : $orderTypeName');
    if (tableNo != null && tableNo.isNotEmpty) {
      buffer.writeln('Meja      : $tableNo');
    }
    buffer.writeln('--------------------------------');

    // 4. INFORMASI ORDER (ITEMS & FINANCIAL SUMMARY)
    for (final item in items) {
      final name = item['name'] as String;
      final qty = item['qty'] as int;
      final price = item['price'] as int;
      final itemSubtotal = qty * price;

      buffer.writeln(name);
      buffer.writeln('  ${qty}x ${_currencyFormat.format(price).padRight(12)} ${_currencyFormat.format(itemSubtotal).padLeft(12)}');

      final notes = item['notes'] as String?;
      if (notes != null && notes.isNotEmpty) {
        buffer.writeln('  * Catatan: $notes');
      }

      final modifiers = item['modifiers'] as List<dynamic>?;
      if (modifiers != null && modifiers.isNotEmpty) {
        for (final mod in modifiers) {
          final modPrice = (mod['price'] as num?)?.toInt() ?? 0;
          buffer.writeln('  + ${mod['name']} (${_currencyFormat.format(modPrice)})');
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

    // 5. JENIS PEMBAYARAN
    for (final p in payments) {
      final method = p['method'] as String;
      final amount = p['amount'] as int;
      buffer.writeln('${method.padRight(16)}: ${_currencyFormat.format(amount).padLeft(14)}');
    }

    if (changeAmount > 0) {
      buffer.writeln('Kembalian     : ${_currencyFormat.format(changeAmount).padLeft(14)}');
    }

    // 6. FOOTER
    buffer.writeln('--------------------------------');
    buffer.writeln('  Terima kasih atas kunjungan Anda  ');
    buffer.writeln('    Selamat menikmati hidangan!     ');
    buffer.writeln('      Instagram: @hiroshima.id      ');
    buffer.writeln('\n\n\n[CUT]\n');

    return buffer.toString();
  }

  /// Rangkap 2: Kitchen / Bar Ticket (NO PRICES, NO FINANCIAL DATA - ANTI FRAUD ENFORCED)
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
      buffer.writeln('   *** TIKET TAMBAHAN - $targetStation ***   ');
    } else {
      buffer.writeln('    *** TIKET PESANAN $targetStation ***   ');
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
          // Zero price leak for kitchen
          buffer.writeln('    + ${mod['name']}');
        }
      }
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('  * KHUSUS $targetStation - BUKAN STRUK BAYAR *  ');
    buffer.writeln('  * DILARANG SEBAGAI ALAT TRANSAKSI *  ');
    buffer.writeln('================================');
    buffer.writeln('\n\n\n[CUT]\n');

    return buffer.toString();
  }

  /// Close Shift Report (Laporan Penjualan & Rekonsiliasi Kas Shift)
  /// Complies with Section 5 of Specification:
  /// A. Rekap Penjualan per Menu (No, Menu, Qty, Total Penjualan, TOTAL Baris Bawah)
  /// B. Ringkasan Transaksi (Tx Selesai, Kotor, Diskon, Pajak/Service, Bersih, Breakdown Metode, Kas Laci)
  /// C. Informasi Shift (Usaha, Outlet, Kasir, ID, Buka, Tutup, Cetak, Jenis Tutup)
  static String buildCloseShiftReceipt({
    required Map<String, dynamic> report,
  }) {
    final buffer = StringBuffer();
    final shiftInfo = (report['shift_info'] as Map<String, dynamic>?) ?? {};
    final menuSummary = (report['menu_summary'] as Map<String, dynamic>?) ?? {};
    final menuItems = (menuSummary['items'] as List<dynamic>?) ?? [];
    final menuTotal = (menuSummary['total'] as Map<String, dynamic>?) ?? {};
    final txSummary = (report['transaction_summary'] as Map<String, dynamic>?) ?? {};
    final payments = (txSummary['payments_by_method'] as List<dynamic>?) ?? [];
    final cashRec = (txSummary['cash_reconciliation'] as Map<String, dynamic>?) ?? {};

    final company = (shiftInfo['company_name'] as String?) ?? 'Hiroshima Japanese Street Food';
    final branchName = (shiftInfo['branch_name'] as String?) ?? 'Hiroshima';
    final cashier = (shiftInfo['cashier_name'] as String?) ?? (shiftInfo['cashier_username'] as String?) ?? 'Kasir';
    final shiftId = shiftInfo['shift_id']?.toString() ?? '-';
    final closeType = (shiftInfo['close_type'] ?? 'manual') == 'auto' ? 'OTOMATIS (23 JAM)' : 'MANUAL (KASIR)';

    DateTime? openedAt = shiftInfo['opened_at'] != null ? DateTime.tryParse(shiftInfo['opened_at'].toString()) : null;
    DateTime? closedAt = shiftInfo['closed_at'] != null ? DateTime.tryParse(shiftInfo['closed_at'].toString()) : null;
    DateTime printedAt = shiftInfo['printed_at'] != null ? (DateTime.tryParse(shiftInfo['printed_at'].toString()) ?? DateTime.now()) : DateTime.now();

    final df = DateFormat('dd/MM/yyyy HH:mm');

    buffer.writeln('================================');
    buffer.writeln('   $company   ');
    buffer.writeln('   Outlet: $branchName   ');
    buffer.writeln('================================');
    final isOpen = (shiftInfo['status'] == 'open') || (closedAt == null);
    buffer.writeln(isOpen ? '*** RINGKASAN SHIFT (X-REPORT) ***' : '*** LAPORAN TUTUP SHIFT (CLOSE) ***');
    buffer.writeln('--------------------------------');
    buffer.writeln('Shift ID   : #$shiftId');
    buffer.writeln('Kasir      : $cashier');
    buffer.writeln('Waktu Buka : ${openedAt != null ? df.format(openedAt) : "-"} WIB');
    if (isOpen) {
      buffer.writeln('Status     : SHIFT BERJALAN');
    } else {
      buffer.writeln('Waktu Tutup: ${closedAt != null ? df.format(closedAt) : "-"} WIB');
    }
    buffer.writeln('Waktu Cetak: ${df.format(printedAt)} WIB');
    if (!isOpen) {
      buffer.writeln('Tipe Tutup : $closeType');
    }
    buffer.writeln('================================');
    buffer.writeln('    REKAP PENJUALAN PER MENU    ');
    buffer.writeln('--------------------------------');

    if (menuItems.isEmpty) {
      buffer.writeln(' (Tidak ada transaksi selesai)  ');
    } else {
      for (final item in menuItems) {
        final no = item['no'] ?? '';
        final menu = (item['menu'] as String?) ?? 'Item';
        final qty = (item['total_qty'] as num?)?.toInt() ?? 0;
        final sales = (item['total_sales'] as num?)?.toInt() ?? 0;
        buffer.writeln('$no. $menu');
        buffer.writeln('    ${qty}x ${''.padRight(4)} ${_currencyFormat.format(sales).padLeft(16)}');
      }
    }

    buffer.writeln('--------------------------------');
    final totalQty = (menuTotal['total_qty'] as num?)?.toInt() ?? 0;
    final totalSales = (menuTotal['total_sales'] as num?)?.toInt() ?? 0;
    buffer.writeln('TOTAL MENU : $totalQty item');
    buffer.writeln('TOTAL NILAI: ${_currencyFormat.format(totalSales).padLeft(16)}');
    buffer.writeln('================================');
    buffer.writeln('      RINGKASAN TRANSAKSI       ');
    buffer.writeln('--------------------------------');

    final txCount = txSummary['completed_transaction_count'] ?? 0;
    final gross = (txSummary['gross_sales'] as num?)?.toInt() ?? 0;
    final discount = (txSummary['total_discount'] as num?)?.toInt() ?? 0;
    final service = (txSummary['service_charge_amount'] as num?)?.toInt() ?? 0;
    final tax = (txSummary['tax_amount'] as num?)?.toInt() ?? 0;
    final rounding = (txSummary['rounding_amount'] as num?)?.toInt() ?? 0;
    final netSales = (txSummary['net_sales'] as num?)?.toInt() ?? 0;

    buffer.writeln('Trx Selesai   : $txCount');
    buffer.writeln('Penj. Kotor   : ${_currencyFormat.format(gross).padLeft(16)}');
    if (discount > 0) {
      buffer.writeln('Total Diskon  : -${_currencyFormat.format(discount).padLeft(15)}');
    }
    if (service > 0) {
      buffer.writeln('Service Charge: ${_currencyFormat.format(service).padLeft(16)}');
    }
    if (tax > 0) {
      buffer.writeln('Pajak (PB1)   : ${_currencyFormat.format(tax).padLeft(16)}');
    }
    if (rounding != 0) {
      final sign = rounding > 0 ? '+' : '-';
      buffer.writeln('Pembulatan    : $sign${_currencyFormat.format(rounding.abs()).padLeft(15)}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('PENJ. BERSIH  : ${_currencyFormat.format(netSales).padLeft(16)}');
    buffer.writeln('================================');
    buffer.writeln('       METODE PEMBAYARAN        ');
    buffer.writeln('--------------------------------');

    if (payments.isEmpty) {
      buffer.writeln('    (Tidak ada pembayaran)      ');
    } else {
      for (final p in payments) {
        final name = (p['name'] as String?) ?? 'Metode';
        final pCount = p['tx_count'] ?? 0;
        final pTotal = (p['total_amount'] as num?)?.toInt() ?? 0;
        buffer.writeln('$name (${pCount}x)');
        buffer.writeln('    Total     : ${_currencyFormat.format(pTotal).padLeft(16)}');
      }
    }

    buffer.writeln('================================');
    buffer.writeln('      REKONSILIASI KAS LACI     ');
    buffer.writeln('--------------------------------');

    final startCash = (cashRec['starting_cash'] as num?)?.toInt() ?? 0;
    final expCash = (cashRec['expected_cash'] as num?)?.toInt() ?? 0;
    final actCash = (cashRec['actual_cash'] as num?)?.toInt();
    final diff = (cashRec['cash_difference'] as num?)?.toInt();

    buffer.writeln('Modal Kas Awal : ${_currencyFormat.format(startCash).padLeft(15)}');
    buffer.writeln('Ekspektasi Kas : ${_currencyFormat.format(expCash).padLeft(15)}');
    if (actCash != null) {
      buffer.writeln('Kas Fisik Akt. : ${_currencyFormat.format(actCash).padLeft(15)}');
    }
    if (diff != null) {
      final diffLabel = diff == 0 ? 'Pas' : (diff < 0 ? 'Kurang' : 'Lebih');
      final sign = diff > 0 ? '+' : (diff < 0 ? '-' : '');
      buffer.writeln('Selisih Kas    : $sign${_currencyFormat.format(diff.abs()).padLeft(12)} ($diffLabel)');
    }

    buffer.writeln('================================');
    buffer.writeln('\n');
    buffer.writeln('Kasir Bertugas,       Supervisor,\n\n\n');
    buffer.writeln('( $cashier )        ( __________ )\n');
    buffer.writeln('================================');
    buffer.writeln('\n\n\n[CUT]\n');

    return buffer.toString();
  }
}

