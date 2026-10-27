// @req FR-POS-01, FR-POS-02, FSD-20
// Apple HIG Design Tokens for Hiroshima POS — Phone + Tablet (iOS + Android)

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

// ───────────────────────── 1. Platform & Fonts ─────────────────────────
abstract final class IOSPlatform {
  static bool get isApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Minimum tappable size: 44 pt on iOS, 48 dp on Android
  static double get minTarget => isAndroid ? 48.0 : 44.0;

  static String? get fontFamily => isApple ? null : 'sans-serif';
  static List<String>? get fontFamilyFallback => const ['Roboto', 'Arial', 'sans-serif'];

  static double trackingFor(double size, double appleTracking) {
    if (isApple) return appleTracking;
    if (size <= 12) return 0;
    if (size <= 17) return size * -0.011;
    if (size <= 24) return size * -0.019;
    return size * -0.022;
  }

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

// ───────────────────────── 2. Spacing (4-pt grid) ─────────────────────────
abstract final class IOSSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: md);
  static const double minTouchTarget = 44.0;
}

// ───────────────────────── 3. Radii ─────────────────────────
abstract final class IOSRadius {
  static const double cell = 10.0;
  static const double card = 14.0;
  static const double button = 14.0;
  static const double sheet = 20.0;
  static const double badge = 8.0;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(button));
  static const BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(sheet));
}

// ───────────────────────── 4. Colors ─────────────────────────
abstract final class IOSColors {
  // Hiroshima Signature Brand Accent (Deep Crimson / Vermilion)
  static const CupertinoDynamicColor accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFDC2626),
    darkColor: Color(0xFFEF4444),
  );
  static const Color accentLight = Color(0xFFDC2626);
  static const Color accentDark = Color(0xFFEF4444);

  // System Backgrounds (Auto-resolves for light/dark)
  static const CupertinoDynamicColor groupedBackground = CupertinoColors.systemGroupedBackground;
  static const CupertinoDynamicColor secondaryGroupedBackground =
      CupertinoColors.secondarySystemGroupedBackground;
  static const CupertinoDynamicColor tertiaryGroupedBackground =
      CupertinoColors.tertiarySystemGroupedBackground;

  // Labels & Typography
  static const CupertinoDynamicColor label = CupertinoColors.label;
  static const CupertinoDynamicColor secondaryLabel = CupertinoColors.secondaryLabel;
  static const CupertinoDynamicColor tertiaryLabel = CupertinoColors.tertiaryLabel;
  static const CupertinoDynamicColor quaternaryLabel = CupertinoColors.quaternaryLabel;

  // Separators & Borders
  static const CupertinoDynamicColor separator = CupertinoColors.separator;
  static const CupertinoDynamicColor opaqueSeparator = CupertinoColors.opaqueSeparator;

  // System Fills
  static const CupertinoDynamicColor systemFill = CupertinoColors.systemFill;
  static const CupertinoDynamicColor secondarySystemFill = CupertinoColors.secondarySystemFill;
  static const CupertinoDynamicColor tertiarySystemFill = CupertinoColors.tertiarySystemFill;

  // Semantic Status Colors
  static const CupertinoDynamicColor destructive = CupertinoColors.systemRed;
  static const CupertinoDynamicColor success = CupertinoColors.systemGreen;
  static const CupertinoDynamicColor warning = CupertinoColors.systemOrange;
  static const CupertinoDynamicColor info = CupertinoColors.systemBlue;
}

// ───────────────────────── 5. Typography Scale ─────────────────────────
abstract final class IOSText {
  static TextStyle _s(double size, FontWeight weight, double appleTracking, {double? height}) => TextStyle(
        fontFamily: IOSPlatform.fontFamily,
        fontFamilyFallback: IOSPlatform.fontFamilyFallback,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: IOSPlatform.trackingFor(size, appleTracking),
        height: height,
        decoration: TextDecoration.none,
      );

  static TextStyle get largeTitle => _s(34, FontWeight.w700, 0.4);
  static TextStyle get title1 => _s(28, FontWeight.w600, 0.38);
  static TextStyle get title2 => _s(22, FontWeight.w600, -0.26);
  static TextStyle get title3 => _s(20, FontWeight.w600, -0.45);
  static TextStyle get headline => _s(17, FontWeight.w600, -0.43);
  static TextStyle get body => _s(17, FontWeight.w400, -0.43);
  static TextStyle get callout => _s(16, FontWeight.w400, -0.31);
  static TextStyle get subhead => _s(15, FontWeight.w400, -0.23);
  static TextStyle get footnote => _s(13, FontWeight.w400, -0.08);
  static TextStyle get caption1 => _s(12, FontWeight.w400, 0);
  static TextStyle get caption2 => _s(11, FontWeight.w400, 0.06);

  static TextStyle label(BuildContext context, TextStyle base) =>
      base.copyWith(color: IOSColors.label.resolveFrom(context));

  static TextStyle secondary(BuildContext context, TextStyle base) =>
      base.copyWith(color: IOSColors.secondaryLabel.resolveFrom(context));

  static TextStyle tabular(TextStyle base) => base.copyWith(fontFeatures: IOSPlatform.tabular);
}

// ───────────────────────── 6. System UI & Theme ─────────────────────────
abstract final class IOSSystemUi {
  static Future<void> init() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static SystemUiOverlayStyle styleFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: const Color(0x00000000),
      systemNavigationBarDividerColor: const Color(0x00000000),
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }
}

CupertinoThemeData buildIOSTheme({Brightness? brightness}) {
  final isDark = brightness == Brightness.dark;
  final effectiveTextColor = isDark ? CupertinoColors.white : CupertinoColors.black;
  final effectiveSubtextColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

  return CupertinoThemeData(
    brightness: brightness ?? Brightness.light,
    primaryColor: isDark ? IOSColors.accentDark : IOSColors.accentLight,
    primaryContrastingColor: CupertinoColors.white,
    scaffoldBackgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
    barBackgroundColor: isDark ? const Color(0xCC1C1C1E) : const Color(0xCCFFFFFF),
    textTheme: CupertinoTextThemeData(
      primaryColor: isDark ? IOSColors.accentDark : IOSColors.accentLight,
      textStyle: IOSText.body.copyWith(color: effectiveTextColor),
      actionTextStyle: IOSText.body.copyWith(color: isDark ? IOSColors.accentDark : IOSColors.accentLight),
      tabLabelTextStyle: IOSText.caption2.copyWith(color: effectiveSubtextColor),
      navTitleTextStyle: IOSText.headline.copyWith(color: effectiveTextColor),
      navLargeTitleTextStyle: IOSText.largeTitle.copyWith(color: effectiveTextColor),
      pickerTextStyle: IOSText.title3.copyWith(color: effectiveTextColor),
      dateTimePickerTextStyle: IOSText.title3.copyWith(color: effectiveTextColor),
    ),
  );
}
