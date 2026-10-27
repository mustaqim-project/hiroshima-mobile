// @req FR-POS-01, FR-POS-02, FR-POS-03, FR-POS-04, FR-POS-05, FR-POS-05a, FR-POS-06, FR-POS-07, FR-POS-14, FR-POS-16, FR-POS-17, FR-OFF-01, FR-OFF-02, FR-OFF-03, FR-OFF-04, FR-OFF-05, FSD-06, FSD-07, FSD-08, FSD-10, FSD-14
// Apple HIG Multi-Platform POS Screen for Hiroshima Japanese Street Food
// Responsive Phone + Tablet (iOS + Android) · 100% Dynamic Backend Data · Panda POS Bluetooth Thermal Print

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ScaffoldMessenger, SnackBar, Theme;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/pricing/order_calculator.dart';
import '../../../core/printing/pos_printer_sheet.dart';
import '../../../core/printing/thermal_printer_service.dart';
import '../../../core/security/pin_verifier.dart';
import '../../../core/sync/pos_sync_service.dart';
import '../../../core/theme/ios_adaptive.dart';
import '../../../core/theme/ios_components.dart';
import '../../../core/theme/ios_tokens.dart';
import '../../../core/theme/pos_product_image.dart';
import '../../../core/theme/theme_controller.dart';
import 'pos_modifier_dialog.dart';
import 'pos_payment_sheet.dart';
import 'pos_shift_sheet.dart';
import '../../auth/presentation/pos_login_screen.dart';

class PosTabletScreen extends StatefulWidget {
  const PosTabletScreen({super.key});

  @override
  State<PosTabletScreen> createState() => _PosTabletScreenState();
}

