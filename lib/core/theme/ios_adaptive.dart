// @req FR-POS-01, FR-POS-02, FSD-20
// Adaptive layout helpers for Phone & Tablet (iOS + Android)

import 'package:flutter/widgets.dart';

enum IOSSizeClass { compact, regular, wide }

abstract final class IOSBreakpoints {
  static const double regular = 600;
  static const double wide = 1024;
  static const double readableWidth = 672;

  static IOSSizeClass of(double width) {
    if (width >= wide) return IOSSizeClass.wide;
    if (width >= regular) return IOSSizeClass.regular;
    return IOSSizeClass.compact;
  }
}

extension IOSAdaptiveContext on BuildContext {
  IOSSizeClass get sizeClass => IOSBreakpoints.of(MediaQuery.sizeOf(this).width);
  bool get isCompact => sizeClass == IOSSizeClass.compact;
  bool get isTablet => sizeClass != IOSSizeClass.compact;

  double get screenMargin => switch (sizeClass) {
        IOSSizeClass.compact => 16.0,
        IOSSizeClass.regular => 20.0,
        IOSSizeClass.wide => 24.0,
      };

  int get responsivePosGridColumns {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= 1200) return 4;
    if (width >= 850) return 3;
    if (width >= 600) return 3;
    if (width >= 420) return 2;
    return 2;
  }
}

/// Adaptive Grid Delegate for Apple-styled product cards
SliverGridDelegateWithFixedCrossAxisCount iosProductGridDelegate({
  required BuildContext context,
  bool isSplitView = false,
}) {
  final width = MediaQuery.sizeOf(context).width;
  int columns = 2;
  double aspectRatio = 0.70;

  if (isSplitView) {
    // In tablet split-view (catalog pane is ~65% of width)
    final catalogWidth = width * 0.65;
    if (catalogWidth >= 800) {
      columns = 4;
      aspectRatio = 0.68;
    } else if (catalogWidth >= 520) {
      columns = 3;
      aspectRatio = 0.67;
    } else {
      columns = 2;
      aspectRatio = 0.66;
    }
  } else {
    // Phone or full width
    if (width >= 600) {
      columns = 3;
      aspectRatio = 0.68;
    } else {
      columns = 2;
      aspectRatio = 0.66;
    }
  }

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: aspectRatio,
  );
}
