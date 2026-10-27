// @req FR-POS-01, FR-POS-02, FSD-20
// Apple HIG Reusable Components for Hiroshima POS (iOS + Android)

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'ios_tokens.dart';

enum IOSButtonVariant { filled, tinted, plain }
enum IOSButtonSize { regular, small }

/// Apple HIG Button adhering to 3 kinds x 2 sizes + destructive modifier
class IOSButton extends StatelessWidget {
  const IOSButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = IOSButtonVariant.filled,
    this.size = IOSButtonSize.regular,
    this.icon,
    this.isDestructive = false,
    this.isLoading = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IOSButtonVariant variant;
  final IOSButtonSize size;
  final IconData? icon;
  final bool isDestructive;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final accent = isDestructive ? IOSColors.destructive : IOSColors.accent;
    final resolvedAccent = accent.resolveFrom(context);

    final height = switch (size) {
      IOSButtonSize.regular => 50.0,
      IOSButtonSize.small => 36.0,
    };

    final horizontalPadding = switch (size) {
      IOSButtonSize.regular => 20.0,
      IOSButtonSize.small => 12.0,
    };

    final textStyle = switch (size) {
      IOSButtonSize.regular => IOSText.headline,
      IOSButtonSize.small => IOSText.subhead.copyWith(fontWeight: FontWeight.w600),
    };

    Color bgColor;
    Color fgColor;

    switch (variant) {
      case IOSButtonVariant.filled:
        bgColor = enabled ? resolvedAccent : CupertinoColors.systemGrey4.resolveFrom(context);
        fgColor = CupertinoColors.white;
        break;
      case IOSButtonVariant.tinted:
        bgColor = enabled
            ? resolvedAccent.withValues(alpha: 0.12)
            : CupertinoColors.systemGrey6.resolveFrom(context);
        fgColor = enabled ? resolvedAccent : CupertinoColors.secondaryLabel.resolveFrom(context);
        break;
      case IOSButtonVariant.plain:
        bgColor = CupertinoColors.transparent;
        fgColor = enabled ? resolvedAccent : CupertinoColors.secondaryLabel.resolveFrom(context);
        break;
    }

    Widget content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          CupertinoActivityIndicator(
            color: variant == IOSButtonVariant.filled ? CupertinoColors.white : fgColor,
            radius: size == IOSButtonSize.small ? 8 : 10,
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: size == IOSButtonSize.small ? 16 : 18, color: fgColor),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: textStyle.copyWith(color: fgColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: IOSPlatform.minTarget,
        minWidth: expanded ? double.infinity : 60.0,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        pressedOpacity: 0.75,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(IOSRadius.button),
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}

/// Apple HIG Icon Button with touch target safety
class IOSIconButton extends StatelessWidget {
  const IOSIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.size = 20.0,
    this.color,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double size;
  final Color? color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IOSColors.label.resolveFrom(context);
    final target = IOSPlatform.minTarget;

    Widget iconWidget = Icon(icon, size: size, color: effectiveColor);

    if (badge != null && badge!.isNotEmpty) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: IOSColors.destructive.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      label: semanticLabel,
      button: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size(target, target),
        onPressed: onPressed != null
            ? () {
                HapticFeedback.selectionClick();
                onPressed!();
              }
            : null,
        child: SizedBox(
          width: target,
          height: target,
          child: Center(child: iconWidget),
        ),
      ),
    );
  }
}

/// Apple HIG Pill / Chip for category filtering
class IOSChip extends StatelessWidget {
  const IOSChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final accent = IOSColors.accent.resolveFrom(context);
    final bgColor = isSelected
        ? accent
        : IOSColors.secondaryGroupedBackground.resolveFrom(context);
    final fgColor = isSelected
        ? CupertinoColors.white
        : IOSColors.label.resolveFrom(context);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 36),
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accent
                : IOSColors.separator.resolveFrom(context).withValues(alpha: 0.5),
            width: 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fgColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: IOSText.subhead.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: fgColor,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? CupertinoColors.white.withValues(alpha: 0.3)
                      : IOSColors.systemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: fgColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inset Grouped Section Card (Apple HIG)
class IOSGroupedCard extends StatelessWidget {
  const IOSGroupedCard({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6, top: 12),
            child: header,
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: IOSColors.secondaryGroupedBackground.resolveFrom(context),
            borderRadius: IOSRadius.cardRadius,
            border: Border.all(
              color: IOSColors.separator.resolveFrom(context).withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          padding: padding,
          child: Column(
            children: children,
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: footer,
          ),
      ],
    );
  }
}
