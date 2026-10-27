// @req FR-POS-06, FR-POS-07, FR-POS-14, FR-POS-17, FR-PRN-01, FR-PRN-02, FR-OFF-01, FSD-06, FSD-10, FSD-14
// Apple HIG Payment & Bluetooth Thermal Printing Sheet for Hiroshima POS

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/pricing/order_calculator.dart';
import '../../../../core/printing/thermal_printer_service.dart';
import '../../../../core/sync/pos_sync_service.dart';
import '../../../../core/time/trusted_clock.dart';
import '../../../../core/theme/ios_tokens.dart';
import '../../../../core/theme/ios_components.dart';
import 'pos_receipt_dialog.dart';

class PosPaymentSheet extends StatefulWidget {
  const PosPaymentSheet({
    super.key,
    required this.cart,
    required this.calculation,
    required this.orderType,
    required this.orderTypeId,
    required this.tableNo,
    required this.onPaymentSuccess,
    this.resumedOrderId,
  });

  final List<Map<String, dynamic>> cart;
  final OrderCalculationResult calculation;
  final String orderType;
  final int orderTypeId;
  final String? tableNo;
  final VoidCallback onPaymentSuccess;
  final int? resumedOrderId;

  static Future<void> show({
    required BuildContext context,
    required List<Map<String, dynamic>> cart,
    required OrderCalculationResult calculation,
    required String orderType,
    required int orderTypeId,
    required String? tableNo,
    required VoidCallback onPaymentSuccess,
    int? resumedOrderId,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PosPaymentSheet(
        cart: cart,
        calculation: calculation,
        orderType: orderType,
        orderTypeId: orderTypeId,
        tableNo: tableNo,
        onPaymentSuccess: onPaymentSuccess,
        resumedOrderId: resumedOrderId,
      ),
    );
  }

  @override
  State<PosPaymentSheet> createState() => _PosPaymentSheetState();
}

