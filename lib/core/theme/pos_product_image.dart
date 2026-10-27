import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';

class PosProductImage extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? category;

  const PosProductImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedUrl = PosSyncService.instance.resolveImageUrl(imagePath);
    final radius = borderRadius ?? const BorderRadius.vertical(top: Radius.circular(16));

    Widget imageContent;

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      imageContent = Image.network(
        resolvedUrl,
        width: width,
        height: height,
        fit: fit,
        alignment: Alignment.center,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
            alignment: Alignment.center,
            child: const CupertinoActivityIndicator(radius: 8),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallback(isDark);
        },
      );
    } else {
      imageContent = _buildFallback(isDark);
    }

    return ClipRRect(
      borderRadius: radius,
      child: imageContent,
    );
  }

  Widget _buildFallback(bool isDark) {
    return Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF242426) : const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.2 : 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.flame_fill,
              size: 18,
              color: Color(0xFFDC2626),
            ),
          ),
          if (category != null && category!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              category!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
