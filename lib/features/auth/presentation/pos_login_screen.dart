// @req FR-AUTH-01, FR-AUTH-02, FR-AUTH-05, FR-DEV-01, FR-POS-01, FSD-01
// Apple HIG iOS-Look Cashier PIN & Multi-Role Login Screen for Hiroshima POS
// Responsive Phone + Tablet (iOS + Android) · Haptic Tactile Keypad · Username & PIN or Email & Password

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:flutter/services.dart';
import '../../../core/sync/pos_sync_service.dart';
import '../../../core/theme/ios_adaptive.dart';
import '../../../core/theme/ios_components.dart';
import '../../../core/theme/ios_tokens.dart';
import '../../../core/theme/theme_controller.dart';
import '../../pos/presentation/pos_tablet_screen.dart';

enum LoginMode { pin, email }

class PosLoginScreen extends StatefulWidget {
  const PosLoginScreen({super.key});

  @override
  State<PosLoginScreen> createState() => _PosLoginScreenState();
}

class _PosLoginScreenState extends State<PosLoginScreen> {
  LoginMode _selectedMode = LoginMode.pin;

  // PIN mode state
  final TextEditingController _usernameController = TextEditingController();
  String _enteredPin = '';

  // Email mode state
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onKeyPress(String val) {
    if (_isLoading) return;
    HapticFeedback.lightImpact();
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += val;
        _errorMessage = null;
      });

      if (_enteredPin.length == 6) {
        if (_usernameController.text.trim().isNotEmpty) {
          _submitPinLogin();
        } else {
          setState(() {
            _errorMessage = 'Silakan masukkan username kasir terlebih dahulu.';
          });
        }
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty || _isLoading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  void _clearPin() {
    if (_enteredPin.isEmpty || _isLoading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _submitPinLogin() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _errorMessage = 'Username kasir wajib diisi.');
      return;
    }
    if (_enteredPin.length < 6) {
      setState(() => _errorMessage = 'PIN kasir harus 6 digit angka.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await PosSyncService.instance.login(
      identifier: username,
      credential: _enteredPin,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const PosTabletScreen()),
      );
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _enteredPin = '';
        _errorMessage = res['message'] as String? ?? 'Kredensial atau PIN salah. Silakan coba lagi.';
      });
    }
  }

  Future<void> _submitEmailLogin() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Email dan kata sandi wajib diisi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await PosSyncService.instance.login(
      identifier: email,
      credential: pass,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const PosTabletScreen()),
      );
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _errorMessage = res['message'] as String? ?? 'Kredensial salah.';
      });
    }
  }





  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;

    return CupertinoPageScaffold(
      backgroundColor: IOSColors.groupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context).withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(
            color: Color(0x333C3C43),
            width: 0.5,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
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
                color: const Color(0xFFDC2626),
                alignment: Alignment.center,
                child: const Text('H', style: TextStyle(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ),
        middle: Text(
          PosSyncService.instance.appName,
          style: IOSText.headline,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          onPressed: () => ThemeController.instance.toggleTheme(context),
          child: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? CupertinoIcons.sun_max_fill
                : CupertinoIcons.moon_fill,
            size: 20,
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.screenMargin,
              vertical: IOSSpacing.md,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 500 : double.infinity,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Brand Header Monogram
                  _buildBrandHeader(),
                  const SizedBox(height: IOSSpacing.lg),

                  // Segmented Mode Selector
                  _buildModeSegmentedControl(),
                  const SizedBox(height: IOSSpacing.lg),

                  // Error alert if present
                  if (_errorMessage != null) ...[
                    _buildErrorAlert(_errorMessage!),
                    const SizedBox(height: IOSSpacing.md),
                  ],

                  // Mode Content Card
                  switch (_selectedMode) {
                    LoginMode.pin => _buildPinModeContent(),
                    LoginMode.email => _buildEmailModeContent(),
                  },

                  const SizedBox(height: IOSSpacing.xl),
                  _buildFooterInfo(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    final hasActiveBranch = PosSyncService.instance.branch.isNotEmpty &&
        PosSyncService.instance.branch['name'] != null;
    final branchName = hasActiveBranch
        ? (PosSyncService.instance.branch['name'] as String? ?? '')
        : PosSyncService.instance.appTagline;
    final branchCode = hasActiveBranch ? (PosSyncService.instance.branch['code'] as String?) : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.35 : 0.22),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/logo_badge.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFFDC2626),
              alignment: Alignment.center,
              child: const Text(
                'H',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: IOSSpacing.sm),
        Text(
          PosSyncService.instance.appName,
          style: IOSText.title2.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: PosSyncService.instance.isOnline ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                branchCode != null ? '$branchName ($branchCode)' : branchName,
                style: IOSText.footnote.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeSegmentedControl() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<LoginMode>(
        groupValue: _selectedMode,
        thumbColor: CupertinoColors.white,
        backgroundColor: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        padding: const EdgeInsets.all(3),
        children: {
          LoginMode.pin: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text('Username & PIN', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          LoginMode.email: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text('Email & Password', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        },
        onValueChanged: (val) {
          if (val != null) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedMode = val;
              _errorMessage = null;
              _enteredPin = '';
            });
          }
        },
      ),
    );
  }

  Widget _buildErrorAlert(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 1. MODE PIN KASIR ─────────────────────────
  Widget _buildPinModeContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(IOSRadius.card),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dynamic Username Input Field
          Text('Username Kasir', style: IOSText.caption1),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: _usernameController,
            placeholder: 'Masukkan username kasir',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(CupertinoIcons.person_crop_circle, size: 20, color: CupertinoColors.systemGrey),
            ),
            clearButtonMode: OverlayVisibilityMode.editing,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: IOSSpacing.md),

          Center(
            child: Text(
              'PIN Kasir (6 Digit)',
              style: IOSText.caption1.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 6-Digit PIN Dots Display
          _buildPinDots(),
          const SizedBox(height: IOSSpacing.lg),

          // 3x4 Tactile Keypad
          _buildNumpadGrid(),
          const SizedBox(height: IOSSpacing.lg),

          IOSButton(
            label: 'Masuk dengan PIN',
            variant: IOSButtonVariant.filled,
            expanded: true,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submitPinLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < _enteredPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? const Color(0xFFDC2626) : CupertinoColors.systemGrey5.resolveFrom(context),
            border: Border.all(
              color: isFilled ? const Color(0xFFDC2626) : CupertinoColors.systemGrey3.resolveFrom(context),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumpadGrid() {
    final keyLabels = [
      ['1', ''],
      ['2', 'ABC'],
      ['3', 'DEF'],
      ['4', 'GHI'],
      ['5', 'JKL'],
      ['6', 'MNO'],
      ['7', 'PQRS'],
      ['8', 'TUV'],
      ['9', 'WXYZ'],
      ['C', ''],
      ['0', ''],
      ['⌫', ''],
    ];

    return Column(
      children: [
        for (int row = 0; row < 4; row++) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int col = 0; col < 3; col++) ...[
                Builder(
                  builder: (_) {
                    final item = keyLabels[row * 3 + col];
                    final keyChar = item[0];
                    final sub = item[1];
                    return _buildKeypadButton(keyChar, sub);
                  },
                ),
                if (col < 2) const SizedBox(width: 16),
              ],
            ],
          ),
          if (row < 3) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildKeypadButton(String keyChar, String subtext) {
    final isSpecial = keyChar == 'C' || keyChar == '⌫';

    return SizedBox(
      width: 72,
      height: 60,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(16),
        color: isSpecial
            ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
            : CupertinoColors.systemBackground.resolveFrom(context),
        onPressed: () {
          if (keyChar == 'C') {
            _clearPin();
          } else if (keyChar == '⌫') {
            _onBackspace();
          } else {
            _onKeyPress(keyChar);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (keyChar == '⌫')
              Icon(
                CupertinoIcons.delete_left_fill,
                size: 22,
                color: CupertinoColors.label.resolveFrom(context),
              )
            else
              Text(
                keyChar,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isSpecial
                      ? CupertinoColors.secondaryLabel.resolveFrom(context)
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
            if (subtext.isNotEmpty)
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 2. MODE EMAIL & PASSWORD ─────────────────────────
  Widget _buildEmailModeContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(IOSRadius.card),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Username atau Email', style: IOSText.caption1),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: _emailController,
            placeholder: 'Masukkan email atau username',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(CupertinoIcons.mail, size: 20, color: CupertinoColors.systemGrey),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: IOSSpacing.md),

          Text('Kata Sandi', style: IOSText.caption1),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            placeholder: 'Masukkan kata sandi',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(CupertinoIcons.lock, size: 20, color: CupertinoColors.systemGrey),
            ),
            suffix: CupertinoButton(
              padding: const EdgeInsets.only(right: 12),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                size: 20,
                color: CupertinoColors.systemGrey,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: IOSSpacing.lg),

          IOSButton(
            label: 'Masuk Akun',
            variant: IOSButtonVariant.filled,
            expanded: true,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submitEmailLogin,
          ),
        ],
      ),
    );
  }



  Widget _buildFooterInfo() {
    final appName = PosSyncService.instance.appName;
    return Column(
      children: [
        Text(
          '$appName POS',
          style: IOSText.caption1.copyWith(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Mode Offline-First · Enkripsi Argon2id',
          style: IOSText.caption2.copyWith(
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}
