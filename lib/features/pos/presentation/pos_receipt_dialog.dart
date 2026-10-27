// @req FR-POS-17, FR-PRN-01, FR-PRN-02, FR-PRN-03, FSD-14
// Digital Bill / Struk Modal Dialog in Apple HIG Style
// Displays landscape Hiroshima logo, branch info, receipt no, order type, order items, payment details, and footer.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:intl/intl.dart';
import '../../../core/theme/ios_components.dart';
import '../../../core/theme/ios_tokens.dart';

class PosReceiptDialog extends StatelessWidget {
  final String branchName;
  final String branchAddress;
  final String branchPhone;
  final String orderNo;
  final String? tableNo;
  final String orderTypeName;
  final String cashierName;
  final DateTime transactionTime;
  final List<Map<String, dynamic>> items;
  final int subtotal;
  final int totalDiscount;
  final int serviceChargeAmount;
  final int taxAmount;
  final int roundingAmount;
  final int totalAmount;
  final String paymentMethodName;
  final int paidAmount;
  final int changeAmount;
  final String? printNotice;
  final VoidCallback onReprint;
  final VoidCallback onClose;
  final dynamic orderId;
  final bool isVoided;
  final String? voidReason;
  final Future<bool> Function(String pin, String reason)? onVoid;

  const PosReceiptDialog({
    super.key,
    required this.branchName,
    required this.branchAddress,
    required this.branchPhone,
    required this.orderNo,
    required this.tableNo,
    required this.orderTypeName,
    required this.cashierName,
    required this.transactionTime,
    required this.items,
    required this.subtotal,
    required this.totalDiscount,
    required this.serviceChargeAmount,
    required this.taxAmount,
    required this.roundingAmount,
    required this.totalAmount,
    required this.paymentMethodName,
    required this.paidAmount,
    required this.changeAmount,
    this.printNotice,
    required this.onReprint,
    required this.onClose,
    this.orderId,
    this.isVoided = false,
    this.voidReason,
    this.onVoid,
  });

