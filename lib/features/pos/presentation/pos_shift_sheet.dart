// @req FR-POS-01, FR-POS-01a, FR-POS-01b, FR-POS-13, FSD-09
// Apple HIG iOS-Look Shift Management Sheet for Hiroshima POS (iOS + Android)

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/sync/pos_sync_service.dart';
import '../../../core/theme/ios_components.dart';
import '../../../core/theme/ios_tokens.dart';
import 'pos_close_shift_report_dialog.dart';

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
  String? _lastErrorCode;

  @override
  void initState() {
    super.initState();
    PosSyncService.instance.addListener(_onSyncChange);
    PosSyncService.instance.fetchCurrentShift();
    _cashController.text = '';
  }

  @override
  void dispose() {
    PosSyncService.instance.removeListener(_onSyncChange);
    _cashController.dispose();
    super.dispose();
  }

  void _onSyncChange() {
    if (mounted) {
      setState(() {});
    }
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
      _lastErrorCode = null;
    });

    final res = await PosSyncService.instance.openShift(amount);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
    } else {
      HapticFeedback.heavyImpact();
      final msg = res['message'] as String? ?? 'Gagal membuka shift.';
      setState(() {
        _errorMessage = msg;
        _lastErrorCode = res['error_code'] as String?;
      });

      // If active shift exists, refresh immediately to switch view to Close Shift
      if (res['error_code'] == 'ACTIVE_SHIFT_EXISTS' || msg.contains('shift aktif')) {
        await PosSyncService.instance.fetchCurrentShift();
        if (mounted) {
          setState(() {
            _cashController.text = '';
          });
        }
      }
    }
  }

  Future<void> _handleCloseShift({bool forceCancelUnfinalized = false}) async {
    final amount = _parsedAmount;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lastErrorCode = null;
    });

    final res = await PosSyncService.instance.closeShift(
      amount,
      forceCancelUnfinalized: forceCancelUnfinalized,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      HapticFeedback.mediumImpact();
      final report = (res['report'] as Map<String, dynamic>?) ?? {};
      final rootNav = Navigator.of(context);
      rootNav.pop();
      PosCloseShiftReportDialog.show(rootNav.context, report: report);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = res['message'] as String? ?? 'Gagal menutup shift.';
        _lastErrorCode = res['error_code'] as String?;
      });
    }
  }

  Future<void> _handleViewLastReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final report = await PosSyncService.instance.fetchCurrentShiftReport();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (report != null) {
      final rootNav = Navigator.of(context);
      rootNav.pop();
      PosCloseShiftReportDialog.show(rootNav.context, report: report, autoPrint: false);
    } else {
      setState(() {
        _errorMessage = 'Tidak ditemukan data laporan shift sebelumnya.';
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
                            isOpen
                                ? (shift?['is_other_branch'] == true
                                    ? 'Tutup Shift (${shift?['branch_name'] ?? 'Cabang Lain'})'
                                    : 'Tutup Shift Kasir')
                                : 'Buka Shift Kasir Baru',
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
                Builder(builder: (ctx) {
                  final isDark = CupertinoTheme.of(ctx).brightness == Brightness.dark;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                CupertinoIcons.exclamationmark_triangle_fill,
                                size: 16,
                                color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_lastErrorCode == 'UNFINALIZED_TRANSACTIONS') ...[
                          const SizedBox(height: 10),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(8),
                            onPressed: _isLoading
                                ? null
                                : () => _handleCloseShift(forceCancelUnfinalized: true),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.trash, size: 15, color: CupertinoColors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Batalkan Transaksi Belum Selesai & Tutup Shift',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_lastErrorCode == 'ACTIVE_SHIFT_EXISTS' || _errorMessage!.contains('shift aktif')) ...[
                          const SizedBox(height: 10),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(8),
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setState(() => _isLoading = true);
                                    await PosSyncService.instance.fetchCurrentShift();
                                    if (mounted) {
                                      setState(() {
                                        _isLoading = false;
                                        _errorMessage = null;
                                        _lastErrorCode = null;
                                        _cashController.text = '';
                                      });
                                    }
                                  },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.arrow_clockwise, size: 15, color: CupertinoColors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Muat & Tutup Shift Aktif Ini Sekarang',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
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
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            'Rp ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
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
                const SizedBox(height: 8),

                IOSButton(
                  label: 'Lihat Laporan Shift Terakhir',
                  icon: CupertinoIcons.doc_text,
                  variant: IOSButtonVariant.plain,
                  size: IOSButtonSize.small,
                  expanded: true,
                  isLoading: false,
                  onPressed: _isLoading ? null : _handleViewLastReport,
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
                          Builder(builder: (ctx) {
                            final isDark = CupertinoTheme.of(ctx).brightness == Brightness.dark;
                            final isOther = shift?['is_other_branch'] == true;
                            final label = isOther
                                ? 'AKTIF (${shift?['branch_name'] ?? 'CABANG LAIN'})'
                                : 'BERJALAN';

                            final bgColor = isOther
                                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFDBEAFE))
                                : (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7));

                            final borderColor = isOther
                                ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD))
                                : (isDark ? const Color(0xFF047857) : const Color(0xFF86EFAC));

                            final textColor = isOther
                                ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF))
                                : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534));

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: borderColor,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      if (shift?['is_other_branch'] == true) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: CupertinoTheme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: CupertinoTheme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFBFDBFE),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF2563EB), size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Shift #${shift?['id']} ini aktif di ${shift?['branch_name'] ?? 'cabang lain'}. Harap tutup shift ini untuk menyelesaikan sesi kasir atau membuka shift di cabang saat ini.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: CupertinoTheme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF93C5FD)
                                        : const Color(0xFF1E40AF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            'Rp ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Builder(builder: (diffCtx) {
                        final isDark = CupertinoTheme.of(diffCtx).brightness == Brightness.dark;
                        final expected = (shift?['expected_cash'] as num?)?.toInt() ?? (shift?['starting_cash'] as num?)?.toInt() ?? 0;
                        final actual = _parsedAmount;
                        final diff = actual - expected;

                        final bgColor = diff == 0
                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                            : (diff < 0
                                ? (isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2))
                                : (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)));

                        final borderColor = diff == 0
                            ? (isDark ? const Color(0xFF047857) : const Color(0xFF86EFAC))
                            : (diff < 0
                                ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5))
                                : (isDark ? const Color(0xFF78350F) : const Color(0xFFFCD34D)));

                        final textColor = diff == 0
                            ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534))
                            : (diff < 0
                                ? (isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B))
                                : (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)));

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor, width: 0.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                diff == 0 ? 'Kas Seimbang' : (diff < 0 ? 'Selisih Kurang' : 'Selisih Lebih'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                _currency.format(diff.abs()),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: textColor,
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
