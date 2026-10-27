// @req FR-POS-01, FR-POS-02, FR-OFF-07
// Apple HIG iOS-Look Entry Point for Hiroshima POS (iOS + Android)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
import 'package:mobile/core/theme/ios_tokens.dart';
import 'package:mobile/features/auth/presentation/pos_login_screen.dart';
import 'package:mobile/features/pos/presentation/pos_tablet_screen.dart';

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
    return MaterialApp(
      title: 'Hiroshima POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: IOSPlatform.fontFamily,
        fontFamilyFallback: IOSPlatform.fontFamilyFallback,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFDC2626),
          primary: const Color(0xFFDC2626),
          surface: Colors.white,
        ),
        cupertinoOverrideTheme: buildIOSTheme(),
        dividerTheme: const DividerThemeData(
          color: Color(0x333C3C43), // CupertinoColors.separator
          thickness: 0.5,
          space: 1,
        ),
      ),
      builder: (context, child) {
        final brightness = MediaQuery.platformBrightnessOf(context);
        return AnnotatedRegion(
          value: IOSSystemUi.styleFor(brightness),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: PosSyncService.instance.isLoggedIn
          ? const PosTabletScreen()
          : const PosLoginScreen(),
    );
  }
}
