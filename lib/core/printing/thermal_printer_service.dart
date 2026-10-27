// @req FR-POS-17, FR-PRN-01, FR-PRN-02, FR-PRN-03, FSD-14
// Bluetooth Thermal Printer Service for Hiroshima POS
// Tested and compatible with Panda POS (PRJ-58D / PRJ-80), Iware, Eppos, BellaV, and standard ESC/POS printers.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterResult {
  final bool success;
  final String message;
  final String? error;

  const PrinterResult({
    required this.success,
    required this.message,
    this.error,
  });

  @override
  String toString() => 'PrinterResult(success: $success, message: $message, error: $error)';
}

class ThermalPrinterService extends ChangeNotifier {
  static final ThermalPrinterService instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => instance;
  ThermalPrinterService._internal() {
    _loadSettings();
  }

  static const String _prefKeyMac = 'hiroshima_printer_mac';
  static const String _prefKeyName = 'hiroshima_printer_name';
  static const String _prefKeyPaper = 'hiroshima_printer_paper_size'; // '58' or '80'
  static const String _prefKeyAutoPrint = 'hiroshima_printer_auto_print';

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _connectedMac;
  String? get connectedMac => _connectedMac;

  String? _connectedName;
  String? get connectedName => _connectedName;

  PaperSize _paperSize = PaperSize.mm58;
  PaperSize get paperSize => _paperSize;
  bool get is80mm => _paperSize == PaperSize.mm80;

  bool _autoPrintOnCheckout = true;
  bool get autoPrintOnCheckout => _autoPrintOnCheckout;

  CapabilityProfile? _cachedProfile;

  Future<CapabilityProfile> _getProfile() async {
    if (_cachedProfile != null) return _cachedProfile!;
    try {
      _cachedProfile = await CapabilityProfile.load();
      return _cachedProfile!;
    } catch (_) {
      _cachedProfile = await CapabilityProfile.load(name: 'default');
      return _cachedProfile!;
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _connectedMac = prefs.getString(_prefKeyMac);
      _connectedName = prefs.getString(_prefKeyName);
      final size = prefs.getString(_prefKeyPaper) ?? '58';
      _paperSize = size == '80' ? PaperSize.mm80 : PaperSize.mm58;
      _autoPrintOnCheckout = prefs.getBool(_prefKeyAutoPrint) ?? true;

      // Check current connection status
      await checkConnection();
    } catch (e) {
      debugPrint('[ThermalPrinterService] Error loading settings: $e');
    }
  }

