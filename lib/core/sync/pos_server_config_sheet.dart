// @req FR-OFF-01, FR-OFF-02, FSD-10
// Apple HIG Backend Server Configuration Sheet for Hiroshima POS

import 'package:flutter/cupertino.dart';
import '../theme/ios_tokens.dart';
import '../theme/ios_components.dart';
import 'pos_sync_service.dart';

class PosServerConfigSheet extends StatefulWidget {
  const PosServerConfigSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const PosServerConfigSheet(),
    );
  }

  @override
  State<PosServerConfigSheet> createState() => _PosServerConfigSheetState();
}

class _PosServerConfigSheetState extends State<PosServerConfigSheet> {
  final TextEditingController _urlController = TextEditingController();
  final PosSyncService _syncService = PosSyncService.instance;
  bool _isTesting = false;
  Map<String, dynamic>? _testResult;

  @override
  void initState() {
    super.initState();
    _urlController.text = _syncService.baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleTest() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final res = await _syncService.testConnection(_urlController.text);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = res;
      });
    }
  }

  Future<void> _handleSave() async {
    await _syncService.setBaseUrl(_urlController.text);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _applyPreset(String preset) {
    setState(() {
      _urlController.text = preset;
      _testResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IOSColors.groupedBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
                  const Icon(CupertinoIcons.cloud_download, size: 24, color: IOSColors.accentLight),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pengaturan Server Backend', style: IOSText.headline),
                        Text(
                          'Koneksikan POS ke sistem Laravel backend Hiroshima',
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
                    // Input Card
                    Text('URL ENDPOINT API', style: IOSText.caption1.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    IOSGroupedCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      children: [
                        CupertinoTextField(
                          controller: _urlController,
                          placeholder: 'http://127.0.0.1:8000/api/v1',
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          decoration: null,
                          style: IOSText.body,
                          clearButtonMode: OverlayVisibilityMode.editing,
                          keyboardType: TextInputType.url,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Preset buttons
                    Text('PRESET URL CEPAT', style: IOSText.caption1.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                          onPressed: () => _applyPreset('http://127.0.0.1:8000/api/v1'),
                          child: Text('Localhost (8000)', style: IOSText.caption1.copyWith(color: IOSColors.accent.resolveFrom(context))),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                          onPressed: () => _applyPreset('http://10.0.2.2:8000/api/v1'),
                          child: Text('Emulator Android (10.0.2.2)', style: IOSText.caption1.copyWith(color: IOSColors.accent.resolveFrom(context))),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                          onPressed: () => _applyPreset('http://hiroshima.test/api/v1'),
                          child: Text('Laragon (hiroshima.test)', style: IOSText.caption1.copyWith(color: IOSColors.accent.resolveFrom(context))),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (_testResult != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_testResult!['success'] == true)
                              ? IOSColors.success.resolveFrom(context).withValues(alpha: 0.12)
                              : IOSColors.destructive.resolveFrom(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_testResult!['success'] == true)
                                ? IOSColors.success.resolveFrom(context)
                                : IOSColors.destructive.resolveFrom(context),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  (_testResult!['success'] == true) ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.xmark_circle_fill,
                                  color: (_testResult!['success'] == true) ? IOSColors.success.resolveFrom(context) : IOSColors.destructive.resolveFrom(context),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _testResult!['message'] as String? ?? '',
                                    style: IOSText.subhead.copyWith(
                                      color: (_testResult!['success'] == true) ? IOSColors.success.resolveFrom(context) : IOSColors.destructive.resolveFrom(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_testResult!['latency']} ms',
                                  style: IOSText.caption1.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context)),
                                ),
                              ],
                            ),
                            if (_testResult!['branch'] != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Cabang: ${_testResult!['branch']}',
                                style: IOSText.footnote.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: IOSButton(
                            label: 'Uji Koneksi',
                            icon: CupertinoIcons.wifi,
                            variant: IOSButtonVariant.tinted,
                            isLoading: _isTesting,
                            onPressed: _handleTest,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: IOSButton(
                            label: 'Simpan & Sinkronkan',
                            icon: CupertinoIcons.cloud_download,
                            variant: IOSButtonVariant.filled,
                            onPressed: _handleSave,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
