// @req FR-POS-17, FR-PRN-01, FR-PRN-02, FR-PRN-03, FSD-14
// Unit tests for Bluetooth Thermal Printer Service & Dual-Copy ESC/POS generation

import 'package:flutter_test/flutter_test.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/printing/thermal_printer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bluetooth Thermal Printer Service Tests', () {
    final service = ThermalPrinterService.instance;

    test('Initializes with default 58mm paper size for Panda POS printer', () {
      expect(service.paperSize, equals(PaperSize.mm58));
      expect(service.is80mm, isFalse);
    });

    test('Paper size toggle correctly switches between 58mm and 80mm', () async {
      await service.setPaperSize(PaperSize.mm80);
      expect(service.paperSize, equals(PaperSize.mm80));
      expect(service.is80mm, isTrue);

      await service.setPaperSize(PaperSize.mm58);
      expect(service.paperSize, equals(PaperSize.mm58));
      expect(service.is80mm, isFalse);
    });

    test('Auto-print on checkout toggle can be modified and retrieved', () async {
      await service.setAutoPrint(false);
      expect(service.autoPrintOnCheckout, isFalse);

      await service.setAutoPrint(true);
      expect(service.autoPrintOnCheckout, isTrue);
    });

    test('Returns clear error when printing without connected Bluetooth device', () async {
      final res = await service.printTest();
      expect(res.success, isFalse);
      expect(res.message, contains('belum terhubung'));
    });
  });
}
