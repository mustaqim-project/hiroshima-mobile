// @req FR-POS-10, FSD-09
// Apple HIG iOS-Look In-App OTA Update Dialog for Hiroshima POS (Android)

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator, Material;
import '../../../core/theme/ios_components.dart';
import '../../../core/theme/ios_tokens.dart';
import '../../../core/update/app_update_service.dart';

class PosUpdateDialog extends StatefulWidget {
  final bool forceCheck;

  const PosUpdateDialog({super.key, this.forceCheck = false});

  static Future<void> show(BuildContext context, {bool forceCheck = false}) {
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PosUpdateDialog(forceCheck: forceCheck),
    );
  }

  @override
  State<PosUpdateDialog> createState() => _PosUpdateDialogState();
}

class _PosUpdateDialogState extends State<PosUpdateDialog> {
  final _service = AppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChange);
    if (widget.forceCheck || !_service.hasUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _service.checkForUpdate();
      });
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  void _startUpdate() {
    final url = _service.downloadUrl;
    if (url == null || url.isEmpty) return;

    _service.startOtaUpdate(
      targetUrl: url,
      onComplete: () {
        if (mounted) {
          // Dialog will naturally remain or dismiss as OS package installer opens
        }
      },
      onError: (err) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final isDownloading = _service.isDownloading;
    final isChecking = _service.isChecking;
    final hasUpdate = _service.hasUpdate;
    final isMandatory = _service.isMandatory;

    return Center(
      child: Container(
        width: 440,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: IOSColors.groupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(IOSRadius.sheet),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: CupertinoColors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(IOSSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Icon
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (hasUpdate ? const Color(0xFF2563EB) : IOSColors.success.resolveFrom(context))
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasUpdate
                          ? CupertinoIcons.arrow_down_circle_fill
                          : CupertinoIcons.checkmark_seal_fill,
                      color: hasUpdate ? const Color(0xFF2563EB) : IOSColors.success.resolveFrom(context),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  isChecking
                      ? 'Memeriksa Pembaruan...'
                      : (hasUpdate ? 'Pembaruan Tersedia' : 'Aplikasi Sudah Versi Terbaru'),
                  textAlign: TextAlign.center,
                  style: IOSText.title3.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  hasUpdate
                      ? 'Versi Baru: v${_service.latestVersion ?? '1.0.2'} (Build #${_service.latestBuildNumber ?? 3})\nVersi Terpasang: v${_service.currentVersion}'
                      : 'Hiroshima POS v${_service.currentVersion} (Build #${_service.currentBuildNumber})',
                  textAlign: TextAlign.center,
                  style: IOSText.caption1.copyWith(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: IOSSpacing.md),

                // Error Notice
                if (_service.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5)),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFDC2626), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _service.errorMessage!,
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: IOSSpacing.md),
                ],

                // Checking State Indicator
                if (isChecking) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CupertinoActivityIndicator(radius: 14)),
                  ),
                ] else if (hasUpdate) ...[
                  // Changelog Box
                  if (_service.changelog != null && _service.changelog!.isNotEmpty) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Catatan Pembaruan:',
                              style: IOSText.caption1.copyWith(
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.label.resolveFrom(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _service.changelog!,
                              style: IOSText.caption1.copyWith(
                                height: 1.4,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: IOSSpacing.md),
                  ],

                  // Downloading Progress
                  if (isDownloading) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _service.downloadProgress > 0 ? _service.downloadProgress / 100.0 : null,
                            backgroundColor: CupertinoColors.systemGrey5.resolveFrom(context),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _service.updateStatusText,
                          textAlign: TextAlign.center,
                          style: IOSText.caption1.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Paket instalasi Android akan terbuka otomatis setelah unduhan selesai.',
                          textAlign: TextAlign.center,
                          style: IOSText.caption2.copyWith(
                            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: IOSSpacing.md),
                  ],
                ],

                // Action Buttons
                if (hasUpdate && !isDownloading) ...[
                  IOSButton(
                    label: 'Perbarui Sekarang',
                    icon: CupertinoIcons.arrow_down_to_line_alt,
                    variant: IOSButtonVariant.filled,
                    expanded: true,
                    onPressed: _startUpdate,
                  ),
                  if (!isMandatory) ...[
                    const SizedBox(height: 8),
                    IOSButton(
                      label: 'Nanti Saja',
                      variant: IOSButtonVariant.plain,
                      expanded: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ] else if (isDownloading) ...[
                  IOSButton(
                    label: 'Batalkan Unduhan',
                    variant: IOSButtonVariant.plain,
                    isDestructive: true,
                    expanded: true,
                    onPressed: () {
                      _service.cancelDownload();
                      Navigator.pop(context);
                    },
                  ),
                ] else if (!isChecking) ...[
                  IOSButton(
                    label: 'Tutup',
                    variant: IOSButtonVariant.filled,
                    expanded: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
