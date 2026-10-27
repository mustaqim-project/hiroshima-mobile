// @req FR-POS-01, FR-POS-01a, FR-POS-13, FSD-09
// Apple HIG iOS-Look Close Shift Report Preview Dialog & Thermal Printing

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/printing/receipt_builder.dart';
import '../../../core/printing/thermal_printer_service.dart';
import '../../../core/theme/ios_components.dart';
import '../../../core/theme/ios_tokens.dart';

class PosCloseShiftReportDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final bool autoPrint;

  const PosCloseShiftReportDialog({
    super.key,
    required this.report,
    this.autoPrint = true,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> report,
    bool autoPrint = true,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PosCloseShiftReportDialog(
        report: report,
        autoPrint: autoPrint,
      ),
    );
  }

  @override
  State<PosCloseShiftReportDialog> createState() => _PosCloseShiftReportDialogState();
}

class _PosCloseShiftReportDialogState extends State<PosCloseShiftReportDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  bool _isPrinting = false;
  String? _printerStatusMessage;
  bool _printerStatusSuccess = true;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrint && ThermalPrinterService.instance.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePrint();
      });
    }
  }

  Future<void> _handlePrint() async {
    setState(() {
      _isPrinting = true;
      _printerStatusMessage = 'Mengirim perintah cetak ke printer Bluetooth...';
      _printerStatusSuccess = true;
    });

    final res = await ThermalPrinterService.instance.printCloseShiftReport(widget.report);

    if (!mounted) return;
    setState(() {
      _isPrinting = false;
      _printerStatusMessage = res.message;
      _printerStatusSuccess = res.success;
    });

    if (res.success) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _handleCopyText() {
    final text = ReceiptBuilder.buildCloseShiftReceipt(report: widget.report);
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    setState(() {
      _printerStatusMessage = 'Teks laporan berhasil disalin ke clipboard!';
      _printerStatusSuccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shiftInfo = (widget.report['shift_info'] as Map<String, dynamic>?) ?? {};
    final menuSummary = (widget.report['menu_summary'] as Map<String, dynamic>?) ?? {};
    final menuItems = (menuSummary['items'] as List<dynamic>?) ?? [];
    final menuTotal = (menuSummary['total'] as Map<String, dynamic>?) ?? {};
    final txSummary = (widget.report['transaction_summary'] as Map<String, dynamic>?) ?? {};
    final payments = (txSummary['payments_by_method'] as List<dynamic>?) ?? [];
    final cashRec = (txSummary['cash_reconciliation'] as Map<String, dynamic>?) ?? {};

    final company = (shiftInfo['company_name'] as String?) ?? 'Hiroshima Japanese Street Food';
    final branchName = (shiftInfo['branch_name'] as String?) ?? 'Hiroshima';
    final cashier = (shiftInfo['cashier_name'] as String?) ?? (shiftInfo['cashier_username'] as String?) ?? 'Kasir';
    final shiftId = shiftInfo['shift_id']?.toString() ?? '-';
    final closeType = (shiftInfo['close_type'] ?? 'manual') == 'auto' ? 'Otomatis (23 Jam)' : 'Manual (Kasir)';

    DateTime? openedAt = shiftInfo['opened_at'] != null ? DateTime.tryParse(shiftInfo['opened_at'].toString()) : null;
    DateTime? closedAt = shiftInfo['closed_at'] != null ? DateTime.tryParse(shiftInfo['closed_at'].toString()) : null;
    DateTime printedAt = shiftInfo['printed_at'] != null
        ? (DateTime.tryParse(shiftInfo['printed_at'].toString()) ?? DateTime.now())
        : DateTime.now();

    final txCount = txSummary['completed_transaction_count'] ?? 0;
    final gross = (txSummary['gross_sales'] as num?)?.toInt() ?? 0;
    final discount = (txSummary['total_discount'] as num?)?.toInt() ?? 0;
    final service = (txSummary['service_charge_amount'] as num?)?.toInt() ?? 0;
    final tax = (txSummary['tax_amount'] as num?)?.toInt() ?? 0;
    final rounding = (txSummary['rounding_amount'] as num?)?.toInt() ?? 0;
    final netSales = (txSummary['net_sales'] as num?)?.toInt() ?? 0;

    final startCash = (cashRec['starting_cash'] as num?)?.toInt() ?? 0;
    final expCash = (cashRec['expected_cash'] as num?)?.toInt() ?? 0;
    final actCash = (cashRec['actual_cash'] as num?)?.toInt();
    final diff = (cashRec['cash_difference'] as num?)?.toInt();

    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 580, maxHeight: 780),
      decoration: BoxDecoration(
        color: IOSColors.groupedBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(IOSRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: IOSSpacing.md, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grabber Handle
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey3.resolveFrom(context),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(CupertinoIcons.doc_text_fill, color: Color(0xFFDC2626), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Laporan Tutup Shift',
                            style: IOSText.title3.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Shift #$shiftId • $branchName',
                            style: IOSText.caption1.copyWith(
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Selesai',
                      style: IOSText.headline.copyWith(
                        color: IOSColors.accent.resolveFrom(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Status message (e.g. Printer status)
              if (_printerStatusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _printerStatusSuccess
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                        : (isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _printerStatusSuccess
                          ? (isDark ? const Color(0xFF047857) : const Color(0xFF86EFAC))
                          : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5)),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _printerStatusSuccess
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.exclamationmark_triangle_fill,
                        size: 16,
                        color: _printerStatusSuccess
                            ? (_isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534))
                            : (_isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _printerStatusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _printerStatusSuccess
                                ? (_isDark ? const Color(0xFFD1FAE5) : const Color(0xFF065F46))
                                : (_isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Scrollable Thermal Receipt Preview Card
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(IOSRadius.card),
                    border: Border.all(
                      color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.6),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(IOSRadius.card),
                    child: CupertinoScrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Receipt
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    company.toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Outlet: $branchName',
                                    style: TextStyle(
                                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'LAPORAN TUTUP SHIFT',
                                      style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildDashedLine(context),
                            const SizedBox(height: 10),

                            // Informasi Shift
                            _buildReceiptRow('Shift ID', '#$shiftId', isBold: true),
                            _buildReceiptRow('Kasir Bertugas', cashier),
                            _buildReceiptRow('Waktu Buka', openedAt != null ? '${_dateFormat.format(openedAt)} WIB' : '-'),
                            _buildReceiptRow('Waktu Tutup', closedAt != null ? '${_dateFormat.format(closedAt)} WIB' : '-'),
                            _buildReceiptRow('Waktu Cetak', '${_dateFormat.format(printedAt)} WIB'),
                            _buildReceiptRow('Tipe Penutupan', closeType),
                            const SizedBox(height: 10),
                            _buildDashedLine(context),
                            const SizedBox(height: 12),

                            // A. REKAP PENJUALAN PER MENU
                            Text(
                              'A. REKAP PENJUALAN PER MENU',
                              style: IOSText.caption1.copyWith(
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),

                            if (menuItems.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Tidak ada transaksi penjualan selesai pada shift ini.',
                                  style: IOSText.caption1.copyWith(fontStyle: FontStyle.italic),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: menuItems.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 6),
                                itemBuilder: (ctx, idx) {
                                  final item = menuItems[idx];
                                  final no = item['no'] ?? (idx + 1);
                                  final menu = (item['menu'] as String?) ?? 'Menu';
                                  final qty = (item['total_qty'] as num?)?.toInt() ?? 0;
                                  final sales = (item['total_sales'] as num?)?.toInt() ?? 0;

                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        child: Text('$no.', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(menu, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                            Text('$qty item terjual',
                                                style: TextStyle(
                                                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _currency.format(sales),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ],
                                  );
                                },
                              ),

                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TOTAL (${menuTotal['total_qty'] ?? 0} item)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    _currency.format((menuTotal['total_sales'] as num?)?.toInt() ?? 0),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildDashedLine(context),
                            const SizedBox(height: 12),

                            // B. RINGKASAN TRANSAKSI
                            Text(
                              'B. RINGKASAN TRANSAKSI',
                              style: IOSText.caption1.copyWith(
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildReceiptRow('Jumlah Transaksi Selesai', '$txCount transaksi'),
                            _buildReceiptRow('Penjualan Kotor', _currency.format(gross)),
                            if (discount > 0)
                              _buildReceiptRow('Total Diskon', '-${_currency.format(discount)}', valueColor: const Color(0xFFDC2626)),
                            if (service > 0)
                              _buildReceiptRow('Service Charge', _currency.format(service)),
                            if (tax > 0)
                              _buildReceiptRow('Pajak (PB1)', _currency.format(tax)),
                            if (rounding != 0)
                              _buildReceiptRow(
                                'Pembulatan',
                                '${rounding > 0 ? "+" : "-"}${_currency.format(rounding.abs())}',
                              ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'PENJUALAN BERSIH',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFDC2626)),
                                  ),
                                  Text(
                                    _currency.format(netSales),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildDashedLine(context),
                            const SizedBox(height: 12),

                            // C. METODE PEMBAYARAN
                            Text(
                              'C. RINCIAN PEMBAYARAN',
                              style: IOSText.caption1.copyWith(
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (payments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text('Tidak ada pembayaran.', style: IOSText.caption1.copyWith(fontStyle: FontStyle.italic)),
                              )
                            else
                              ...payments.map((p) {
                                final name = (p['name'] as String?) ?? 'Metode';
                                final pCount = p['tx_count'] ?? 0;
                                final pTotal = (p['total_amount'] as num?)?.toInt() ?? 0;
                                return _buildReceiptRow('$name (${pCount}x)', _currency.format(pTotal));
                              }),

                            const SizedBox(height: 14),
                            _buildDashedLine(context),
                            const SizedBox(height: 12),

                            // D. REKONSILIASI KAS LACI
                            Text(
                              'D. REKONSILIASI KAS LACI',
                              style: IOSText.caption1.copyWith(
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildReceiptRow('Modal Kas Awal', _currency.format(startCash)),
                            _buildReceiptRow('Ekspektasi Kas Laci', _currency.format(expCash), isBold: true),
                            if (actCash != null)
                              _buildReceiptRow('Kas Fisik Aktual', _currency.format(actCash), isBold: true),
                            if (diff != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Selisih Kas (${diff == 0 ? "Pas" : (diff < 0 ? "Kurang" : "Lebih")})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: diff == 0
                                          ? const Color(0xFF166534)
                                          : (diff < 0 ? const Color(0xFFDC2626) : const Color(0xFF92400E)),
                                    ),
                                  ),
                                  Text(
                                    '${diff > 0 ? "+" : (diff < 0 ? "-" : "")}${_currency.format(diff.abs())}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: diff == 0
                                          ? const Color(0xFF166534)
                                          : (diff < 0 ? const Color(0xFFDC2626) : const Color(0xFF92400E)),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 20),
                            _buildDashedLine(context),
                            const SizedBox(height: 16),

                            // Signature area
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text('Kasir Bertugas,', style: IOSText.caption1),
                                    const SizedBox(height: 40),
                                    Text('($cashier)', style: IOSText.subhead.copyWith(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('Supervisor,', style: IOSText.caption1),
                                    const SizedBox(height: 40),
                                    Text('( ____________ )', style: IOSText.subhead.copyWith(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: IOSButton(
                      label: 'Cetak Laporan Tutup Shift',
                      variant: IOSButtonVariant.filled,
                      icon: CupertinoIcons.printer_fill,
                      isLoading: _isPrinting,
                      onPressed: _isPrinting ? null : _handlePrint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(IOSRadius.button),
                    onPressed: _handleCopyText,
                    child: const Icon(CupertinoIcons.doc_on_clipboard, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isBold ? CupertinoColors.label.resolveFrom(context) : CupertinoColors.secondaryLabel.resolveFrom(context),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
