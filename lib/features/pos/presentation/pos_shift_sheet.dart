// @req FR-POS-01, FR-POS-01a, FR-POS-01b, FR-POS-13, FSD-09
// Apple HIG iOS-Look Shift Management Sheet for Hiroshima POS (iOS + Android)

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/sync/pos_sync_service.dart';
import '../../../core/theme/ios_components.dart';
import '../../../core/theme/ios_tokens.dart';

class PosShiftSheet extends StatefulWidget {
  const PosShiftSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const PosShiftSheet(),
    );
  }

  @override
  State<PosShiftSheet> createState() => _PosShiftSheetState();
}

class _PosShiftSheetState extends State<PosShiftSheet> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final TextEditingController _cashController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    PosSyncService.instance.fetchCurrentShift();
    _cashController.text = '200000';
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  int get _parsedAmount {
    final clean = _cashController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 0;
  }

  Future<void> _handleOpenShift() async {
    final amount = _parsedAmount;
    if (amount < 0) {
      setState(() => _errorMessage = 'Modal awal tidak boleh kurang dari 0.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await PosSyncService.instance.openShift(amount);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = res['message'] as String? ?? 'Gagal membuka shift.';
      });
    }
  }

  Future<void> _handleCloseShift() async {
    final amount = _parsedAmount;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await PosSyncService.instance.closeShift(amount);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = res['message'] as String? ?? 'Gagal menutup shift.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncService = PosSyncService.instance;
    final shift = syncService.currentShift;
    final isOpen = syncService.hasActiveShift;

    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: IOSColors.groupedBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(IOSRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: IOSSpacing.md,
            right: IOSSpacing.md,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + IOSSpacing.md,
          ),
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
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(CupertinoIcons.money_dollar_circle_fill, color: Color(0xFFDC2626), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isOpen ? 'Tutup Shift Kasir' : 'Buka Shift Kasir Baru',
                            style: IOSText.title3.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Tutup',
                      style: IOSText.body.copyWith(color: IOSColors.accent.resolveFrom(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: IOSSpacing.md),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: IOSSpacing.md),
              ],

              // Content based on shift status
              if (!isOpen) ...[
                // OPEN SHIFT FLOW
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(IOSRadius.card),
                    border: Border.all(
                      color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Masukkan Modal Kas Awal di Laci',
                        style: IOSText.subhead.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Uang tunai kembalian awal yang disiapkan sebelum transaksi dimulai.',
                        style: IOSText.caption1.copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                      ),
                      const SizedBox(height: 14),

                      CupertinoTextField(
                        controller: _cashController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text('Rp ', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Quick Denominations
                      Wrap(
                        spacing: 8,
                        children: [100000, 200000, 300000, 500000].map((amt) {
                          return CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                            borderRadius: BorderRadius.circular(16),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _cashController.text = amt.toString();
                              });
                            },
                            child: Text(
                              _currency.format(amt),
                              style: IOSText.caption1.copyWith(
                                color: CupertinoColors.label.resolveFrom(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: IOSSpacing.lg),

                IOSButton(
                  label: 'Buka Shift Sekarang',
                  variant: IOSButtonVariant.filled,
                  expanded: true,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleOpenShift,
                ),
              ] else ...[
                // CLOSE SHIFT FLOW
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(IOSRadius.card),
                    border: Border.all(
                      color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Shift Aktif', style: IOSText.subhead),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'BERJALAN',
                              style: TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      _buildInfoRow('Modal Awal Kasir', _currency.format((shift?['starting_cash'] as num?)?.toInt() ?? 0)),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        'Ekspektasi Kas Laci',
                        _currency.format((shift?['expected_cash'] as num?)?.toInt() ?? (shift?['starting_cash'] as num?)?.toInt() ?? 0),
                        isBold: true,
                      ),
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.symmetric(vertical: 14),
                        color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.4),
                      ),

                      Text(
                        'Hitung Fisik Kas di Laci Kasir',
                        style: IOSText.subhead.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hitung seluruh uang fisik tunai di kas laci saat shift berakhir.',
                        style: IOSText.caption1.copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                      ),
                      const SizedBox(height: 10),

                      CupertinoTextField(
                        controller: _cashController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text('Rp ', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Builder(builder: (_) {
                        final expected = (shift?['expected_cash'] as num?)?.toInt() ?? (shift?['starting_cash'] as num?)?.toInt() ?? 0;
                        final actual = _parsedAmount;
                        final diff = actual - expected;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: diff == 0
                                ? const Color(0xFFDCFCE7)
                                : (diff < 0 ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                diff == 0 ? 'Kas Seimbang' : (diff < 0 ? 'Selisih Kurang' : 'Selisih Lebih'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: diff == 0
                                      ? const Color(0xFF166534)
                                      : (diff < 0 ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                                ),
                              ),
                              Text(
                                _currency.format(diff.abs()),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: diff == 0
                                      ? const Color(0xFF166534)
                                      : (diff < 0 ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: IOSSpacing.lg),

                IOSButton(
                  label: 'Tutup Shift Sekarang',
                  variant: IOSButtonVariant.filled,
                  isDestructive: true,
                  expanded: true,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleCloseShift,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: IOSText.subhead.copyWith(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        Text(
          value,
          style: IOSText.subhead.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? const Color(0xFFDC2626) : CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}