class _PosPaymentSheetState extends State<PosPaymentSheet> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final TextEditingController _cashInputController = TextEditingController();

  late Map<String, dynamic> _selectedPaymentMethod;
  int _cashGiven = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final methods = PosSyncService.instance.paymentMethods;
    if (methods.isNotEmpty) {
      _selectedPaymentMethod = methods.first;
    } else {
      _selectedPaymentMethod = {'id': 1, 'name': 'Tunai', 'code': 'CASH'};
    }

    _cashGiven = widget.calculation.totalAmount;
    _cashInputController.text = _cashGiven.toString();
  }

  @override
  void dispose() {
    _cashInputController.dispose();
    super.dispose();
  }

  bool get _isCash =>
      (_selectedPaymentMethod['code'] ?? _selectedPaymentMethod['name'] ?? '').toString().toLowerCase().contains('cash') ||
      (_selectedPaymentMethod['name'] ?? '').toString().toLowerCase().contains('tunai');

  int get _changeAmount => _isCash ? (_cashGiven - widget.calculation.totalAmount) : 0;
  bool get _canSubmit => !_isCash || (_cashGiven >= widget.calculation.totalAmount);

  Future<void> _handleProcessPayment() async {
    if (!_canSubmit) return;

    if (!PosSyncService.instance.hasActiveShift) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Shift Kasir Belum Dibuka'),
          content: const Text('Transaksi diblokir. Kasir wajib melakukan Open Shift sebelum dapat memproses pembayaran.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final calc = widget.calculation;
    final branch = PosSyncService.instance.branch;
    final branchName = (branch['name'] as String?) ?? PosSyncService.instance.appName;
    final branchAddress = (branch['address'] as String?) ?? '';
    final branchPhone = (branch['phone'] as String?) ?? '';
    final branchCode = (branch['code'] as String?)?.replaceAll('-', '') ?? 'HRS';

    final orderNo = '$branchCode-POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final orderUuid = const Uuid().v4();
    final transactionTime = TrustedClock().now;
    final currentShift = PosSyncService.instance.currentShift;
    final user = PosSyncService.instance.currentUser;
    final cashierName = (user?['name'] as String?) ?? (user?['username'] as String?) ?? 'Kasir';

    // Build Payload for Backend Push (FSD-10)
    final orderPayload = {
      'uuid': orderUuid,
      'order_no': orderNo,
      'branch_id': branch['id'] ?? 1,
      'shift_id': currentShift?['id'],
      'user_id': user?['id'] ?? 1,
      'order_type_id': widget.orderTypeId,
      'table_id': widget.tableNo != null ? int.tryParse(widget.tableNo!) : null,
      'resumed_order_id': widget.resumedOrderId,
      'client_created_at': transactionTime.toIso8601String(),
      'subtotal': calc.subtotal,
      'promo_discount_amount': calc.promoDiscount,
      'voucher_discount_amount': calc.voucherDiscount,
      'loyalty_discount_amount': calc.loyaltyDiscount,
      'manual_discount_amount': calc.manualDiscount,
      'manual_discount_reason': calc.manualDiscount > 0 ? 'Diskon manual' : null,
      'service_charge_amount': calc.serviceChargeAmount,
      'tax_amount': calc.taxAmount,
      'rounding_amount': calc.roundingAmount,
      'total_amount': calc.totalAmount,
      'paid_amount': _isCash ? _cashGiven : calc.totalAmount,
      'change_amount': _changeAmount > 0 ? _changeAmount : 0,
      'items': widget.cart.map((item) {
        return {
          'product_id': item['id'],
          'product_variant_id': item['variant_id'],
          'product_name': item['name'],
          'variant_name': item['variant_name'],
          'quantity': item['qty'],
          'unit_price': item['price'],
          'subtotal': (item['price'] as int) * (item['qty'] as int),
          'notes': item['notes'],
          'modifiers': ((item['modifiers'] as List<dynamic>?) ?? []).map((m) => {
            'modifier_id': m['modifier_id'] ?? m['id'],
            'modifier_name': m['name'] ?? m['modifier_name'],
            'unit_price': m['price'] ?? m['unit_price'] ?? 0,
            'quantity': 1,
          }).toList(),
        };
      }).toList(),
      'payments': [
        {
          'payment_method_id': _selectedPaymentMethod['id'] ?? 1,
          'payment_method_name': _selectedPaymentMethod['name'] ?? 'Tunai (Cash)',
          'amount': _isCash ? _cashGiven : calc.totalAmount,
        }
      ],
    };

    // 1. Submit to local outbox & sync backend
    await PosSyncService.instance.submitOrder(orderPayload);

    // 2. Bluetooth Thermal Print (Dual Copy: Rangkap 1 & Rangkap 2)
    String printNotice = '';
    if (ThermalPrinterService.instance.autoPrintOnCheckout) {
      final printRes = await ThermalPrinterService.instance.printOrderDualCopy(
        branchName: branchName,
        branchAddress: branchAddress,
        branchPhone: branchPhone,
        orderNo: orderNo,
        tableNo: widget.tableNo,
        orderTypeName: widget.orderType,
        cashierName: cashierName,
        transactionTime: transactionTime,
        items: widget.cart,
        subtotal: calc.subtotal,
        totalDiscount: calc.totalDiscount,
        serviceChargeAmount: calc.serviceChargeAmount,
        taxAmount: calc.taxAmount,
        roundingAmount: calc.roundingAmount,
        totalAmount: calc.totalAmount,
        payments: [
          {
            'method': _selectedPaymentMethod['name'] ?? 'Tunai',
            'amount': _isCash ? _cashGiven : calc.totalAmount,
          }
        ],
        changeAmount: _changeAmount > 0 ? _changeAmount : 0,
        openDrawer: _isCash,
      );

      printNotice = printRes.success
          ? 'Struk Rangkap 1 & Rangkap 2 berhasil dicetak ke printer Bluetooth.'
          : printRes.message;
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);

    // Close payment modal
    Navigator.pop(context);
    widget.onPaymentSuccess();

    // Show Apple HIG Digital Bill & Thermal Receipt Dialog
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PosReceiptDialog(
        branchName: branchName,
        branchAddress: branchAddress,
        branchPhone: branchPhone,
        orderNo: orderNo,
        tableNo: widget.tableNo,
        orderTypeName: widget.orderType,
        cashierName: cashierName,
        transactionTime: transactionTime,
        items: widget.cart,
        subtotal: calc.subtotal,
        totalDiscount: calc.totalDiscount,
        serviceChargeAmount: calc.serviceChargeAmount,
        taxAmount: calc.taxAmount,
        roundingAmount: calc.roundingAmount,
        totalAmount: calc.totalAmount,
        paymentMethodName: _selectedPaymentMethod['name'] ?? 'Tunai (Cash)',
        paidAmount: _isCash ? _cashGiven : calc.totalAmount,
        changeAmount: _changeAmount > 0 ? _changeAmount : 0,
        printNotice: printNotice.isNotEmpty ? printNotice : null,
        onReprint: () async {
          await ThermalPrinterService.instance.printOrderDualCopy(
            branchName: branchName,
            branchAddress: branchAddress,
            branchPhone: branchPhone,
            orderNo: orderNo,
            tableNo: widget.tableNo,
            orderTypeName: widget.orderType,
            cashierName: cashierName,
            transactionTime: transactionTime,
            items: widget.cart,
            subtotal: calc.subtotal,
            totalDiscount: calc.totalDiscount,
            serviceChargeAmount: calc.serviceChargeAmount,
            taxAmount: calc.taxAmount,
            roundingAmount: calc.roundingAmount,
            totalAmount: calc.totalAmount,
            payments: [
              {
                'method': _selectedPaymentMethod['name'] ?? 'Tunai',
                'amount': _isCash ? _cashGiven : calc.totalAmount,
              }
            ],
            changeAmount: _changeAmount > 0 ? _changeAmount : 0,
            openDrawer: _isCash,
          );
        },
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calc = widget.calculation;
    final paymentMethods = PosSyncService.instance.paymentMethods;

    return Container(
      decoration: BoxDecoration(
        color: IOSColors.groupedBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        maxWidth: 580,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grabber handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(CupertinoIcons.creditcard_fill, size: 24, color: IOSColors.accent.resolveFrom(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Penyelesaian Pembayaran', style: IOSText.headline.copyWith(color: IOSColors.label.resolveFrom(context))),
                        Text(
                          '${widget.orderType}${widget.tableNo != null ? " • Meja ${widget.tableNo}" : ""}',
                          style: IOSText.footnote.copyWith(
                            color: IOSColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: IOSColors.systemFill.resolveFrom(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: IOSColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 0.5,
              color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.4),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Bayar Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: IOSColors.accent.resolveFrom(context).withValues(alpha: 0.08),
                        borderRadius: IOSRadius.cardRadius,
                        border: Border.all(
                          color: IOSColors.accent.resolveFrom(context).withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text('TOTAL YANG HARUS DIBAYAR', style: IOSText.caption1.copyWith(fontWeight: FontWeight.bold, color: IOSColors.accent.resolveFrom(context))),
                          const SizedBox(height: 4),
                          Text(
                            _currency.format(calc.totalAmount),
                            style: IOSText.tabular(IOSText.largeTitle).copyWith(
                              fontWeight: FontWeight.w900,
                              color: IOSColors.accent.resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Payment Methods Selection (from Backend) - 2-Column Grid (Kiri & Kanan)
                    Text('METODE PEMBAYARAN', style: IOSText.caption1.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (ctx) {
                        final isDark = Theme.of(ctx).brightness == Brightness.dark;
                        final methods = paymentMethods.isEmpty
                            ? [
                                {'id': 1, 'name': 'Tunai (Cash)', 'code': 'CASH'},
                                {'id': 2, 'name': 'QRIS', 'code': 'QRIS'},
                              ]
                            : paymentMethods;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: methods.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.5,
                          ),
                          itemBuilder: (context, i) {
                            final pm = methods[i];
                            final isSel = _selectedPaymentMethod['id'] == pm['id'];
                            final name = pm['name'] as String? ?? 'Metode';

                            IconData pIcon = CupertinoIcons.money_dollar;
                            if (name.toLowerCase().contains('qris')) {
                              pIcon = CupertinoIcons.qrcode;
                            } else if (name.toLowerCase().contains('kartu') || name.toLowerCase().contains('edc')) {
                              pIcon = CupertinoIcons.creditcard;
                            } else if (name.toLowerCase().contains('transfer')) {
                              pIcon = CupertinoIcons.arrow_right_arrow_left;
                            }

                            final accentColor = IOSColors.accent.resolveFrom(context);

                            return CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedPaymentMethod = pm;
                                  if (!_isCash) {
                                    _cashGiven = calc.totalAmount;
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? accentColor.withValues(alpha: isDark ? 0.18 : 0.08)
                                      : (isDark ? const Color(0xFF242426) : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel
                                        ? accentColor
                                        : (isDark ? const Color(0xFF38383A) : const Color(0xFFE2E8F0)),
                                    width: isSel ? 1.8 : 0.8,
                                  ),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: accentColor.withValues(alpha: 0.15),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? accentColor.withValues(alpha: isDark ? 0.25 : 0.15)
                                            : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        pIcon,
                                        size: 18,
                                        color: isSel ? accentColor : IOSColors.secondaryLabel.resolveFrom(context),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                          color: isSel ? accentColor : IOSColors.label.resolveFrom(context),
                                          decoration: TextDecoration.none,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      isSel ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                                      color: isSel ? accentColor : CupertinoColors.systemGrey4,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Cash Input & Change Calculation Section
                    if (_isCash) ...[
                      const SizedBox(height: 16),
                      Text('UANG TUNAI DITERIMA', style: IOSText.caption1.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      IOSGroupedCard(
                        padding: const EdgeInsets.all(12),
                        children: [
                          CupertinoTextField(
                            controller: _cashInputController,
                            keyboardType: TextInputType.number,
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text('Rp ', style: IOSText.headline.copyWith(color: IOSColors.label.resolveFrom(context))),
                            ),
                            style: IOSText.title2.copyWith(fontWeight: FontWeight.bold, color: IOSColors.label.resolveFrom(context)),
                            decoration: null,
                            onChanged: (val) {
                              setState(() {
                                _cashGiven = int.tryParse(val) ?? 0;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Quick Denomination Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                            borderRadius: BorderRadius.circular(10),
                            onPressed: () {
                              setState(() {
                                _cashGiven = calc.totalAmount;
                                _cashInputController.text = _cashGiven.toString();
                              });
                            },
                            child: Text('Uang Pas', style: IOSText.footnote.copyWith(color: IOSColors.accent.resolveFrom(context), fontWeight: FontWeight.bold)),
                          ),
                          for (final amt in [50000, 100000, 150000, 200000])
                            if (amt >= calc.totalAmount)
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                                borderRadius: BorderRadius.circular(10),
                                onPressed: () {
                                  setState(() {
                                    _cashGiven = amt;
                                    _cashInputController.text = amt.toString();
                                  });
                                },
                                child: Text(_currency.format(amt), style: IOSText.footnote.copyWith(color: IOSColors.label.resolveFrom(context))),
                              ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Kembalian
                      IOSGroupedCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Kembalian', style: IOSText.body.copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                _changeAmount >= 0 ? _currency.format(_changeAmount) : 'Uang Kurang',
                                style: IOSText.tabular(IOSText.headline).copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _changeAmount >= 0 ? IOSColors.success.resolveFrom(context) : IOSColors.destructive.resolveFrom(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Action Button
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
              child: IOSButton(
                label: 'Konfirmasi Bayar & Cetak Struk',
                icon: CupertinoIcons.printer_fill,
                variant: IOSButtonVariant.filled,
                isLoading: _isProcessing,
                expanded: true,
                onPressed: _canSubmit && !_isProcessing ? _handleProcessPayment : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