  Future<void> setPaperSize(PaperSize size) async {
    _paperSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyPaper, size == PaperSize.mm80 ? '80' : '58');
    notifyListeners();
  }

  Future<void> setAutoPrint(bool value) async {
    _autoPrintOnCheckout = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAutoPrint, value);
    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      final granted = statuses.values.every((s) => s.isGranted || s.isLimited);
      return granted;
    } catch (e) {
      debugPrint('[ThermalPrinterService] Request permissions error: $e');
      return true; // continue attempt
    }
  }

  Future<bool> isBluetoothEnabled() async {
    if (kIsWeb) return false;
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      debugPrint('[ThermalPrinterService] isBluetoothEnabled error: $e');
      return false;
    }
  }

  Future<bool> checkConnection() async {
    if (kIsWeb) return false;
    try {
      _isConnected = await PrintBluetoothThermal.connectionStatus;
      notifyListeners();
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<BluetoothInfo>> getPairedDevices() async {
    if (kIsWeb) return [];
    try {
      await requestPermissions();
      final bool enabled = await isBluetoothEnabled();
      if (!enabled) return [];
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      debugPrint('[ThermalPrinterService] getPairedDevices error: $e');
      return [];
    }
  }

  Future<PrinterResult> connect(String macAddress, {String? deviceName}) async {
    if (kIsWeb) {
      return const PrinterResult(success: false, message: 'Bluetooth tidak didukung di web browser.');
    }
    if (macAddress.isEmpty) {
      return const PrinterResult(success: false, message: 'Alamat MAC printer kosong.');
    }

    _isConnecting = true;
    notifyListeners();

    try {
      final current = await PrintBluetoothThermal.connectionStatus;
      if (current) {
        await PrintBluetoothThermal.disconnect;
        await Future.delayed(const Duration(milliseconds: 250));
      }

      final success = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      _isConnected = success;
      _isConnecting = false;

      if (success) {
        _connectedMac = macAddress;
        _connectedName = deviceName ?? _connectedName ?? 'Panda POS Printer';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyMac, macAddress);
        if (deviceName != null) {
          await prefs.setString(_prefKeyName, deviceName);
        }
        notifyListeners();
        return PrinterResult(
          success: true,
          message: 'Berhasil terhubung ke printer $_connectedName.',
        );
      } else {
        notifyListeners();
        return const PrinterResult(
          success: false,
          message: 'Gagal terhubung ke printer. Pastikan printer hidup dan Bluetooth aktif.',
        );
      }
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
      return PrinterResult(
        success: false,
        message: 'Koneksi printer gagal: $e',
        error: e.toString(),
      );
    }
  }

  Future<PrinterResult> disconnect() async {
    if (kIsWeb) return const PrinterResult(success: true, message: 'OK');
    try {
      await PrintBluetoothThermal.disconnect;
      _isConnected = false;
      notifyListeners();
      return const PrinterResult(success: true, message: 'Printer terputus.');
    } catch (e) {
      return PrinterResult(success: false, message: 'Gagal memutuskan: $e');
    }
  }

  /// Print ESC/POS Dual-Copy Order Receipts:
  /// Rangkap 1: Customer Receipt (Full financial breakdown)
  /// Rangkap 2: Kitchen Ticket (Item specifications, modifiers, notes, NO prices)
  Future<PrinterResult> printOrderDualCopy({
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
    bool openDrawer = false,
  }) async {
    if (kIsWeb) {
      return const PrinterResult(success: false, message: 'Pencetakan Bluetooth tidak didukung di web.');
    }

    // Auto-reconnect to saved printer if disconnected
    if (!_isConnected && _connectedMac != null && _connectedMac!.isNotEmpty) {
      await connect(_connectedMac!);
    }

    if (!_isConnected) {
      return const PrinterResult(
        success: false,
        message: 'Printer belum terhubung. Silakan hubungkan printer Bluetooth di menu pengaturan printer.',
      );
    }

    try {
      final profile = await _getProfile();
      final generator = Generator(_paperSize, profile);
      final List<int> bytes = [];

      final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(transactionTime);

      // Open Cash Drawer if requested
      if (openDrawer) {
        bytes.addAll(generator.drawer());
      }

      // ========================================================
      // 1. RANGKAP 1: STRUK CUSTOMER (Full Financial Breakdown)
      // ========================================================
      bytes.addAll(generator.reset());
      bytes.addAll(generator.text(
        branchName.toUpperCase(),
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
      ));
      if (branchAddress.isNotEmpty) {
        bytes.addAll(generator.text(branchAddress, styles: const PosStyles(align: PosAlign.center)));
      }
      if (branchPhone.isNotEmpty) {
        bytes.addAll(generator.text('Telp: $branchPhone', styles: const PosStyles(align: PosAlign.center)));
      }
      bytes.addAll(generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('*** RANGKAP 1 - CUSTOMER ***', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center)));

      bytes.addAll(generator.row([
        PosColumn(text: 'No. Struk', width: 4),
        PosColumn(text: ': $orderNo', width: 8),
      ]));
      bytes.addAll(generator.row([
        PosColumn(text: 'Waktu', width: 4),
        PosColumn(text: ': $timeStr WIB', width: 8),
      ]));
      bytes.addAll(generator.row([
        PosColumn(text: 'Kasir', width: 4),
        PosColumn(text: ': $cashierName', width: 8),
      ]));
      bytes.addAll(generator.row([
        PosColumn(text: 'Tipe', width: 4),
        PosColumn(text: ': $orderTypeName', width: 8),
      ]));
      if (tableNo != null && tableNo.isNotEmpty) {
        bytes.addAll(generator.row([
          PosColumn(text: 'Meja', width: 4),
          PosColumn(text: ': $tableNo', width: 8, styles: const PosStyles(bold: true)),
        ]));
      }
      bytes.addAll(generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center)));

      // Items list
      for (final item in items) {
        final name = item['name'] as String;
        final qty = item['qty'] as int;
        final price = item['price'] as int;
        final itemSubtotal = qty * price;

        final variantName = item['variant_name'] as String?;
        final fullName = (variantName != null && variantName.isNotEmpty) ? '$name ($variantName)' : name;

        bytes.addAll(generator.text(fullName, styles: const PosStyles(bold: true)));
        bytes.addAll(generator.row([
          PosColumn(text: '  ${qty}x ${currency.format(price)}', width: 7),
          PosColumn(text: currency.format(itemSubtotal), width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]));

        // Modifiers
        final modifiers = (item['modifiers'] as List<dynamic>?) ?? [];
        for (final m in modifiers) {
          final mName = m['name'] ?? m['modifier_name'] ?? '';
          final mPrice = (m['price'] ?? m['unit_price'] ?? 0) as int;
          final priceStr = mPrice > 0 ? currency.format(mPrice) : 'Gratis';
          bytes.addAll(generator.text('   + $mName ($priceStr)', styles: const PosStyles(fontType: PosFontType.fontB)));
        }
      }

      bytes.addAll(generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.row([
        PosColumn(text: 'Subtotal', width: 6),
        PosColumn(text: currency.format(subtotal), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));

      if (totalDiscount > 0) {
        bytes.addAll(generator.row([
          PosColumn(text: 'Diskon', width: 6),
          PosColumn(text: '-${currency.format(totalDiscount)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]));
      }

      if (serviceChargeAmount > 0) {
        bytes.addAll(generator.row([
          PosColumn(text: 'Service', width: 6),
          PosColumn(text: currency.format(serviceChargeAmount), width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]));
      }

      bytes.addAll(generator.row([
        PosColumn(text: 'Pajak (PB1)', width: 6),
        PosColumn(text: currency.format(taxAmount), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));

      if (roundingAmount != 0) {
        final sign = roundingAmount > 0 ? '+' : '-';
        bytes.addAll(generator.row([
          PosColumn(text: 'Pembulatan', width: 6),
          PosColumn(text: '$sign${currency.format(roundingAmount.abs())}', width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]));
      }

      bytes.addAll(generator.text('================================', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.row([
        PosColumn(text: 'TOTAL BAYAR', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: currency.format(totalAmount), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]));
      bytes.addAll(generator.text('================================', styles: const PosStyles(align: PosAlign.center)));

      for (final p in payments) {
        final method = p['method'] as String? ?? 'Pembayaran';
        final amount = (p['amount'] as num?)?.toInt() ?? totalAmount;
        bytes.addAll(generator.row([
          PosColumn(text: method, width: 6),
          PosColumn(text: currency.format(amount), width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]));
      }

      if (changeAmount > 0) {
        bytes.addAll(generator.row([
          PosColumn(text: 'Kembalian', width: 6),
          PosColumn(text: currency.format(changeAmount), width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]));
      }

      bytes.addAll(generator.feed(1));
      bytes.addAll(generator.text('Terima kasih atas kunjungan Anda', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('Selamat menikmati hidangan!', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.feed(2));
      bytes.addAll(generator.cut());

      // ========================================================
      // 2. RANGKAP 2: TIKET DAPUR / BAR (No Prices, Pure Kitchen Spec)
      // ========================================================
      bytes.addAll(generator.reset());
      bytes.addAll(generator.text('================================', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('*** RANGKAP 2 - DAPUR ***', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1)));
      bytes.addAll(generator.text('================================', styles: const PosStyles(align: PosAlign.center)));

      bytes.addAll(generator.row([
        PosColumn(text: 'Order', width: 4),
        PosColumn(text: ': $orderNo', width: 8, styles: const PosStyles(bold: true)),
      ]));
      bytes.addAll(generator.row([
        PosColumn(text: 'Waktu', width: 4),
        PosColumn(text: ': $timeStr WIB', width: 8),
      ]));
      bytes.addAll(generator.row([
        PosColumn(text: 'Tipe', width: 4),
        PosColumn(text: ': $orderTypeName', width: 8, styles: const PosStyles(bold: true)),
      ]));

      if (tableNo != null && tableNo.isNotEmpty) {
        bytes.addAll(generator.text('>> MEJA : $tableNo <<', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1)));
      }
      bytes.addAll(generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center)));

      for (final item in items) {
        final name = item['name'] as String;
        final qty = item['qty'] as int;
        final variantName = item['variant_name'] as String?;
        final fullName = (variantName != null && variantName.isNotEmpty) ? '$name ($variantName)' : name;

        bytes.addAll(generator.text('${qty}x  $fullName', styles: const PosStyles(bold: true, height: PosTextSize.size1)));

        final notes = item['notes'] as String?;
        if (notes != null && notes.isNotEmpty) {
          bytes.addAll(generator.text('   Catatan: $notes', styles: const PosStyles(bold: true)));
        }

        final modifiers = (item['modifiers'] as List<dynamic>?) ?? [];
        for (final m in modifiers) {
          final mName = m['name'] ?? m['modifier_name'] ?? '';
          bytes.addAll(generator.text('   + $mName', styles: const PosStyles(fontType: PosFontType.fontB)));
        }
        bytes.addAll(generator.feed(1));
      }

      bytes.addAll(generator.text('================================', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.feed(3));
      bytes.addAll(generator.cut());

      // Send bytes via Bluetooth Thermal
      final printSuccess = await PrintBluetoothThermal.writeBytes(bytes);

      if (printSuccess) {
        return const PrinterResult(
          success: true,
          message: 'Struk Rangkap 1 (Customer) dan Rangkap 2 (Dapur) berhasil dicetak ke printer Bluetooth.',
        );
      } else {
        return const PrinterResult(
          success: false,
          message: 'Printer merespon gagal cetak. Periksa kertas dan status baterai printer.',
        );
      }
    } catch (e) {
      return PrinterResult(
        success: false,
        message: 'Gagal mencetak struk: $e',
        error: e.toString(),
      );
    }
  }

  /// Test Print to verify Bluetooth printer connection (Panda POS / ESC/POS)
  Future<PrinterResult> printTest() async {
    if (kIsWeb) {
      return const PrinterResult(success: false, message: 'Bluetooth tidak didukung di web.');
    }

    if (!_isConnected && _connectedMac != null && _connectedMac!.isNotEmpty) {
      await connect(_connectedMac!);
    }

    if (!_isConnected) {
      return const PrinterResult(
        success: false,
        message: 'Printer belum terhubung. Hubungkan printer Bluetooth terlebih dahulu.',
      );
    }

    try {
      final profile = await _getProfile();
      final generator = Generator(_paperSize, profile);
      final List<int> bytes = [];

      bytes.addAll(generator.reset());
      bytes.addAll(generator.text(
        'HIROSHIMA POS',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
      ));
      bytes.addAll(generator.text('Japanese Street Food', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('TES KONEKSI PRINTER BERHASIL', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.text('Tipe Kertas : ${_paperSize == PaperSize.mm80 ? "80 mm" : "58 mm"}', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('Printer     : ${_connectedName ?? "Panda POS"}', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('Waktu       : ${DateFormat("dd/MM/yyyy HH:mm:ss").format(DateTime.now())}', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('Siap digunakan untuk cetak POS!', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.feed(3));
      bytes.addAll(generator.cut());

      final success = await PrintBluetoothThermal.writeBytes(bytes);
      return PrinterResult(
        success: success,
        message: success ? 'Tes cetak struk berhasil dikirim ke printer.' : 'Gagal mengirim perintah tes cetak.',
      );
    } catch (e) {
      return PrinterResult(success: false, message: 'Kesalahan tes cetak: $e', error: e.toString());
    }
  }
}
