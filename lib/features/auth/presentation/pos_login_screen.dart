// @req FR-AUTH-01, FR-AUTH-02, FR-AUTH-05, FR-DEV-01, FR-POS-01, FSD-01
// Apple HIG iOS-Look Cashier PIN & Multi-Role Login Screen for Hiroshima POS
// Responsive Phone + Tablet (iOS + Android) · Haptic Tactile Keypad · Device Activation

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ScaffoldMessenger, SnackBar, Theme;
import 'package:flutter/services.dart';
import '../../../core/sync/pos_server_config_sheet.dart';
import '../../../core/sync/pos_sync_service.dart';
import '../../../core/theme/ios_adaptive.dart';
import '../../../core/theme/ios_components.dart';
import '../../../core/theme/ios_tokens.dart';
import '../../../core/theme/theme_controller.dart';
import '../../pos/presentation/pos_tablet_screen.dart';

enum LoginMode { pin, email, activation }

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

  // Activation mode state
  final TextEditingController _activationCodeController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();

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
    _activationCodeController.dispose();
    _deviceNameController.dispose();
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

  Future<void> _submitActivation() async {
    final code = _activationCodeController.text.trim();
    final name = _deviceNameController.text.trim();

    if (code.isEmpty || name.isEmpty) {
      setState(() => _errorMessage = 'Kode aktivasi dan nama perangkat wajib diisi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await PosSyncService.instance.activateDevice(
      activationCode: code,
      deviceName: name,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (res['success'] == true) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] as String? ?? 'Perangkat berhasil diaktivasi!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      setState(() {
        _selectedMode = LoginMode.pin;
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = res['message'] as String? ?? 'Aktivasi gagal.';
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: () => ThemeController.instance.toggleTheme(context),
              child: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? CupertinoIcons.sun_max_fill
                    : CupertinoIcons.moon_fill,
                size: 20,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => PosServerConfigSheet.show(context),
              child: const Icon(CupertinoIcons.gear_alt, size: 22),
            ),
          ],
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
                    LoginMode.activation => _buildActivationModeContent(),
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
    final branchName = PosSyncService.instance.branch['name'] as String? ?? 'Hiroshima Japanese Street Food';
    final branchCode = PosSyncService.instance.branch['code'] as String? ?? 'HRS-CKN';
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
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: IOSSpacing.sm),
        Text(
          PosSyncService.instance.appName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
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
                '$branchName ($branchCode)',
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
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Text('PIN Kasir', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          LoginMode.email: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Text('Email & Sandi', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          LoginMode.activation: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Text('Aktivasi', style: TextStyle(fontWeight: FontWeight.w600)),
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
        children: [
          // Cashier Profile Selector Pill
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showCashierPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.person_crop_circle_fill, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Text(
                    _selectedCashierName,
                    style: IOSText.subhead.copyWith(
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: IOSSpacing.md),

          // 6-Digit PIN Dots Display
          _buildPinDots(),
          const SizedBox(height: IOSSpacing.lg),

          // 3x4 Tactile Keypad
          _buildNumpadGrid(),
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
            placeholder: 'nama@hiroshima.id / username',
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

  // ───────────────────────── 3. MODE AKTIVASI TABLET ─────────────────────────
  Widget _buildActivationModeContent() {
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
          Text('Kode Aktivasi (Dari Web Backoffice)', style: IOSText.caption1),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: _activationCodeController,
            placeholder: 'Contoh: ACT-9999',
            textCapitalization: TextCapitalization.characters,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(CupertinoIcons.qrcode, size: 20, color: CupertinoColors.systemGrey),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: IOSSpacing.md),

          Text('Nama / Posisi Tablet', style: IOSText.caption1),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: _deviceNameController,
            placeholder: 'Contoh: Tablet Kasir Utama / Tablet Bar',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(CupertinoIcons.device_phone_portrait, size: 20, color: CupertinoColors.systemGrey),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: IOSSpacing.lg),

          IOSButton(
            label: 'Aktivasi Perangkat Tablet',
            variant: IOSButtonVariant.filled,
            expanded: true,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submitActivation,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo() {
    return Column(
      children: [
        Text(
          'Hiroshima Japanese Street Food POS v2.2',
          style: IOSText.caption1.copyWith(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Mode Offline-First · Enkripsi Argon2id · Paritas PHP 8.3',
          style: IOSText.caption2.copyWith(
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}
