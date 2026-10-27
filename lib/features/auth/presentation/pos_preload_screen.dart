import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/sync/pos_sync_service.dart';
import 'package:mobile/core/theme/ios_tokens.dart';
import 'package:mobile/core/theme/theme_controller.dart';
import 'package:mobile/features/auth/presentation/pos_login_screen.dart';
import 'package:mobile/features/pos/presentation/pos_tablet_screen.dart';

class PosPreloadScreen extends StatefulWidget {
  const PosPreloadScreen({super.key});

  @override
  State<PosPreloadScreen> createState() => _PosPreloadScreenState();
}

class _PosPreloadScreenState extends State<PosPreloadScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  String _statusText = 'Menginisialisasi sistem...';
  double _progress = 0.2;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();
    _startPreloadSequence();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startPreloadSequence() async {
    final startTime = DateTime.now();

    // Step 1: Initialize local preferences and cached state
    setState(() {
      _statusText = 'Memuat cache lokal & konfigurasi...';
      _progress = 0.4;
    });
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 2: Test / Fetch live catalog from Production Server
    setState(() {
      _statusText = 'Sinkronisasi dengan server backend...';
      _progress = 0.7;
    });

    try {
      if (PosSyncService.instance.isLoggedIn && PosSyncService.instance.authToken.isNotEmpty) {
        await PosSyncService.instance.fetchCatalog().timeout(
          const Duration(seconds: 4),
          onTimeout: () => false,
        );
      }
    } catch (_) {}

    // Step 3: Check active shift and user state
    setState(() {
      _statusText = 'Menyiapkan sesi kasir POS...';
      _progress = 1.0;
    });

    // Guarantee smooth presentation duration (minimum 1.2s)
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inMilliseconds < 1200) {
      await Future.delayed(Duration(milliseconds: 1200 - elapsed.inMilliseconds));
    }

    if (!mounted) return;

    // Navigate to appropriate screen
    final nextScreen = PosSyncService.instance.isLoggedIn
        ? const PosTabletScreen()
        : const PosLoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      child: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Brand Logo Badge Container with Glassmorphic Shadow
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.35 : 0.22),
                          blurRadius: 36,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/logo_badge.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFDC2626),
                          alignment: Alignment.center,
                          child: const Text(
                            'HIROSHIMA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Brand Title & Tagline
                  Text(
                    PosSyncService.instance.appName,
                    style: TextStyle(
                      fontFamily: IOSPlatform.fontFamily,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? CupertinoColors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    PosSyncService.instance.appTagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: IOSPlatform.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF98989D) : const Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Elegant Pill Status Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CupertinoActivityIndicator(radius: 8),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFD1D1D6) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Smooth Progress Bar
                  SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                        minHeight: 3.5,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Bottom Server & Mode Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Server: hiroshima.web.id',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => ThemeController.instance.toggleTheme(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                            size: 14,
                            color: isDark ? const Color(0xFFFFD60A) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