class _PosTabletScreenState extends State<PosTabletScreen> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final TextEditingController _searchController = TextEditingController();

  // Active POS state
  int? _selectedOrderTypeIdState;
  String _selectedCategory = 'Semua';
  String? _selectedTableNo;
  int _manualDiscount = 0;

  // Cart: [{ 'id', 'name', 'price', 'qty', 'variant_id', 'variant_name', 'modifiers', 'notes' }]
  final List<Map<String, dynamic>> _cart = [];

  @override
  void initState() {
    super.initState();
    PosSyncService.instance.addListener(_onSyncChange);
    ThermalPrinterService.instance.addListener(_onPrinterChange);

    // Initial backend fetch & auto-sync start
    PosSyncService.instance.fetchCatalog();
    PosSyncService.instance.startAutoSync();
  }

  @override
  void dispose() {
    PosSyncService.instance.stopAutoSync();
    PosSyncService.instance.removeListener(_onSyncChange);
    ThermalPrinterService.instance.removeListener(_onPrinterChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onSyncChange() {
    if (mounted) setState(() {});
  }

  void _onPrinterChange() {
    if (mounted) setState(() {});
  }

  // Dynamic Branch info from Backend
  String get _branchName {
    final b = PosSyncService.instance.branch;
    return (b['name'] as String?) ?? PosSyncService.instance.appName;
  }

  // Dynamic Order Types from Backend (100% API driven, Zero Hardcode & Zero Dummy)
  List<Map<String, dynamic>> get _availableOrderTypes {
    return PosSyncService.instance.orderTypes;
  }

  Map<String, dynamic> get _activeOrderType {
    final list = _availableOrderTypes;
    if (list.isEmpty) {
      return {'id': 1, 'name': 'Pesanan', 'requires_table': false};
    }
    if (_selectedOrderTypeIdState != null) {
      return list.firstWhere(
        (ot) => (ot['id'] as num?)?.toInt() == _selectedOrderTypeIdState,
        orElse: () => list.first,
      );
    }
    final def = list.firstWhere(
      (ot) => ot['is_default'] == true,
      orElse: () => list.first,
    );
    _selectedOrderTypeIdState = (def['id'] as num?)?.toInt() ?? 1;
    return def;
  }

  int get _selectedOrderTypeId => (_activeOrderType['id'] as num?)?.toInt() ?? 1;
  String get _selectedOrderTypeName => (_activeOrderType['name'] as String?) ?? 'Pesanan';
  bool get _requiresTable => _activeOrderType['requires_table'] == true;

  // Dynamic Categories from Backend
  List<Map<String, dynamic>> get _currentCategories {
    final backendCats = PosSyncService.instance.categories;
    if (backendCats.isNotEmpty) {
      return [
        {'name': 'Semua', 'icon': CupertinoIcons.square_grid_2x2},
        ...backendCats.map((c) {
          final name = c['name'] as String;
          final code = c['code'] as String? ?? '';
          IconData icon = CupertinoIcons.tag;
          final lower = name.toLowerCase();
          if (code == 'MNM' || lower.contains('minum') || lower.contains('bev')) {
            icon = CupertinoIcons.drop;
          } else if (code == 'PKT' || lower.contains('paket')) {
            icon = CupertinoIcons.cube_box;
          } else if (code == 'PRM' || lower.contains('promo')) {
            icon = CupertinoIcons.percent;
          } else if (code == 'MKN' || lower.contains('makan')) {
            icon = CupertinoIcons.flame;
          }
          return {'name': name, 'icon': icon};
        }),
      ];
    }
    return [
      {'name': 'Semua', 'icon': CupertinoIcons.square_grid_2x2},
    ];
  }

  // Dynamic Products from Backend
  List<Map<String, dynamic>> get _currentProducts {
    final backendProds = PosSyncService.instance.products;
    final categories = PosSyncService.instance.categories;

    return backendProds.map((p) {
      final catId = p['category_id'];
      final cat = categories.firstWhere(
        (c) => c['id'] == catId,
        orElse: () => {'name': 'Makanan'},
      );

      final hasVariants = p['has_variants'] == true || ((p['variants'] as List?)?.isNotEmpty ?? false);
      final variants = (p['variants'] as List<dynamic>?) ?? [];
      final modifierGroups = ((p['modifier_groups'] ?? p['modifierGroups']) as List<dynamic>?) ?? [];

      return {
        'id': p['id'],
        'name': p['name'] as String,
        'sku': p['sku'] ?? 'SKU-${p['id']}',
        'category': cat['name'] as String,
        'price': (p['price'] as num?)?.toInt() ?? 0,
        'image_path': p['image_path'] ?? p['image_url'],
        'has_variants': hasVariants,
        'variants': variants,
        'modifier_groups': modifierGroups,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final prods = _currentProducts;
    final query = _searchController.text.trim().toLowerCase();

    return prods.where((p) {
      final matchesCategory = _selectedCategory == 'Semua' ||
          (p['category'] as String).toLowerCase() == _selectedCategory.toLowerCase();
      final matchesQuery = query.isEmpty ||
          (p['name'] as String).toLowerCase().contains(query) ||
          (p['sku'] as String).toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  int get _cartSubtotal {
    int sum = 0;
    for (final item in _cart) {
      sum += (item['price'] as int) * (item['qty'] as int);
    }
    return sum;
  }

  OrderCalculationResult get _calculation {
    final branch = PosSyncService.instance.branch;
    final taxPct = double.tryParse(branch['tax_percent']?.toString() ?? '11.0') ?? 11.0;
    final svcPct = double.tryParse(branch['service_charge_percent']?.toString() ?? '0.0') ?? 0.0;
    final taxInc = (branch['tax_included'] as bool?) ?? false;
    final rounding = (branch['rounding_mode'] as String?) ?? 'round_nearest_100';

    return OrderCalculator.calculate(
      subtotal: _cartSubtotal,
      promoDiscount: 0,
      voucherDiscount: 0,
      loyaltyDiscount: 0,
      manualDiscount: _manualDiscount,
      taxPercent: taxPct,
      serviceChargePercent: svcPct,
      taxIncluded: taxInc,
      roundingMode: rounding,
    );
  }

  int _getPriceFor(Map<String, dynamic> product) {
    return PosSyncService.instance.getProductPrice(
      product['id'],
      _selectedOrderTypeId,
      defaultPrice: (product['price'] as num?)?.toInt() ?? 0,
    );
  }

  void _onOrderTypeChanged(int newTypeId) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedOrderTypeIdState = newTypeId;
      if (!_requiresTable) {
        _selectedTableNo = null;
      }
      // Recalculate price in active cart items to match new order type
      for (final item in _cart) {
        final pId = item['id'];
        item['price'] = PosSyncService.instance.getProductPrice(
          pId,
          newTypeId,
          defaultPrice: item['price'] as int,
        );
      }
    });
  }

  void _addToCart(
    Map<String, dynamic> product, {
    Map<String, dynamic>? variant,
    List<Map<String, dynamic>> selectedModifiers = const [],
  }) {
    setState(() {
      final basePrice = variant != null
          ? ((variant['price'] as num?)?.toInt() ?? _getPriceFor(product))
          : _getPriceFor(product);

      final modExtra = selectedModifiers.fold<int>(
        0,
        (sum, m) => sum + ((m['price'] ?? m['unit_price'] ?? 0) as num).toInt(),
      );
      final finalUnitPrice = basePrice + modExtra;

      final variantId = variant?['id'];
      final variantName = variant?['name'];

      final existingIndex = _cart.indexWhere((item) {
        if (item['id'] != product['id']) return false;
        if (item['variant_id'] != variantId) return false;
        final itemMods = (item['modifiers'] as List<dynamic>?) ?? [];
        if (itemMods.length != selectedModifiers.length) return false;
        final itemModIds = itemMods.map((m) => m['modifier_id'] ?? m['id']).toSet();
        final newModIds = selectedModifiers.map((m) => m['modifier_id'] ?? m['id']).toSet();
        return itemModIds.containsAll(newModIds);
      });

      if (existingIndex >= 0) {
        _cart[existingIndex]['qty'] = (_cart[existingIndex]['qty'] as int) + 1;
      } else {
        _cart.add({
          'id': product['id'],
          'name': product['name'],
          'price': finalUnitPrice,
          'qty': 1,
          'variant_id': variantId,
          'variant_name': variantName,
          'modifiers': selectedModifiers,
          'notes': null,
        });
      }
    });
    HapticFeedback.lightImpact();
  }

  void _updateQty(int index, int delta) {
    setState(() {
      final newQty = (_cart[index]['qty'] as int) + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index]['qty'] = newQty;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _handleProductTap(Map<String, dynamic> product) {
    final hasVariants = product['has_variants'] == true || ((product['variants'] as List?)?.isNotEmpty ?? false);
    final modifierGroups = (product['modifier_groups'] as List?) ?? [];

    if (hasVariants || modifierGroups.isNotEmpty) {
      PosModifierDialog.show(
        context: context,
        product: product,
        initialPrice: _getPriceFor(product),
        onAddToCart: (variant, modifiers) {
          _addToCart(product, variant: variant, selectedModifiers: modifiers);
        },
      );
    } else {
      _addToCart(product);
    }
  }

  void _openDiscountDialog() {
    final textController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Input Diskon Manual'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Diskon di atas 10% atau Rp 20.000 wajib otorisasi PIN Diskon Kepala Cabang.',
                style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: textController,
                keyboardType: TextInputType.number,
                placeholder: 'Nominal Potongan (Rp)',
                placeholderStyle: TextStyle(
                  color: CupertinoColors.placeholderText.resolveFrom(context),
                  fontSize: 14,
                ),
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 15,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Batal'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Terapkan'),
            onPressed: () {
              final discount = int.tryParse(textController.text) ?? 0;
              Navigator.pop(ctx);

              final subtotal = _cartSubtotal;
              final percent = subtotal > 0 ? (discount / subtotal) * 100 : 0;

              if (percent > 10.0 || discount > 20000) {
                _promptSupervisorPin(
                  reason: 'Diskon melebihi ambang batas (${_currency.format(discount)})',
                  onAuthorized: () {
                    setState(() => _manualDiscount = discount);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Diskon ${_currency.format(discount)} berhasil diotorisasi PIN.')),
                    );
                  },
                );
              } else {
                setState(() => _manualDiscount = discount);
              }
            },
          ),
        ],
      ),
    );
  }

  void _promptSupervisorPin({required String reason, required VoidCallback onAuthorized}) {
    final pinController = TextEditingController();

    if (PinVerifier.isLocked()) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Otorisasi Terkunci'),
          content: const Text('PIN salah 5 kali beruntun. Coba lagi dalam 15 menit.'),
          actions: [
            CupertinoDialogAction(child: const Text('Tutup'), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Otorisasi Supervisor'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alasan: $reason', style: TextStyle(fontWeight: FontWeight.bold, color: IOSColors.accent.resolveFrom(context))),
              const SizedBox(height: 8),
              const Text('Masukkan 6-digit PIN Supervisor / Kepala Cabang:'),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                placeholder: 'PIN 6 Angka',
                placeholderStyle: TextStyle(
                  color: CupertinoColors.placeholderText.resolveFrom(context),
                  fontSize: 14,
                ),
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 15,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(child: const Text('Batal'), onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Verifikasi'),
            onPressed: () {
              final pin = pinController.text;
              final pinHash = PosSyncService.instance.branch['pin_discount_hash'] as String?;
              final result = PinVerifier.verify(
                enteredPin: pin,
                expectedPinHash: pinHash ?? '123456',
                pinType: 'discount',
              );
              Navigator.pop(ctx);

              if (result.success) {
                onAuthorized();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: CupertinoColors.systemRed, content: Text(result.message)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _openPayment({bool dismissCurrentModal = false}) {
    if (!PosSyncService.instance.hasActiveShift) {
      if (dismissCurrentModal) {
        Navigator.pop(context);
      }
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Shift Kasir Belum Dibuka'),
          content: const Text('Kasir wajib melakukan Open Shift sebelum dapat memproses transaksi POS.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                PosShiftSheet.show(context);
              },
              child: const Text('Buka Shift Sekarang'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      return;
    }

    if (dismissCurrentModal) {
      Navigator.pop(context);
    }
    PosPaymentSheet.show(
      context: context,
      cart: _cart,
      calculation: _calculation,
      orderType: _selectedOrderTypeName,
      orderTypeId: _selectedOrderTypeId,
      tableNo: _selectedTableNo,
      onPaymentSuccess: () {
        setState(() {
          _cart.clear();
          _manualDiscount = 0;
          _selectedTableNo = null;
        });
      },
    );
  }

  void _handleHoldBill() {
    if (_cart.isEmpty) return;

    if (!PosSyncService.instance.hasActiveShift) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Shift Belum Dibuka'),
          content: const Text('Harap buka shift kasir terlebih dahulu sebelum menahan transaksi.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                PosShiftSheet.show(context);
              },
              child: const Text('Buka Shift'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
          ],
        ),
      );
      return;
    }

    if (!PosSyncService.instance.isHoldBillEnabled) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Fitur Hold Bill Dinonaktifkan'),
          content: const Text('Fitur Tahan Pesanan (Hold Bill) dinonaktifkan oleh pengaturan Back Office.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final refController = TextEditingController(text: _selectedTableNo != null ? 'Meja $_selectedTableNo' : '');
    final notesController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Tahan Pesanan (Hold Bill)'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Simpan transaksi ini sementara untuk melayani pelanggan berikutnya.'),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: refController,
                placeholder: 'Label / Nama Pemesan (cth: Meja 4 / Pak Budi)',
                placeholderStyle: TextStyle(
                  color: CupertinoColors.placeholderText.resolveFrom(context),
                  fontSize: 13,
                ),
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 14,
                ),
                padding: const EdgeInsets.all(10),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: notesController,
                placeholder: 'Catatan tambahan (opsional)',
                placeholderStyle: TextStyle(
                  color: CupertinoColors.placeholderText.resolveFrom(context),
                  fontSize: 13,
                ),
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 14,
                ),
                padding: const EdgeInsets.all(10),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final payload = {
                'shift_id': PosSyncService.instance.currentShift?['id'],
                'order_type_id': _selectedOrderTypeId,
                'table_id': _selectedTableNo != null ? int.tryParse(_selectedTableNo!) : null,
                'hold_reference': refController.text.trim().isNotEmpty
                    ? refController.text.trim()
                    : 'Bill ${DateFormat('HH:mm').format(DateTime.now())}',
                'hold_notes': notesController.text.trim(),
                'manual_discount': _manualDiscount,
                'items': _cart.map((item) => {
                  'product_id': item['id'],
                  'product_variant_id': item['variant_id'],
                  'product_name': item['name'],
                  'variant_name': item['variant_name'],
                  'quantity': item['qty'],
                  'unit_price': item['price'],
                  'notes': item['notes'],
                  'modifiers': ((item['modifiers'] as List<dynamic>?) ?? []).map((m) => {
                    'modifier_id': m['modifier_id'] ?? m['id'],
                    'modifier_name': m['name'] ?? m['modifier_name'],
                    'unit_price': m['price'] ?? m['unit_price'] ?? 0,
                    'quantity': 1,
                  }).toList(),
                }).toList(),
              };

              final res = await PosSyncService.instance.holdOrder(payload);
              if (res['success'] == true) {
                HapticFeedback.mediumImpact();
                setState(() {
                  _cart.clear();
                  _manualDiscount = 0;
                  _selectedTableNo = null;
                });
              } else {
                HapticFeedback.heavyImpact();
                if (mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (errCtx) => CupertinoAlertDialog(
                      title: const Text('Gagal Menahan Bill'),
                      content: Text(res['message'] as String? ?? 'Terjadi kesalahan.'),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.pop(errCtx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('Simpan Hold Bill'),
          ),
        ],
      ),
    );
  }

  void _openHoldBillsModal() async {
    await PosSyncService.instance.fetchHeldOrders();

    if (!mounted) return;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final heldList = PosSyncService.instance.heldOrders;

          return Container(
            constraints: const BoxConstraints(maxHeight: 550, maxWidth: 600),
            decoration: BoxDecoration(
              color: IOSColors.groupedBackground.resolveFrom(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(CupertinoIcons.pause_circle_fill, color: IOSColors.warning.resolveFrom(context), size: 22),
                            const SizedBox(width: 8),
                            Text('Daftar Transaksi Ditahan (Hold Bill)', style: IOSText.headline.copyWith(color: IOSColors.label.resolveFrom(context))),
                          ],
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 0.5, color: CupertinoColors.separator.resolveFrom(context)),

                  // Content List
                  Expanded(
                    child: heldList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.checkmark_circle, size: 48, color: CupertinoColors.systemGrey3.resolveFrom(context)),
                                const SizedBox(height: 8),
                                Text('Tidak ada Hold Bill aktif.', style: IOSText.footnote.copyWith(color: CupertinoColors.systemGrey)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: heldList.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, idx) {
                              final bill = heldList[idx];
                              final items = (bill['items'] as List<dynamic>?) ?? [];
                              final total = (bill['total_amount'] as num?)?.toInt() ?? 0;
                              final ref = (bill['hold_reference'] as String?) ?? 'Bill #${bill['order_no']}';
                              final timeStr = bill['held_at'] != null ? DateFormat('HH:mm').format(DateTime.parse(bill['held_at'])) : '-';

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(ref, style: IOSText.headline.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
                                        Text(timeStr, style: IOSText.footnote.copyWith(color: CupertinoColors.systemGrey)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      items.map((i) => '${i['quantity']}x ${i['product_name']}').join(', '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: IOSText.subhead.copyWith(color: CupertinoColors.label.resolveFrom(context)),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _currency.format(total),
                                          style: TextStyle(fontWeight: FontWeight.w800, color: IOSColors.accent.resolveFrom(context), fontSize: 15),
                                        ),
                                        Row(
                                          children: [
                                            CupertinoButton(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              color: CupertinoColors.systemRed.resolveFrom(context).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              onPressed: () {
                                                _promptCancelHoldBill(bill['id'], setModalState);
                                              },
                                              child: Text('Batalkan', style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context), fontSize: 13, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 8),
                                            CupertinoButton(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                              color: IOSColors.accent.resolveFrom(context),
                                              borderRadius: BorderRadius.circular(8),
                                              onPressed: () {
                                                _resumeHoldBill(bill, ctx);
                                              },
                                              child: const Text('Lanjutkan', style: TextStyle(color: CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _resumeHoldBill(Map<String, dynamic> bill, BuildContext modalCtx) async {
    final orderId = bill['id'] as int;
    final res = await PosSyncService.instance.resumeHeldOrder(orderId);

    if (!mounted) return;

    if (res['success'] == true) {
      if (modalCtx.mounted) {
        Navigator.pop(modalCtx);
      }
      final resumedOrder = res['order'] as Map<String, dynamic>;
      final rawItems = (resumedOrder['items'] as List<dynamic>?) ?? [];

      setState(() {
        _cart.clear();
        for (final it in rawItems) {
          final modifiers = ((it['modifiers'] as List<dynamic>?) ?? []).map((m) => {
            'modifier_id': m['modifier_id'],
            'name': m['modifier_name'],
            'price': m['unit_price'],
          }).toList();

          _cart.add({
            'id': it['product_id'],
            'name': it['product_name'],
            'price': it['unit_price'] as int,
            'qty': it['quantity'] as int,
            'variant_id': it['product_variant_id'],
            'variant_name': it['variant_name'],
            'modifiers': modifiers,
            'notes': it['notes'],
          });
        }
        _manualDiscount = (resumedOrder['manual_discount_amount'] as num?)?.toInt() ?? 0;
        _selectedOrderTypeIdState = (resumedOrder['order_type_id'] as num?)?.toInt() ?? _selectedOrderTypeId;
        _selectedTableNo = resumedOrder['table_id']?.toString();
      });
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (errCtx) => CupertinoAlertDialog(
            title: const Text('Gagal Melanjutkan'),
            content: Text(res['message'] as String? ?? 'Terjadi kesalahan.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(errCtx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _promptCancelHoldBill(int orderId, StateSetter setModalState) {
    final reasonController = TextEditingController(text: 'Pelanggan membatalkan pesanan');

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Batalkan Hold Bill'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Masukkan alasan pembatalan (wajib dicatat pada audit log):'),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: reasonController,
                placeholder: 'Alasan pembatalan...',
                padding: const EdgeInsets.all(10),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kembali'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              final res = await PosSyncService.instance.cancelHeldOrder(orderId, reason);
              if (res['success'] == true) {
                setModalState(() {});
              }
            },
            child: const Text('Konfirmasi Batal'),
          ),
        ],
      ),
    );
  }

  void _openTablePicker() {
    final tables = PosSyncService.instance.tables;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: IOSColors.groupedBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: const BoxConstraints(maxHeight: 380, maxWidth: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Pilih Meja (Dine In)', style: IOSText.headline),
            const SizedBox(height: 12),
            Expanded(
              child: tables.isEmpty
                  ? Center(child: Text('Tidak ada konfigurasi meja dari backend.', style: IOSText.footnote))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: tables.length,
                      itemBuilder: (ctx, i) {
                        final t = tables[i];
                        final tNo = (t['table_number'] ?? t['name'] ?? '${i + 1}').toString();
                        final isSel = _selectedTableNo == tNo;

                        return CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: isSel ? IOSColors.accent.resolveFrom(context) : IOSColors.secondaryGroupedBackground.resolveFrom(context),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () {
                            setState(() => _selectedTableNo = tNo);
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            tNo,
                            style: IOSText.headline.copyWith(
                              color: isSel ? CupertinoColors.white : IOSColors.label.resolveFrom(context),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBranchPicker(BuildContext context) {
    if (!PosSyncService.instance.canSwitchBranch) return;

    final branches = PosSyncService.instance.accessibleBranches;
    if (branches.isEmpty) return;

    final activeId = PosSyncService.instance.branch['id'];

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text('Ganti Cabang Operasional', style: IOSText.headline),
        message: Text('Pilih cabang untuk mengalihkan katalog, harga & transaksi', style: IOSText.caption1),
        actions: branches.map((b) {
          final isCurrent = b['id'] == activeId;
          final name = b['name'] as String? ?? 'Cabang';
          final code = b['code'] as String? ?? '';
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              if (!isCurrent) {
                if (_cart.isNotEmpty) {
                  _cart.clear();
                }
                HapticFeedback.mediumImpact();
                await PosSyncService.instance.switchBranch(b);
                if (mounted) {
                  setState(() {});
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCurrent) ...[
                  Icon(CupertinoIcons.checkmark_alt, size: 18, color: IOSColors.success.resolveFrom(context)),
                  const SizedBox(width: 8),
                ],
                Text(
                  '$name ($code)',
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? IOSColors.success.resolveFrom(context) : null,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  void _showCashierMenu(BuildContext context) {
    final user = PosSyncService.instance.currentUser;
    final userName = user?['name'] as String? ?? (user?['username'] as String?) ?? 'Kasir';
    final userRole = user?['role'] as String? ?? 'cashier';

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text(userName, style: IOSText.headline),
        message: Text('Peran: $userRole · Cabang: $_branchName', style: IOSText.caption1),
        actions: <CupertinoActionSheetAction>[
          if (PosSyncService.instance.canSwitchBranch)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _showBranchPicker(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.arrow_2_squarepath, size: 20, color: IOSColors.accent.resolveFrom(context)),
                  const SizedBox(width: 8),
                  Text('Ganti Cabang Operasional', style: TextStyle(fontWeight: FontWeight.w600, color: IOSColors.accent.resolveFrom(context))),
                ],
              ),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              PosShiftSheet.show(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.money_dollar_circle, size: 20),
                SizedBox(width: 8),
                Text('Kelola Shift & Kas Drawer'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              PosPrinterSheet.show(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.printer, size: 20),
                SizedBox(width: 8),
                Text('Printer Kasir Bluetooth'),
              ],
            ),
          ),

          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacement(
                CupertinoPageRoute(builder: (_) => const PosLoginScreen()),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.arrow_2_squarepath, size: 20),
                SizedBox(width: 8),
                Text('Ganti Akun Kasir'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await PosSyncService.instance.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  CupertinoPageRoute(builder: (_) => const PosLoginScreen()),
                );
              }
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.square_arrow_right, size: 20, color: CupertinoColors.destructiveRed),
                SizedBox(width: 8),
                Text('Keluar Sesi POS'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncService = PosSyncService.instance;
    final printerService = ThermalPrinterService.instance;
    final categories = _currentCategories;
    final filteredProds = _filteredProducts;
    final calc = _calculation;
    final isTablet = context.isTablet;

    return CupertinoPageScaffold(
      backgroundColor: IOSColors.groupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoDynamicColor.withBrightness(
          color: const Color(0xF2FFFFFF),
          darkColor: const Color(0xF21C1C1E),
        ),
        border: Border(
          bottom: BorderSide(
            color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/logo_badge.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: IOSColors.accent.resolveFrom(context),
                  alignment: Alignment.center,
                  child: const Text('H', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
            if (isTablet) ...[
              const SizedBox(width: 8),
              Text(PosSyncService.instance.appName, style: IOSText.headline.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: PosSyncService.instance.canSwitchBranch ? () => _showBranchPicker(context) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: PosSyncService.instance.canSwitchBranch
                        ? IOSColors.accent.resolveFrom(context).withValues(alpha: 0.12)
                        : IOSColors.systemFill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                    border: PosSyncService.instance.canSwitchBranch
                        ? Border.all(color: IOSColors.accent.resolveFrom(context).withValues(alpha: 0.35), width: 0.8)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.building_2_fill,
                        size: 12,
                        color: PosSyncService.instance.canSwitchBranch
                            ? IOSColors.accent.resolveFrom(context)
                            : IOSColors.secondaryLabel.resolveFrom(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _branchName,
                        style: IOSText.caption1.copyWith(
                          fontWeight: FontWeight.w600,
                          color: PosSyncService.instance.canSwitchBranch ? IOSColors.accent.resolveFrom(context) : null,
                        ),
                      ),
                      if (PosSyncService.instance.canSwitchBranch) ...[
                        const SizedBox(width: 4),
                        Icon(CupertinoIcons.chevron_down, size: 10, color: IOSColors.accent.resolveFrom(context)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        middle: isTablet
            ? null
            : Text(
                PosSyncService.instance.appName,
                style: IOSText.headline.copyWith(fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dark / Light Theme Toggle Button
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onPressed: () => ThemeController.instance.toggleTheme(context),
              child: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? CupertinoIcons.sun_max_fill
                    : CupertinoIcons.moon_fill,
                size: 20,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFD60A)
                    : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),

            // Dynamic Backend Sync Badge
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                syncService.fetchCatalog();
                syncService.flushOutbox();
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 10 : 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: syncService.isOnline
                      ? IOSColors.success.resolveFrom(context).withValues(alpha: 0.12)
                      : IOSColors.warning.resolveFrom(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: syncService.isOnline
                        ? IOSColors.success.resolveFrom(context).withValues(alpha: 0.5)
                        : IOSColors.warning.resolveFrom(context).withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (syncService.isSyncing)
                      const CupertinoActivityIndicator(radius: 6)
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: syncService.isOnline ? IOSColors.success.resolveFrom(context) : IOSColors.warning.resolveFrom(context),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (isTablet) ...[
                      const SizedBox(width: 6),
                      Text(
                        syncService.isOnline
                            ? (syncService.pendingQueueCount > 0 ? 'Sinkron (${syncService.pendingQueueCount})' : 'Online Backend')
                            : 'Offline (${syncService.pendingQueueCount})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: syncService.isOnline ? IOSColors.success.resolveFrom(context) : IOSColors.warning.resolveFrom(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            if (isTablet) ...[
              // Hold Bills List Button
              IOSIconButton(
                icon: CupertinoIcons.pause_circle_fill,
                semanticLabel: 'Daftar Transaksi Ditahan (Hold Bill)',
                color: syncService.heldOrders.isNotEmpty ? IOSColors.warning.resolveFrom(context) : CupertinoColors.systemGrey,
                badge: syncService.heldOrders.isNotEmpty ? '${syncService.heldOrders.length}' : null,
                onPressed: _openHoldBillsModal,
              ),
              const SizedBox(width: 6),

              // Shift Management Button (Open / Close Cashier Shift)
              IOSIconButton(
                icon: CupertinoIcons.money_dollar_circle_fill,
                semanticLabel: 'Kelola Shift Kasir',
                color: syncService.hasActiveShift ? IOSColors.success.resolveFrom(context) : IOSColors.accent.resolveFrom(context),
                badge: syncService.hasActiveShift ? 'SHIFT' : 'TUTUP',
                onPressed: () => PosShiftSheet.show(context),
              ),
              const SizedBox(width: 6),

              // Bluetooth Thermal Printer Status Button (Panda POS / ESC/POS)
              IOSIconButton(
                icon: CupertinoIcons.printer_fill,
                semanticLabel: 'Pengaturan Printer Bluetooth',
                color: printerService.isConnected ? IOSColors.accent.resolveFrom(context) : CupertinoColors.systemGrey,
                badge: printerService.isConnected ? 'OK' : null,
                onPressed: () => PosPrinterSheet.show(context),
              ),
              const SizedBox(width: 6),

            ] else ...[
              // On phone, keep direct printer access
              IOSIconButton(
                icon: CupertinoIcons.printer_fill,
                semanticLabel: 'Pengaturan Printer Bluetooth',
                color: printerService.isConnected ? IOSColors.accent.resolveFrom(context) : CupertinoColors.systemGrey,
                badge: printerService.isConnected ? 'OK' : null,
                onPressed: () => PosPrinterSheet.show(context),
              ),
              const SizedBox(width: 6),
            ],

            // Cashier User Menu Pill
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showCashierMenu(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: IOSColors.systemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.person_crop_circle_fill, size: 16, color: IOSColors.accent.resolveFrom(context)),
                    if (isTablet) ...[
                      const SizedBox(width: 6),
                      Text(
                        PosSyncService.instance.currentUser?['name'] ?? 'Kasir',
                        style: IOSText.caption1.copyWith(
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_down, size: 11, color: CupertinoColors.systemGrey),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: isTablet
            // ==========================================
            // TABLET SPLIT-VIEW POS (CATALOG + CART PANE)
            // ==========================================
            ? Row(
                children: [
                  // Left Pane: Catalog
                  Expanded(
                    flex: 65,
                    child: _buildCatalogView(categories, filteredProds, isSplitView: true),
                  ),

                  // Hairline Divider
                  Container(
                    width: 0.5,
                    color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.5),
                  ),

                  // Right Pane: Active Order / Cart Bill
                  Expanded(
                    flex: 35,
                    child: _buildCartPanel(calc),
                  ),
                ],
              )
            // ==========================================
            // PHONE ADAPTIVE VIEW (WITH BOTTOM CART PILL)
            // ==========================================
            : Column(
                children: [
                  Expanded(
                    child: _buildCatalogView(categories, filteredProds, isSplitView: false),
                  ),
                  _buildPhoneBottomBar(calc),
                ],
              ),
      ),
    );
  }

  // ───────────────────────── Catalog View ─────────────────────────
  Widget _buildCatalogView(
    List<Map<String, dynamic>> categories,
    List<Map<String, dynamic>> products, {
    required bool isSplitView,
  }) {
    final syncService = PosSyncService.instance;

    return Column(
      children: [
        // Category Pills & Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Cari menu, paket, atau minuman...',
                  style: IOSText.body,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),

        // Categories Horizontal Bar
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final name = cat['name'] as String;
              final icon = cat['icon'] as IconData?;
              final isSel = _selectedCategory == name;

              return IOSChip(
                label: name,
                icon: icon,
                isSelected: isSel,
                onTap: () => setState(() => _selectedCategory = name),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Product Grid or Empty State
        Expanded(
          child: products.isEmpty
              ? (syncService.isSyncing
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CupertinoActivityIndicator(radius: 14),
                          const SizedBox(height: 12),
                          Text(
                            'Mengambil data katalog dari backend...',
                            style: IOSText.footnote.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context)),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.tray, size: 54, color: IOSColors.tertiaryLabel.resolveFrom(context)),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada menu ditemukan dari backend',
                              style: IOSText.headline.copyWith(color: IOSColors.label.resolveFrom(context)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pastikan server backend Laravel aktif dan URL server sesuai.',
                              textAlign: TextAlign.center,
                              style: IOSText.footnote.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context)),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IOSButton(
                                  label: 'Tarik Data Backend',
                                  icon: CupertinoIcons.arrow_clockwise,
                                  variant: IOSButtonVariant.tinted,
                                  onPressed: () => syncService.fetchCatalog(),
                                ),

                              ],
                            ),
                          ],
                        ),
                      ),
                    ))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: iosProductGridDelegate(context: context, isSplitView: isSplitView),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) {
                    final p = products[i];
                    return _buildProductCard(p);
                  },
                ),
        ),
      ],
    );
  }

  // ───────────────────────── Product Card ─────────────────────────
  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] as String;
    final category = product['category'] as String;
    final sku = (product['sku'] as String?)?.trim();
    final price = _getPriceFor(product);
    final hasVariants = product['has_variants'] == true || ((product['variants'] as List?)?.isNotEmpty ?? false);
    final modifierGroups = (product['modifier_groups'] as List?) ?? [];
    final imagePath = product['image_path'] as String? ?? product['image_url'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _handleProductTap(product),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Container with Overlaid Badges (Uncropped, AspectRatio 1.45)
            AspectRatio(
              aspectRatio: 1.45,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: isDark ? const Color(0xFF242426) : const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.all(4),
                    child: PosProductImage(
                      imagePath: imagePath,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      category: category,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                  ),
                  // Category Pill (Top-Left)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark ? CupertinoColors.black.withValues(alpha: 0.75) : CupertinoColors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isDark ? CupertinoColors.white : CupertinoColors.black).withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 9.5,
                          color: isDark ? CupertinoColors.white : const Color(0xFF1E293B),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                  // Variants / Custom Modifiers Pill (Top-Right)
                  if (hasVariants)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Varian',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    )
                  else if (modifierGroups.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Kustom',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Product Info (Name, SKU, Price, and Tactile Add Button)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: IOSColors.label.resolveFrom(context),
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (sku != null && sku.isNotEmpty) ? sku : category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _currency.format(price),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? CupertinoColors.white : const Color(0xFF0F172A),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            CupertinoIcons.plus,
                            size: 16,
                            color: CupertinoColors.white,
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

  // ───────────────────────── Cart / Order Summary Panel ─────────────────────────
  Widget _buildCartPanel(
    OrderCalculationResult calc, {
    bool isModalSheet = false,
    VoidCallback? onClose,
  }) {
    return Container(
      color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
      child: Column(
        children: [
          if (isModalSheet)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

          // Header: Pesanan Berjalan
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Pesanan Berjalan',
                          style: IOSText.headline.copyWith(
                            fontWeight: FontWeight.w800,
                            color: IOSColors.label.resolveFrom(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: IOSColors.accent.resolveFrom(context).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_cart.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: IOSColors.accent.resolveFrom(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_cart.isNotEmpty)
                  CupertinoButton(
                    padding: const EdgeInsets.only(right: 8),
                    onPressed: () {
                      setState(() {
                        _cart.clear();
                        _manualDiscount = 0;
                      });
                    },
                    child: Text('Kosongkan', style: IOSText.footnote.copyWith(color: IOSColors.destructive.resolveFrom(context))),
                  ),
                if (isModalSheet)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onClose ?? () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: IOSColors.systemFill.resolveFrom(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 15,
                        color: IOSColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Order Types Segmented Control (100% Dynamic from Backend API, Zero Hardcode)
          if (_availableOrderTypes.length >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedOrderTypeId,
                  thumbColor: CupertinoDynamicColor.withBrightness(
                    color: CupertinoColors.white,
                    darkColor: const Color(0xFF636366),
                  ).resolveFrom(context),
                  backgroundColor: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  children: {
                    for (final ot in _availableOrderTypes)
                      (ot['id'] as num).toInt(): Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            (ot['name'] as String?) ?? 'Order',
                            style: IOSText.caption1.copyWith(
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ),
                      ),
                  },
                  onValueChanged: (val) {
                    if (val != null) _onOrderTypeChanged(val);
                  },
                ),
              ),
            )
          else if (_availableOrderTypes.length == 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: IOSColors.systemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (_availableOrderTypes.first['name'] as String?) ?? 'Order',
                  style: IOSText.caption1.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),

          // Table Selector (dynamically shown when order type requires table)
          if (_requiresTable) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _openTablePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: IOSColors.groupedBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.square_list, size: 16, color: IOSColors.accentLight),
                      const SizedBox(width: 8),
                      Text(
                        _selectedTableNo != null ? 'Nomor Meja: $_selectedTableNo' : 'Pilih Nomor Meja',
                        style: IOSText.subhead.copyWith(
                          fontWeight: _selectedTableNo != null ? FontWeight.bold : FontWeight.normal,
                          color: IOSColors.label.resolveFrom(context),
                        ),
                      ),
                      const Spacer(),
                      const Icon(CupertinoIcons.chevron_forward, size: 14, color: CupertinoColors.systemGrey),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Container(
            height: 0.5,
            color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.35),
          ),

          // Cart Item List
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.cart, size: 42, color: IOSColors.tertiaryLabel.resolveFrom(context)),
                          const SizedBox(height: 8),
                          Text(
                            'Keranjang kosong.\nSentuh menu untuk menambahkan.',
                            textAlign: TextAlign.center,
                            style: IOSText.footnote.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _cart.length,
                    separatorBuilder: (c, _) => Container(
                      height: 0.5,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: IOSColors.separator.resolveFrom(c).withValues(alpha: 0.3),
                    ),
                    itemBuilder: (ctx, i) {
                      final item = _cart[i];
                      final sub = (item['price'] as int) * (item['qty'] as int);
                      final variantName = item['variant_name'] as String?;
                      final modifiers = (item['modifiers'] as List<dynamic>?) ?? [];

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'] as String, style: IOSText.subhead.copyWith(fontWeight: FontWeight.bold)),
                                if (variantName != null && variantName.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Varian: $variantName',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: IOSColors.info.resolveFrom(context),
                                      ),
                                    ),
                                  ),
                                if (modifiers.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      modifiers.map((m) => '+ ${m['name'] ?? m['modifier_name']}').join(', '),
                                      style: IOSText.caption2.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context)),
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(_currency.format(item['price']), style: IOSText.tabular(IOSText.caption1).copyWith(color: IOSColors.secondaryLabel.resolveFrom(context))),
                              ],
                            ),
                          ),

                          // Quantity Stepper (Apple HIG)
                          Container(
                            decoration: BoxDecoration(
                              color: IOSColors.groupedBackground.resolveFrom(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(32, 32),
                                  onPressed: () => _updateQty(i, -1),
                                  child: const Icon(CupertinoIcons.minus, size: 14),
                                ),
                                Text(
                                  '${item['qty']}',
                                  style: IOSText.tabular(IOSText.subhead).copyWith(fontWeight: FontWeight.bold),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(32, 32),
                                  onPressed: () => _updateQty(i, 1),
                                  child: const Icon(CupertinoIcons.plus, size: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Item Subtotal
                          SizedBox(
                            width: 76,
                            child: Text(
                              _currency.format(sub),
                              textAlign: TextAlign.right,
                              style: IOSText.tabular(IOSText.subhead).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Bill Summary Panel (Pure Sequence FSD-06)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IOSColors.groupedBackground.resolveFrom(context),
              border: Border(
                top: BorderSide(
                  color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: IOSText.footnote),
                    Text(_currency.format(calc.subtotal), style: IOSText.tabular(IOSText.footnote).copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                if (_manualDiscount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Diskon Manual', style: IOSText.footnote.copyWith(color: IOSColors.destructive.resolveFrom(context))),
                      Text('-${_currency.format(_manualDiscount)}', style: IOSText.tabular(IOSText.footnote).copyWith(color: IOSColors.destructive.resolveFrom(context), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pajak (PB1 11%)', style: IOSText.footnote),
                    Text(_currency.format(calc.taxAmount), style: IOSText.tabular(IOSText.footnote)),
                  ],
                ),
                if (calc.roundingAmount != 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pembulatan (Rp 100)', style: IOSText.footnote),
                      Text('${calc.roundingAmount > 0 ? "+" : ""}${_currency.format(calc.roundingAmount)}', style: IOSText.tabular(IOSText.footnote)),
                    ],
                  ),
                ],
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.4),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL BAYAR', style: IOSText.headline.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      _currency.format(calc.totalAmount),
                      style: IOSText.tabular(IOSText.title2).copyWith(
                        fontWeight: FontWeight.w900,
                        color: IOSColors.accent.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Secondary Actions: Hold & Diskon
                Row(
                  children: [
                    Expanded(
                      child: IOSButton(
                        label: 'Hold',
                        icon: CupertinoIcons.pause,
                        variant: IOSButtonVariant.tinted,
                        size: IOSButtonSize.small,
                        expanded: true,
                        onPressed: _cart.isEmpty ? null : _handleHoldBill,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: IOSButton(
                        label: 'Diskon',
                        icon: CupertinoIcons.tag,
                        variant: IOSButtonVariant.tinted,
                        size: IOSButtonSize.small,
                        expanded: true,
                        onPressed: _cart.isEmpty ? null : _openDiscountDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Primary CTA: Bayar & Cetak (Prominent Full Width)
                IOSButton(
                  label: 'Bayar & Cetak',
                  icon: CupertinoIcons.printer_fill,
                  variant: IOSButtonVariant.filled,
                  size: IOSButtonSize.regular,
                  expanded: true,
                  onPressed: _cart.isEmpty
                      ? null
                      : () => _openPayment(dismissCurrentModal: isModalSheet),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Phone Bottom Floating Bar ─────────────────────────
  Widget _buildPhoneBottomBar(OrderCalculationResult calc) {
    if (_cart.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_cart.length} item • $_selectedOrderTypeName',
                  style: IOSText.caption2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currency.format(calc.totalAmount),
                    style: IOSText.tabular(IOSText.headline).copyWith(
                      fontWeight: FontWeight.w900,
                      color: IOSColors.accent.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IOSButton(
            label: 'Bayar',
            icon: CupertinoIcons.cart_fill,
            variant: IOSButtonVariant.filled,
            onPressed: () {
              showCupertinoModalPopup(
                context: context,
                builder: (ctx) => Container(
                  height: MediaQuery.sizeOf(context).height * 0.88,
                  decoration: BoxDecoration(
                    color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: _buildCartPanel(
                    calc,
                    isModalSheet: true,
                    onClose: () => Navigator.pop(ctx),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
