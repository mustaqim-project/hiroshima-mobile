// @req FR-POS-01, FR-POS-02, FR-POS-03, FR-POS-04, FR-POS-05, FR-POS-05a, FR-POS-06, FR-POS-07, FR-POS-14, FR-POS-16, FR-POS-17, FR-OFF-01, FR-OFF-02, FR-OFF-03, FR-OFF-04, FR-OFF-05, FSD-06, FSD-07, FSD-08, FSD-10, FSD-14
// Apple HIG Multi-Platform POS Screen for Hiroshima Japanese Street Food
// Responsive Phone + Tablet (iOS + Android) · 100% Dynamic Backend Data · Panda POS Bluetooth Thermal Print

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/pricing/order_calculator.dart';
import '../../../core/printing/pos_printer_sheet.dart';
import '../../../core/printing/thermal_printer_service.dart';
import '../../../core/security/pin_verifier.dart';
import '../../../core/sync/pos_server_config_sheet.dart';
import '../../../core/sync/pos_sync_service.dart';
import '../../../core/theme/ios_adaptive.dart';
import '../../../core/theme/ios_components.dart';
import '../../../core/theme/ios_tokens.dart';
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
  String _selectedOrderType = 'Dine In';
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
    return (b['name'] as String?) ?? 'Hiroshima Pusat';
  }

  // Dynamic Order Types from Backend (ensures at least 2 for CupertinoSlidingSegmentedControl)
  List<String> get _availableOrderTypes {
    final ot = PosSyncService.instance.orderTypes;
    if (ot.length >= 2) {
      return ot.map((e) => e['name'] as String).toList();
    }
    return ['Dine In', 'Take Away', 'Delivery'];
  }

  int get _selectedOrderTypeId {
    final otList = PosSyncService.instance.orderTypes;
    final matchedOt = otList.firstWhere(
      (ot) => (ot['name'] as String).toLowerCase() == _selectedOrderType.toLowerCase(),
      orElse: () => {'id': 1},
    );
    return (matchedOt['id'] as num?)?.toInt() ?? 1;
  }

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
        'price': (p['price'] as num?)?.toInt() ?? 25000,
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
      defaultPrice: (product['price'] as num?)?.toInt() ?? 25000,
    );
  }

  void _onOrderTypeChanged(String newType) {
    setState(() {
      _selectedOrderType = newType;
      // Recalculate price in active cart items to match new order type
      for (final item in _cart) {
        final pId = item['id'];
        item['price'] = PosSyncService.instance.getProductPrice(
          pId,
          _selectedOrderTypeId,
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
              Text('Alasan: $reason', style: const TextStyle(fontWeight: FontWeight.bold, color: IOSColors.accentLight)),
              const SizedBox(height: 8),
              const Text('Masukkan 6-digit PIN Supervisor / Kepala Cabang:'),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                placeholder: 'PIN 6 Angka',
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
    if (dismissCurrentModal) {
      Navigator.pop(context);
    }
    PosPaymentSheet.show(
      context: context,
      cart: _cart,
      calculation: _calculation,
      orderType: _selectedOrderType,
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

  void _showCashierMenu(BuildContext context) {
    final user = PosSyncService.instance.currentUser;
    final userName = user?['name'] as String? ?? 'Kasir Cikini';
    final userRole = user?['role'] as String? ?? 'cashier';

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text(userName, style: IOSText.headline),
        message: Text('Peran: $userRole · Cabang: $_branchName', style: IOSText.caption1),
        actions: <CupertinoActionSheetAction>[
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
              PosServerConfigSheet.show(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.cloud_download, size: 20),
                SizedBox(width: 8),
                Text('Pengaturan Server Backend'),
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
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: IOSColors.accent.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('H', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(width: 8),
            Text('HIROSHIMA POS', style: IOSText.headline.copyWith(fontWeight: FontWeight.w800)),
            if (isTablet) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: IOSColors.systemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.building_2_fill, size: 12, color: IOSColors.secondaryLabel.resolveFrom(context)),
                    const SizedBox(width: 4),
                    Text(_branchName, style: IOSText.caption1.copyWith(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              // Shift Management Button (Open / Close Cashier Shift)
              IOSIconButton(
                icon: CupertinoIcons.money_dollar_circle_fill,
                semanticLabel: 'Kelola Shift Kasir',
                color: syncService.hasActiveShift ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
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

              // Backend Server Configuration Button
              IOSIconButton(
                icon: CupertinoIcons.cloud_download,
                semanticLabel: 'Pengaturan Server Backend',
                onPressed: () => PosServerConfigSheet.show(context),
              ),
              const SizedBox(width: 8),
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
                    const Icon(CupertinoIcons.person_crop_circle_fill, size: 16, color: Color(0xFFDC2626)),
                    if (isTablet) ...[
                      const SizedBox(width: 6),
                      Text(
                        PosSyncService.instance.currentUser?['name'] ?? 'Kasir',
                        style: IOSText.caption1.copyWith(fontWeight: FontWeight.w600),
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
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoActivityIndicator(radius: 14),
                          SizedBox(height: 12),
                          Text('Mengambil data katalog dari backend...'),
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
                            Text('Tidak ada menu ditemukan dari backend', style: IOSText.headline),
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
                                const SizedBox(width: 8),
                                IOSButton(
                                  label: 'Atur URL Server',
                                  icon: CupertinoIcons.gear,
                                  variant: IOSButtonVariant.plain,
                                  onPressed: () => PosServerConfigSheet.show(context),
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
    final price = _getPriceFor(product);
    final hasVariants = product['has_variants'] == true || ((product['variants'] as List?)?.isNotEmpty ?? false);
    final modifierGroups = (product['modifier_groups'] as List?) ?? [];

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _handleProductTap(product),
      child: Container(
        decoration: BoxDecoration(
          color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
          borderRadius: IOSRadius.cardRadius,
          border: Border.all(
            color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.35),
            width: 0.6,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Category Tag & Variants Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: IOSColors.systemFill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: IOSText.caption2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: IOSColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ),
                const Spacer(),
                if (hasVariants)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: IOSColors.info.resolveFrom(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Varian',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: IOSColors.info.resolveFrom(context),
                      ),
                    ),
                  )
                else if (modifierGroups.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: IOSColors.warning.resolveFrom(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Kustom',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: IOSColors.warning.resolveFrom(context),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Product Name
            Expanded(
              child: Text(
                name,
                style: IOSText.subhead.copyWith(fontWeight: FontWeight.bold, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Price & Add Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _currency.format(price),
                      style: IOSText.tabular(IOSText.headline).copyWith(
                        fontWeight: FontWeight.w800,
                        color: IOSColors.accent.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: IOSColors.accent.resolveFrom(context).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.add,
                    size: 16,
                    color: IOSColors.accent.resolveFrom(context),
                  ),
                ),
              ],
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
                Text('Pesanan Berjalan', style: IOSText.headline.copyWith(fontWeight: FontWeight.w800)),
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
                const Spacer(),
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

          // Order Types Segmented Control (Dine In, Take Away, Delivery)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _selectedOrderType,
                children: {
                  for (final ot in _availableOrderTypes)
                    ot: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(ot, style: IOSText.caption1.copyWith(fontWeight: FontWeight.w600)),
                    ),
                },
                onValueChanged: (val) {
                  if (val != null) _onOrderTypeChanged(val);
                },
              ),
            ),
          ),

          // Table Selector (if Dine In)
          if (_selectedOrderType.toLowerCase().contains('dine')) ...[
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

                // Action Buttons: One filled button per screen rule
                Row(
                  children: [
                    Expanded(
                      child: IOSButton(
                        label: 'Diskon',
                        icon: CupertinoIcons.tag,
                        variant: IOSButtonVariant.tinted,
                        onPressed: _cart.isEmpty ? null : _openDiscountDialog,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: IOSButton(
                        label: 'Bayar & Cetak',
                        icon: CupertinoIcons.printer_fill,
                        variant: IOSButtonVariant.filled,
                        onPressed: _cart.isEmpty
                            ? null
                            : () => _openPayment(dismissCurrentModal: isModalSheet),
                      ),
                    ),
                  ],
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
                  '${_cart.length} item • $_selectedOrderType',
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