  static final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static final _timeFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 440,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: IOSColors.groupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.6),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.18),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Success / Void Pill
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: isVoided
                    ? CupertinoColors.destructiveRed.withValues(alpha: 0.15)
                    : IOSColors.success.resolveFrom(context).withValues(alpha: 0.15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isVoided ? CupertinoIcons.xmark_shield_fill : CupertinoIcons.checkmark_seal_fill,
                      color: isVoided ? CupertinoColors.destructiveRed : IOSColors.success.resolveFrom(context),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isVoided ? 'TRANSAKSI DIBATALKAN (VOID)' : 'TRANSAKSI BERHASIL / STRUK PEMBAYARAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isVoided ? CupertinoColors.destructiveRed : IOSColors.success.resolveFrom(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              if (isVoided && voidReason != null && voidReason!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  color: CupertinoColors.destructiveRed.withValues(alpha: 0.08),
                  child: Text(
                    'Alasan Void: $voidReason',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: CupertinoColors.destructiveRed,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),

              // Scrollable Receipt Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. LOGO LANDSCAPE HIROSHIMA
                      Center(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/logo_horizontal.png',
                              height: 48,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Column(
                                children: [
                                  Text(
                                    'HIROSHIMA',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3,
                                      color: IOSColors.label.resolveFrom(context),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  Text(
                                    'JAPANESE STREET FOOD & SUSHI',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                      color: IOSColors.secondaryLabel.resolveFrom(context),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              branchName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: IOSColors.label.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            if (branchAddress.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  branchAddress,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: IOSColors.secondaryLabel.resolveFrom(context),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            if (branchPhone.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  'Telp: $branchPhone',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: IOSColors.secondaryLabel.resolveFrom(context),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      _buildDashedDivider(context),
                      const SizedBox(height: 10),

                      // 2. INFORMASI STRUK & ORDER TYPE
                      _buildMetaRow(context, 'No. Struk', orderNo, isBoldValue: true),
                      const SizedBox(height: 4),
                      _buildMetaRow(context, 'Waktu', '${_timeFormat.format(transactionTime)} WIB'),
                      const SizedBox(height: 4),
                      _buildMetaRow(context, 'Kasir', cashierName),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tipe Order',
                            style: TextStyle(
                              fontSize: 12,
                              color: IOSColors.secondaryLabel.resolveFrom(context),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: IOSColors.accent.resolveFrom(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tableNo != null && tableNo!.isNotEmpty
                                  ? '$orderTypeName (Meja $tableNo)'
                                  : orderTypeName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: IOSColors.accent.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      _buildDashedDivider(context),
                      const SizedBox(height: 10),

                      // 3. INFORMASI ORDER (ITEMS DETAIL)
                      Text(
                        'DETAIL PESANAN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: IOSColors.secondaryLabel.resolveFrom(context),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 6),

                      for (final item in items) ...[
                        _buildOrderItemRow(context, item),
                        const SizedBox(height: 6),
                      ],

                      const SizedBox(height: 6),
                      _buildDashedDivider(context),
                      const SizedBox(height: 8),

                      // 4. RINGKASAN FINANSIAL
                      _buildAmountRow(context, 'Subtotal', subtotal),
                      if (totalDiscount > 0)
                        _buildAmountRow(context, 'Diskon', -totalDiscount, isDiscount: true),
                      if (serviceChargeAmount > 0)
                        _buildAmountRow(context, 'Service Charge', serviceChargeAmount),
                      _buildAmountRow(context, 'Pajak (PB1 11%)', taxAmount),
                      if (roundingAmount != 0)
                        _buildAmountRow(context, 'Pembulatan', roundingAmount),

                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL BAYAR',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: IOSColors.label.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Text(
                              _currency.format(totalAmount),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: IOSColors.accent.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                      _buildDashedDivider(context),
                      const SizedBox(height: 8),

                      // 5. JENIS PEMBAYARAN
                      Text(
                        'PEMBAYARAN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: IOSColors.secondaryLabel.resolveFrom(context),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildMetaRow(context, 'Metode Bayar', paymentMethodName, isBoldValue: true),
                      const SizedBox(height: 4),
                      _buildAmountRow(context, 'Nominal Diterima', paidAmount),
                      if (changeAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kembalian',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: IOSColors.label.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Text(
                              _currency.format(changeAmount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: IOSColors.success.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),
                      _buildDashedDivider(context),
                      const SizedBox(height: 10),

                      // 6. FOOTER
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Terima kasih atas kunjungan Anda',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: IOSColors.label.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Selamat menikmati hidangan kami!',
                              style: TextStyle(
                                fontSize: 10,
                                color: IOSColors.secondaryLabel.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Instagram: @hiroshima.id',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: IOSColors.secondaryLabel.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (printNotice != null && printNotice!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            printNotice!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: IOSColors.secondaryLabel.resolveFrom(context),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                  border: Border(
                    top: BorderSide(
                      color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: IOSButton(
                            label: 'Cetak Lagi',
                            icon: CupertinoIcons.printer_fill,
                            variant: IOSButtonVariant.tinted,
                            onPressed: onReprint,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: IOSButton(
                            label: 'Selesai',
                            icon: CupertinoIcons.checkmark,
                            variant: IOSButtonVariant.filled,
                            onPressed: onClose,
                          ),
                        ),
                      ],
                    ),
                    if (!isVoided && onVoid != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          color: CupertinoColors.destructiveRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => _handlePromptVoid(context),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: CupertinoColors.destructiveRed),
                              SizedBox(width: 6),
                              Text(
                                'Batalkan / Void Transaksi Ini',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.destructiveRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePromptVoid(BuildContext context) {
    final pinController = TextEditingController();
    final reasonController = TextEditingController();
    String? errorMessage;

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Otorisasi Void Transaksi (FSD-08)'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Masukkan 6-digit PIN Supervisor dan alasan pembatalan transaksi ini. Pembayaran akan dicatat sebagai Refund.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: pinController,
                  placeholder: 'PIN Void (Default: 123456)',
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(letterSpacing: 6, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: reasonController,
                  placeholder: 'Alasan Void (min. 3 huruf)',
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                final pin = pinController.text.trim();
                final reason = reasonController.text.trim();
                if (pin.length != 6) {
                  setDialogState(() => errorMessage = 'PIN Supervisor wajib 6 digit.');
                  return;
                }
                if (reason.length < 3) {
                  setDialogState(() => errorMessage = 'Alasan pembatalan minimal 3 karakter.');
                  return;
                }

                if (onVoid != null) {
                  final ok = await onVoid!(pin, reason);
                  if (ok) {
                    Navigator.pop(dialogCtx);
                    onClose();
                  } else {
                    setDialogState(() => errorMessage = 'PIN salah atau gagal membatalkan transaksi.');
                  }
                }
              },
              child: const Text('Konfirmasi Void'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, String label, String value, {bool isBoldValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: IOSColors.secondaryLabel.resolveFrom(context),
            decoration: TextDecoration.none,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
            color: IOSColors.label.resolveFrom(context),
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemRow(BuildContext context, Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Item';
    final qty = (item['qty'] as num?)?.toInt() ?? 1;
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final itemSubtotal = qty * price;
    final modifiers = (item['modifiers'] as List<dynamic>?) ?? [];
    final notes = item['notes'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${qty}x $name',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: IOSColors.label.resolveFrom(context),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _currency.format(itemSubtotal),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: IOSColors.label.resolveFrom(context),
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        if (modifiers.isNotEmpty)
          for (final m in modifiers) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 1),
              child: Text(
                '+ ${m['name']} (${(m['price'] ?? 0) > 0 ? _currency.format(m['price']) : "Gratis"})',
                style: TextStyle(
                  fontSize: 10.5,
                  color: IOSColors.secondaryLabel.resolveFrom(context),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        if (notes != null && notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 1),
            child: Text(
              '* Catatan: $notes',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: IOSColors.secondaryLabel.resolveFrom(context),
                decoration: TextDecoration.none,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAmountRow(BuildContext context, String label, int amount, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: IOSColors.secondaryLabel.resolveFrom(context),
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            isDiscount ? '-${_currency.format(amount.abs())}' : _currency.format(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDiscount ? IOSColors.destructive.resolveFrom(context) : IOSColors.label.resolveFrom(context),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider(BuildContext context) {
    return Row(
      children: List.generate(
        32,
        (i) => Expanded(
          child: Container(
            color: i % 2 == 0
                ? IOSColors.separator.resolveFrom(context).withValues(alpha: 0.6)
                : Colors.transparent,
            height: 1,
          ),
        ),
      ),
    );
  }
}
