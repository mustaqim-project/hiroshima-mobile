// @req FSD-06, FR-POS-05, FR-POS-05a, FR-POS-06, FR-POS-07, RPT-01, RPT-08

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/pricing/order_calculator.dart';

void main() {
  group('OrderCalculator Parity Tests (Matching PHP Backend)', () {
    test('Parity Case 1: Tax exclusive + Service Charge + Rounding nearest 100', () {
      // Subtotal: 100.000, Promo: 10.000, Manual discount: 5.000 -> Taxable Base: 85.000
      // Service 5%: 4.250 -> Base with service: 89.250
      // Tax 11%: 89.250 * 0.11 = 9.818
      // Unrounded: 99.068
      // Round nearest 100: +32 -> Total: 99.100
      final result = OrderCalculator.calculate(
        subtotal: 100000,
        promoDiscount: 10000,
        voucherDiscount: 0,
        loyaltyDiscount: 0,
        manualDiscount: 5000,
        taxPercent: 11.0,
        serviceChargePercent: 5.0,
        taxIncluded: false,
        roundingMode: 'round_nearest_100',
      );

      expect(result.taxableBase, 85000);
      expect(result.serviceChargeAmount, 4250);
      expect(result.taxAmount, 9818);
      expect(result.unroundedTotal, 99068);
      expect(result.roundingAmount, 32);
      expect(result.totalAmount, 99100);
    });

    test('Parity Case 2: Tax inclusive (Extracted tax)', () {
      // Subtotal: 111.000, Discount: 0, Tax 11% inclusive, Service 0%
      // Base: 111.000 / 1.11 = 100.000 Net
      // Tax: 11.000
      // Total: 111.000
      final result = OrderCalculator.calculate(
        subtotal: 111000,
        promoDiscount: 0,
        voucherDiscount: 0,
        loyaltyDiscount: 0,
        manualDiscount: 0,
        taxPercent: 11.0,
        serviceChargePercent: 0.0,
        taxIncluded: true,
        roundingMode: 'round_nearest_100',
      );

      expect(result.taxableBase, 111000);
      expect(result.taxAmount, 11000);
      expect(result.totalAmount, 111000);
    });

    test('Parity Case 3: Discount exceeds subtotal is capped', () {
      final result = OrderCalculator.calculate(
        subtotal: 50000,
        promoDiscount: 40000,
        voucherDiscount: 20000,
        loyaltyDiscount: 0,
        manualDiscount: 0,
        taxPercent: 11.0,
        serviceChargePercent: 0.0,
        taxIncluded: false,
        roundingMode: 'round_nearest_100',
      );

      expect(result.totalDiscount, 50000);
      expect(result.taxableBase, 0);
      expect(result.totalAmount, 0);
    });
  });
}
