// @req FSD-06, FR-POS-05, FR-POS-05a, FR-POS-06, FR-POS-07, RPT-01, RPT-08

import 'dart:math';

class OrderCalculationResult {
  final int subtotal;
  final int promoDiscount;
  final int voucherDiscount;
  final int loyaltyDiscount;
  final int manualDiscount;
  final int totalDiscount;
  final int taxableBase;
  final int serviceChargeAmount;
  final int taxAmount;
  final int unroundedTotal;
  final int roundingAmount;
  final int totalAmount;

  const OrderCalculationResult({
    required this.subtotal,
    required this.promoDiscount,
    required this.voucherDiscount,
    required this.loyaltyDiscount,
    required this.manualDiscount,
    required this.totalDiscount,
    required this.taxableBase,
    required this.serviceChargeAmount,
    required this.taxAmount,
    required this.unroundedTotal,
    required this.roundingAmount,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() => {
    'subtotal': subtotal,
    'promo_discount': promoDiscount,
    'voucher_discount': voucherDiscount,
    'loyalty_discount': loyaltyDiscount,
    'manual_discount': manualDiscount,
    'total_discount': totalDiscount,
    'taxable_base': taxableBase,
    'service_charge_amount': serviceChargeAmount,
    'tax_amount': taxAmount,
    'unrounded_total': unroundedTotal,
    'rounding_amount': roundingAmount,
    'total_amount': totalAmount,
  };
}

/// OrderCalculator pure class in Dart matching PHP backend OrderCalculator with 100% parity.
class OrderCalculator {
  static OrderCalculationResult calculate({
    required int subtotal,
    required int promoDiscount,
    required int voucherDiscount,
    required int loyaltyDiscount,
    required int manualDiscount,
    required double taxPercent,
    required double serviceChargePercent,
    required bool taxIncluded,
    required String roundingMode, // round_nearest_100, round_down_100, round_up_100
  }) {
    // 1. Total discounts cannot exceed subtotal
    final totalDiscount = min(subtotal, promoDiscount + voucherDiscount + loyaltyDiscount + manualDiscount);
    final taxableBase = max(0, subtotal - totalDiscount);

    final serviceRate = serviceChargePercent / 100.0;
    final taxRate = taxPercent / 100.0;

    int serviceChargeAmount = 0;
    int taxAmount = 0;
    int unroundedTotal = 0;

    if (taxIncluded) {
      // Extracted tax and service charge
      final combinedRate = 1.0 + serviceRate + taxRate;
      final netAmount = (taxableBase / combinedRate).round();
      serviceChargeAmount = (netAmount * serviceRate).round();
      taxAmount = taxableBase - netAmount - serviceChargeAmount;
      unroundedTotal = taxableBase;
    } else {
      // Added tax and service charge
      serviceChargeAmount = (taxableBase * serviceRate).round();
      taxAmount = ((taxableBase + serviceChargeAmount) * taxRate).round();
      unroundedTotal = taxableBase + serviceChargeAmount + taxAmount;
    }

    // 2. Rounding logic (default: round_nearest_100)
    int roundingAmount = 0;
    int finalTotal = unroundedTotal;

    if (roundingMode == 'round_nearest_100') {
      final remainder = unroundedTotal % 100;
      if (remainder != 0) {
        if (remainder < 50) {
          roundingAmount = -remainder; // Round down
        } else {
          roundingAmount = 100 - remainder; // Round up
        }
      }
      finalTotal = unroundedTotal + roundingAmount;
    } else if (roundingMode == 'round_down_100') {
      final remainder = unroundedTotal % 100;
      if (remainder != 0) {
        roundingAmount = -remainder;
      }
      finalTotal = unroundedTotal + roundingAmount;
    } else if (roundingMode == 'round_up_100') {
      final remainder = unroundedTotal % 100;
      if (remainder != 0) {
        roundingAmount = 100 - remainder;
      }
      finalTotal = unroundedTotal + roundingAmount;
    }

    return OrderCalculationResult(
      subtotal: subtotal,
      promoDiscount: promoDiscount,
      voucherDiscount: voucherDiscount,
      loyaltyDiscount: loyaltyDiscount,
      manualDiscount: manualDiscount,
      totalDiscount: totalDiscount,
      taxableBase: taxableBase,
      serviceChargeAmount: serviceChargeAmount,
      taxAmount: taxAmount,
      unroundedTotal: unroundedTotal,
      roundingAmount: roundingAmount,
      totalAmount: max(0, finalTotal),
    );
  }
}
