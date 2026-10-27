// @req FR-POS-17, FR-PRN-01, FR-PRN-02, FR-PRN-03, FSD-14
// Apple HIG Bluetooth Thermal Printer Modal Sheet for Hiroshima POS

import 'package:flutter/cupertino.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../theme/ios_tokens.dart';
import '../theme/ios_components.dart';
import 'thermal_printer_service.dart';

class PosPrinterSheet extends StatefulWidget {
  const PosPrinterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const PosPrinterSheet(),
    );
  }

  @override
  State<PosPrinterSheet> createState() => _PosPrinterSheetState();
}

class _PosPrinterSheetState extends State<PosPrinterSheet> {
  final ThermalPrinterService _printerService = ThermalPrinterService.instance;
  List<BluetoothInfo> _devices = [];
  bool _isLoadingDevices = false;
  bool _isTestingPrint = false;
  String? _feedbackMessage;
  bool _isFeedbackSuccess = true;

  @override
  void initState() {
    super.initState();
    _printerService.addListener(_onPrinterChange);
    _loadDevices();
  }

  @override
  void dispose() {
    _printerService.removeListener(_onPrinterChange);
    super.dispose();
  }

  void _onPrinterChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoadingDevices = true;
      _feedbackMessage = null;
    });

    final devices = await _printerService.getPairedDevices();

    if (mounted) {
      setState(() {
        _devices = devices;
        _isLoadingDevices = false;
      });
    }
  }

  Future<void> _handleConnect(BluetoothInfo device) async {
    setState(() => _feedbackMessage = null);
    final result = await _printerService.connect(
      device.macAdress,
      deviceName: device.name,
    );

    if (mounted) {
      setState(() {
        _feedbackMessage = result.message;
        _isFeedbackSuccess = result.success;
      });
    }
  }

  Future<void> _handleDisconnect() async {
    final result = await _printerService.disconnect();
    if (mounted) {
      setState(() {
        _feedbackMessage = result.message;
        _isFeedbackSuccess = result.success;
      });
    }
  }

  Future<void> _handleTestPrint() async {
    setState(() {
      _isTestingPrint = true;
      _feedbackMessage = null;
    });

    final result = await _printerService.printTest();

    if (mounted) {
      setState(() {
        _isTestingPrint = false;
        _feedbackMessage = result.message;
        _isFeedbackSuccess = result.success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _printerService.isConnected;
    final isConnecting = _printerService.isConnecting;
    final connectedMac = _printerService.connectedMac;
    final connectedName = _printerService.connectedName;

    return Container(
      decoration: BoxDecoration(
        color: IOSColors.groupedBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
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

            // Navigation bar header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.printer_fill, size: 24, color: IOSColors.accentLight),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Printer Kasir Bluetooth', style: IOSText.headline),
                        Text(
                          'Mendukung printer Panda POS (PRJ-58D / PRJ-80), Iware, dll.',
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

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Connection Status Card
                    IOSGroupedCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isConnected
                                      ? IOSColors.success.resolveFrom(context)
                                      : (isConnecting
                                          ? IOSColors.warning.resolveFrom(context)
                                          : CupertinoColors.systemGrey),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isConnected
                                          ? 'Terhubung: ${connectedName ?? "Printer Thermal"}'
                                          : (isConnecting ? 'Menghubungkan printer...' : 'Belum Terhubung'),
                                      style: IOSText.body.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    if (connectedMac != null)
                                      Text(
                                        'MAC: $connectedMac',
                                        style: IOSText.caption1.copyWith(
                                          color: IOSColors.secondaryLabel.resolveFrom(context),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isConnected)
                                IOSButton(
                                  label: 'Putus',
                                  variant: IOSButtonVariant.tinted,
                                  size: IOSButtonSize.small,
                                  isDestructive: true,
                                  onPressed: _handleDisconnect,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_feedbackMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isFeedbackSuccess
                              ? IOSColors.success.resolveFrom(context).withValues(alpha: 0.12)
                              : IOSColors.destructive.resolveFrom(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isFeedbackSuccess
                                ? IOSColors.success.resolveFrom(context)
                                : IOSColors.destructive.resolveFrom(context),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isFeedbackSuccess ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_circle_fill,
                              color: _isFeedbackSuccess ? IOSColors.success.resolveFrom(context) : IOSColors.destructive.resolveFrom(context),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _feedbackMessage!,
                                style: IOSText.footnote.copyWith(
                                  color: _isFeedbackSuccess ? IOSColors.success.resolveFrom(context) : IOSColors.destructive.resolveFrom(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Paper Size & Auto Print Settings
                    Text('PENGATURAN KERTAS & CETAK', style: IOSText.caption1.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    IOSGroupedCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Ukuran Kertas Struk', style: IOSText.body),
                                  Text(
                                    'Panda POS PRJ-58D = 58 mm, PRJ-80 = 80 mm',
                                    style: IOSText.caption2.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context)),
                                  ),
                                ],
                              ),
                              CupertinoSlidingSegmentedControl<PaperSize>(
                                groupValue: _printerService.paperSize,
                                children: const {
                                  PaperSize.mm58: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('58 mm')),
                                  PaperSize.mm80: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('80 mm')),
                                },
                                onValueChanged: (size) {
                                  if (size != null) _printerService.setPaperSize(size);
                                },
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.only(left: 16),
                          color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.4),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cetak Otomatis saat Bayar', style: IOSText.body),
                                  Text(
                                    'Otomatis cetak Rangkap 1 & Rangkap 2',
                                    style: IOSText.caption2.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context)),
                                  ),
                                ],
                              ),
                              CupertinoSwitch(
                                value: _printerService.autoPrintOnCheckout,
                                activeTrackColor: IOSColors.accent.resolveFrom(context),
                                onChanged: (val) => _printerService.setAutoPrint(val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Paired Bluetooth Devices Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PERANGKAT BLUETOOTH TERPASANG', style: IOSText.caption1.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context), fontWeight: FontWeight.bold)),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(28, 28),
                          onPressed: _isLoadingDevices ? null : _loadDevices,
                          child: Row(
                            children: [
                              if (_isLoadingDevices)
                                const CupertinoActivityIndicator(radius: 7)
                              else
                                const Icon(CupertinoIcons.arrow_clockwise, size: 14),
                              const SizedBox(width: 4),
                              Text('Pindai Ulang', style: IOSText.footnote.copyWith(color: IOSColors.accent.resolveFrom(context))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (_isLoadingDevices)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: const Column(
                          children: [
                            CupertinoActivityIndicator(),
                            SizedBox(height: 8),
                            Text('Mencari perangkat Bluetooth terpasang...'),
                          ],
                        ),
                      )
                    else if (_devices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                          borderRadius: IOSRadius.cardRadius,
                        ),
                        child: Column(
                          children: [
                            Icon(CupertinoIcons.bluetooth, size: 36, color: IOSColors.tertiaryLabel.resolveFrom(context)),
                            const SizedBox(height: 8),
                            Text('Tidak ada perangkat Bluetooth ditemukan', style: IOSText.subhead.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              'Pastikan Bluetooth tablet aktif dan pasangkan (pair) printer Anda terlebih dahulu melalui Pengaturan Bluetooth Android / Tablet.',
                              textAlign: TextAlign.center,
                              style: IOSText.footnote.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context)),
                            ),
                          ],
                        ),
                      )
                    else
                      IOSGroupedCard(
                        children: [
                          for (int i = 0; i < _devices.length; i++) ...[
                            if (i > 0)
                              Container(
                                height: 0.5,
                                margin: const EdgeInsets.only(left: 48),
                                color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.4),
                              ),
                            Builder(
                              builder: (ctx) {
                                final d = _devices[i];
                                final isThisConnected = isConnected && connectedMac == d.macAdress;

                                return CupertinoListTile(
                                  leading: Icon(
                                    CupertinoIcons.printer,
                                    color: isThisConnected
                                        ? IOSColors.accent.resolveFrom(context)
                                        : IOSColors.secondaryLabel.resolveFrom(context),
                                  ),
                                  title: Text(
                                    d.name.isNotEmpty ? d.name : 'Unknown Device',
                                    style: IOSText.body.copyWith(
                                      fontWeight: isThisConnected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(d.macAdress, style: IOSText.caption1),
                                  trailing: isThisConnected
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: IOSColors.success.resolveFrom(context).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Aktif',
                                            style: TextStyle(
                                              color: IOSColors.success.resolveFrom(context),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      : IOSButton(
                                          label: 'Hubungkan',
                                          variant: IOSButtonVariant.tinted,
                                          size: IOSButtonSize.small,
                                          onPressed: isConnecting ? null : () => _handleConnect(d),
                                        ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),

                    const SizedBox(height: 24),

                    // Test Print Button
                    IOSButton(
                      label: 'Tes Cetak Struk (Panda / Thermal)',
                      icon: CupertinoIcons.printer,
                      variant: IOSButtonVariant.filled,
                      isLoading: _isTestingPrint,
                      expanded: true,
                      onPressed: isConnected ? _handleTestPrint : null,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Menguji cetak header Hiroshima Japanese Street Food & pemotong kertas.',
                        style: IOSText.caption2.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context)),
                      ),
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
