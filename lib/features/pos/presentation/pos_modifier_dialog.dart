// @req FR-POS-04, FR-POS-05, FR-POS-05a, FSD-08
// Apple HIG Variant and Modifier Customization Sheet for Hiroshima POS

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/ios_tokens.dart';
import '../../../../core/theme/ios_components.dart';
import '../../../../core/sync/pos_sync_service.dart';

class PosModifierDialog extends StatefulWidget {
  const PosModifierDialog({
    super.key,
    required this.product,
    required this.initialPrice,
    this.orderTypeId,
    required this.onAddToCart,
  });

  final Map<String, dynamic> product;
  final int initialPrice;
  final int? orderTypeId;
  final Function(Map<String, dynamic>? variant, List<Map<String, dynamic>> modifiers) onAddToCart;

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> product,
    required int initialPrice,
    int? orderTypeId,
    required Function(Map<String, dynamic>? variant, List<Map<String, dynamic>> modifiers) onAddToCart,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PosModifierDialog(
        product: product,
        initialPrice: initialPrice,
        orderTypeId: orderTypeId,
        onAddToCart: onAddToCart,
      ),
    );
  }

  @override
  State<PosModifierDialog> createState() => _PosModifierDialogState();
}

class _PosModifierDialogState extends State<PosModifierDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  Map<String, dynamic>? _selectedVariant;
  final Map<int, List<Map<String, dynamic>>> _selectedModsByGroup = {};

  List<dynamic> get _variants => (widget.product['variants'] as List<dynamic>?) ?? [];
  List<dynamic> get _modifierGroups =>
      ((widget.product['modifier_groups'] ?? widget.product['modifierGroups']) as List<dynamic>?) ?? [];

  @override
  void initState() {
    super.initState();
    // Pre-select first variant if variants exist
    if (_variants.isNotEmpty) {
      _selectedVariant = _variants.first as Map<String, dynamic>;
    }

    // Pre-select first modifier for required single-choice groups
    for (final g in _modifierGroups) {
      final gId = (g['id'] as num?)?.toInt() ?? 0;
      final isSingle = (g['selection_type'] ?? 'single') == 'single';
      final isRequired = g['is_required'] == true;
      final mods = (g['modifiers'] as List<dynamic>?) ?? [];

      if (isRequired && isSingle && mods.isNotEmpty) {
        _selectedModsByGroup[gId] = [mods.first as Map<String, dynamic>];
      }
    }
  }

  int _getVariantPrice(Map<String, dynamic> v) {
    if (widget.orderTypeId != null) {
      return PosSyncService.instance.getProductPrice(
        v['id'],
        widget.orderTypeId,
        sellableType: 'variant',
        defaultPrice: (v['price'] as num?)?.toInt() ?? widget.initialPrice,
      );
    }
    return (v['price'] as num?)?.toInt() ?? widget.initialPrice;
  }

  int get _calculatedPrice {
    int base = _selectedVariant != null
        ? _getVariantPrice(_selectedVariant!)
        : widget.initialPrice;

    int modExtra = 0;
    for (final mods in _selectedModsByGroup.values) {
      for (final m in mods) {
        modExtra += ((m['price'] ?? m['unit_price'] ?? 0) as num).toInt();
      }
    }
    return base + modExtra;
  }

  String? get _validationError {
    for (final g in _modifierGroups) {
      final gId = (g['id'] as num?)?.toInt() ?? 0;
      final gName = g['name'] as String? ?? 'Pilihan';
      final isRequired = g['is_required'] == true;
      final selected = _selectedModsByGroup[gId] ?? [];

      if (isRequired && selected.isEmpty) {
        return 'Wajib memilih salah satu opsi untuk "$gName".';
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _allSelectedModifiers {
    final List<Map<String, dynamic>> res = [];
    for (final list in _selectedModsByGroup.values) {
      res.addAll(list);
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final pName = widget.product['name'] as String? ?? 'Menu';
    final pCategory = widget.product['category'] as String? ?? 'Menu';
    final error = _validationError;
    final isValid = error == null;

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

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pName, style: IOSText.headline.copyWith(color: IOSColors.label.resolveFrom(context))),
                        Text(
                          pCategory,
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

            // Scrollable Options
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Variants Section
                    if (_variants.isNotEmpty) ...[
                      Text(
                        'PILIHAN PORSI / VARIAN',
                        style: IOSText.caption1.copyWith(
                          fontWeight: FontWeight.bold,
                          color: IOSColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      IOSGroupedCard(
                        children: [
                          for (int i = 0; i < _variants.length; i++) ...[
                            if (i > 0)
                              Container(
                                height: 0.5,
                                margin: const EdgeInsets.only(left: 16),
                                color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.4),
                              ),
                            Builder(
                              builder: (_) {
                                final v = _variants[i] as Map<String, dynamic>;
                                final isSel = _selectedVariant?['id'] == v['id'];
                                final vPrice = _getVariantPrice(v);

                                return CupertinoListTile(
                                  onTap: () {
                                    setState(() => _selectedVariant = v);
                                  },
                                  title: Text(v['name'] as String, style: IOSText.body.copyWith(color: IOSColors.label.resolveFrom(context))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_currency.format(vPrice), style: IOSText.tabular(IOSText.subhead).copyWith(color: IOSColors.label.resolveFrom(context))),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isSel ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                                        color: isSel ? IOSColors.accent.resolveFrom(context) : CupertinoColors.systemGrey4,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Modifier Groups Section
                    for (final g in _modifierGroups) ...[
                      Builder(
                        builder: (_) {
                          final gId = (g['id'] as num?)?.toInt() ?? 0;
                          final gName = g['name'] as String? ?? 'Pilihan';
                          final isSingle = (g['selection_type'] ?? 'single') == 'single';
                          final isRequired = g['is_required'] == true;
                          final mods = (g['modifiers'] as List<dynamic>?) ?? [];
                          final selected = _selectedModsByGroup[gId] ?? [];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      gName.toUpperCase(),
                                      style: IOSText.caption1.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: IOSColors.secondaryLabel.resolveFrom(context),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isRequired
                                            ? IOSColors.destructive.resolveFrom(context).withValues(alpha: 0.12)
                                            : IOSColors.systemFill.resolveFrom(context),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isRequired ? 'Wajib (1)' : 'Opsional',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isRequired
                                              ? IOSColors.destructive.resolveFrom(context)
                                              : IOSColors.secondaryLabel.resolveFrom(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                IOSGroupedCard(
                                  children: [
                                    for (int i = 0; i < mods.length; i++) ...[
                                      if (i > 0)
                                        Container(
                                          height: 0.5,
                                          margin: const EdgeInsets.only(left: 16),
                                          color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.4),
                                        ),
                                      Builder(
                                        builder: (_) {
                                          final m = mods[i] as Map<String, dynamic>;
                                          final mId = (m['id'] as num?)?.toInt() ?? 0;
                                          final mName = m['name'] as String? ?? '';
                                          final mPrice = ((m['price'] ?? m['unit_price'] ?? 0) as num).toInt();
                                          final isSel = selected.any((s) => (s['id'] ?? s['modifier_id']) == mId);

                                          return CupertinoListTile(
                                            onTap: () {
                                              setState(() {
                                                if (isSingle) {
                                                  _selectedModsByGroup[gId] = [m];
                                                } else {
                                                  if (isSel) {
                                                    _selectedModsByGroup[gId] = selected.where((s) => (s['id'] ?? s['modifier_id']) != mId).toList();
                                                  } else {
                                                    _selectedModsByGroup[gId] = [...selected, m];
                                                  }
                                                }
                                              });
                                            },
                                            title: Text(mName, style: IOSText.body.copyWith(color: IOSColors.label.resolveFrom(context))),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  mPrice > 0 ? '+${_currency.format(mPrice)}' : 'Gratis',
                                                  style: IOSText.tabular(IOSText.footnote).copyWith(
                                                    color: mPrice > 0 ? IOSColors.label.resolveFrom(context) : IOSColors.success.resolveFrom(context),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  isSingle
                                                      ? (isSel ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle)
                                                      : (isSel ? CupertinoIcons.checkmark_square_fill : CupertinoIcons.square),
                                                  color: isSel ? IOSColors.accent.resolveFrom(context) : CupertinoColors.systemGrey4,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    if (error != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: IOSColors.destructive.resolveFrom(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 16, color: IOSColors.destructive.resolveFrom(context)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error,
                                style: IOSText.caption1.copyWith(
                                  color: IOSColors.destructive.resolveFrom(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Footer Bottom Summary Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
                border: Border(
                  top: BorderSide(
                    color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total Harga Item',
                          style: IOSText.caption2.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context)),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _currency.format(_calculatedPrice),
                            style: IOSText.tabular(IOSText.title2).copyWith(
                              fontWeight: FontWeight.w800,
                              color: IOSColors.accent.resolveFrom(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IOSButton(
                    label: 'Tambahkan',
                    icon: CupertinoIcons.cart_badge_plus,
                    variant: IOSButtonVariant.filled,
                    onPressed: isValid
                        ? () {
                            Navigator.pop(context);
                            widget.onAddToCart(_selectedVariant, _allSelectedModifiers);
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
