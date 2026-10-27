// @req FR-POS-01, FR-POS-02, FR-OFF-07
// Apple HIG iOS-Look Entry Point for Hiroshima POS (iOS + Android)
// World-class Million Dollar Architecture with Production Server, Dual Theme, Preload, and Offline Cache

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/core/theme/ios_tokens.dart';
import 'package:mobile/core/theme/theme_controller.dart';
import 'package:mobile/features/auth/presentation/pos_preload_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IOSSystemUi.init();
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: HiroshimaPosApp(),
    ),
  );
}

/// Hybrid App Shell: MaterialApp wearing Cupertino Theme (per flutter-ios-design)
class HiroshimaPosApp extends StatelessWidget {
  const HiroshimaPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Hiroshima POS',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.themeMode,
          
          // Light Theme (Apple HIG System Grouped Background)
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            fontFamily: IOSPlatform.fontFamily,
            fontFamilyFallback: IOSPlatform.fontFamilyFallback,
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFDC2626),
              primary: const Color(0xFFDC2626),
              surface: Colors.white,
              brightness: Brightness.light,
            ),
            cupertinoOverrideTheme: buildIOSTheme(brightness: Brightness.light),
            dividerTheme: const DividerThemeData(
              color: Color(0x333C3C43), // CupertinoColors.separator
              thickness: 0.5,
              space: 1,
            ),
          ),

          // Dark Theme (Apple HIG OLED Black & Elevated Surface)
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            fontFamily: IOSPlatform.fontFamily,
            fontFamilyFallback: IOSPlatform.fontFamilyFallback,
            scaffoldBackgroundColor: const Color(0xFF000000),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFDC2626),
              primary: const Color(0xFFEF4444),
              surface: const Color(0xFF1C1C1E),
              brightness: Brightness.dark,
            ),
            cupertinoOverrideTheme: buildIOSTheme(brightness: Brightness.dark),
            dividerTheme: const DividerThemeData(
              color: Color(0x54545865), // CupertinoColors.darkSeparator
              thickness: 0.5,
              space: 1,
            ),
          ),

          builder: (context, child) {
            final brightness = MediaQuery.platformBrightnessOf(context);
            final effectiveDark = ThemeController.instance.themeMode == ThemeMode.dark ||
                (ThemeController.instance.themeMode == ThemeMode.system && brightness == Brightness.dark);
            
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: IOSSystemUi.styleFor(effectiveDark ? Brightness.dark : Brightness.light),
              child: CupertinoTheme(
                data: buildIOSTheme(brightness: effectiveDark ? Brightness.dark : Brightness.light),
                child: Material(
                  type: MaterialType.transparency,
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontFamily: IOSPlatform.fontFamily,
                      fontFamilyFallback: IOSPlatform.fontFamilyFallback,
                      decoration: TextDecoration.none,
                      color: effectiveDark ? CupertinoColors.white : CupertinoColors.black,
                    ),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },

          home: const PosPreloadScreen(),
        );
      },
    );
  }
}
