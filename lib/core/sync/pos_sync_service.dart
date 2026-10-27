// @req FR-OFF-01, FR-OFF-02, FR-OFF-03, FR-OFF-04, FR-OFF-05, FR-POS-16, FSD-10

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/sync/outbox_manager.dart';
import 'package:mobile/core/time/trusted_clock.dart';

/// PosSyncService manages:
/// 1. Dynamic catalog synchronization from Backend (`/api/v1/sync/pull`)
/// 2. Local disk caching for 100% offline functionality
/// 3. Offline order queueing (`OutboxManager`) and auto-sync when online (`/api/v1/sync/push`)
/// 4. Configurable Base URL persisted across app restarts
class PosSyncService extends ChangeNotifier {
  static final PosSyncService instance = PosSyncService._internal();
  factory PosSyncService() => instance;
  PosSyncService._internal() {
    _initAutoSync();
  }

  static const String _prefKeyBaseUrl = 'hiroshima_pos_api_base_url';
  static const String _prefKeyAuthToken = 'hiroshima_pos_auth_token';
  static const String _prefKeyCurrentUser = 'hiroshima_pos_current_user';
  static const String _prefKeyActiveBranch = 'hiroshima_pos_active_branch';
  static const String _prefKeyAccessibleBranches = 'hiroshima_pos_accessible_branches';
  static const String _prefKeyCanSwitchBranch = 'hiroshima_pos_can_switch_branch';
  static const String _prefKeyCatalogCache = 'hiroshima_pos_catalog_cache_v2';

  /// Official production API base URL on hiroshima.web.id
  static const String productionBaseUrl = 'https://hiroshima.web.id/api/v1';

  /// Optional build-time override via `--dart-define=API_BASE_URL=...`
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Default API Base URL:
  /// Always points to https://hiroshima.web.id/api/v1 by default,
  /// unless overridden via compile-time flag or saved in settings.
  static String get defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    return productionBaseUrl;
  }

  String baseUrl = defaultBaseUrl;

  String get serverBaseUrl => baseUrl.replaceAll('/api/v1', '');
  String authToken = '';

  Map<String, dynamic> _branch = {};
  List<Map<String, dynamic>> _accessibleBranches = [];
  bool _canSwitchBranch = false;

  Map<String, dynamic>? currentUser;
  void setMockUser(Map<String, dynamic>? val) {
    currentUser = val;
    if (val != null) {
      if (val['branch'] != null) {
        _branch = Map<String, dynamic>.from(val['branch'] as Map);
      }
      if (val['accessible_branches'] != null) {
        _accessibleBranches = ((val['accessible_branches'] as List<dynamic>?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      if (val['can_switch_branch'] != null) {
        _canSwitchBranch = val['can_switch_branch'] == true;
      }
    }
  }
  bool get isLoggedIn => currentUser != null;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  String _statusMessage = 'Menunggu inisialisasi...';
  String get statusMessage => _statusMessage;

  // Cached domain state from backend
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orderTypes = [];
  List<Map<String, dynamic>> _productPrices = [];
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _cashiers = [];
  Map<String, dynamic> _systemSettings = {};

  Map<String, dynamic> get branch => _branch;
  List<Map<String, dynamic>> get accessibleBranches => _accessibleBranches;
  bool get canSwitchBranch => _canSwitchBranch;
  List<Map<String, dynamic>> get categories => _categories;
  List<Map<String, dynamic>> get products => _products;
  List<Map<String, dynamic>> get orderTypes => _orderTypes;
  List<Map<String, dynamic>> get productPrices => _productPrices;
  List<Map<String, dynamic>> get tables => _tables;
  List<Map<String, dynamic>> get paymentMethods => _paymentMethods;
  List<Map<String, dynamic>> get cashiers => _cashiers;
  Map<String, dynamic> get systemSettings => _systemSettings;

  String get appName => (_systemSettings['app_name'] as String?) ?? 'HIROSHIMA POS';
  String get appTagline => (_systemSettings['app_tagline'] as String?) ?? 'Japanese Street Food';
  String? get appLogoUrl => resolveImageUrl(_systemSettings['app_logo_url'] as String?);

  bool get isHoldBillEnabled {
    final val = _systemSettings['hold_bill_enabled'];
    if (val == null) return true;
    if (val is bool) return val;
    return val.toString() == '1' || val.toString().toLowerCase() == 'true';
  }

  List<Map<String, dynamic>> _heldOrders = [];
  List<Map<String, dynamic>> get heldOrders => _heldOrders;

  @visibleForTesting
  void resetForTesting() {
    _branch = {};
    _accessibleBranches = [];
    _canSwitchBranch = false;
    _categories = [];
    _products = [];
    _orderTypes = [];
    _productPrices = [];
    _tables = [];
    _paymentMethods = [];
    _cashiers = [];
    _systemSettings = {};
    _heldOrders = [];
    currentUser = null;
    authToken = '';
  }

  /// Resolves relative or localhost image URLs to the active production backend
  String? resolveImageUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.trim().isEmpty) return null;
    final clean = pathOrUrl.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      if (clean.contains('localhost') || clean.contains('127.0.0.1')) {
        final uri = Uri.parse(clean);
        return '$serverBaseUrl${uri.path}';
      }
      return clean;
    }
    final root = clean.startsWith('/') ? clean : '/$clean';
    return '$serverBaseUrl$root';
  }

  int get pendingQueueCount => OutboxManager().queueSize;

  Timer? _autoSyncTimer;

  File get _cacheFile => File('offline_catalog_cache.json');
  File get _outboxFile => File('offline_outbox_queue.json');

  Future<void> _initAutoSync() async {
    await _loadSavedBaseUrl();
    await _loadSavedAuth();
    _loadOutboxFromDisk();
    _loadCacheFromDisk();
  }

  Future<void> _loadSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_prefKeyAuthToken);
      final userStr = prefs.getString(_prefKeyCurrentUser);
      final branchStr = prefs.getString(_prefKeyActiveBranch);
      final accBranchesStr = prefs.getString(_prefKeyAccessibleBranches);
      final canSwitch = prefs.getBool(_prefKeyCanSwitchBranch);

      if (token != null && token.isNotEmpty) {
        authToken = token;
      }
      if (userStr != null && userStr.isNotEmpty) {
        currentUser = jsonDecode(userStr) as Map<String, dynamic>;
      }
      if (branchStr != null && branchStr.isNotEmpty) {
        _branch = jsonDecode(branchStr) as Map<String, dynamic>;
      }
      if (accBranchesStr != null && accBranchesStr.isNotEmpty) {
        _accessibleBranches = (jsonDecode(accBranchesStr) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      if (canSwitch != null) {
        _canSwitchBranch = canSwitch;
      }
    } catch (_) {}
  }

  /// Perform Cashier / Supervisor Login (PIN or Email/Password)
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String credential,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username_or_email': identifier,
          'password_or_pin': credential,
        }),
      ).timeout(const Duration(seconds: 6));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final token = body['token'] as String?;
        final user = body['user'] as Map<String, dynamic>?;

        if (token != null) {
          authToken = token;
        }
        if (user != null) {
          currentUser = user;
          _canSwitchBranch = (user['can_switch_branch'] as bool?) ??
              (user['branch_id'] == null || user['role'] == 'owner' || user['role'] == 'central_admin');

          if (user['accessible_branches'] != null) {
            _accessibleBranches = ((user['accessible_branches'] as List<dynamic>?) ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } else if (user['branch'] != null) {
            _accessibleBranches = [Map<String, dynamic>.from(user['branch'] as Map)];
          }

          if (user['branch'] != null) {
            _branch = Map<String, dynamic>.from(user['branch'] as Map);
          } else if (_accessibleBranches.isNotEmpty) {
            _branch = _accessibleBranches.first;
          }

          try {
            final prefs = await SharedPreferences.getInstance();
            if (token != null) await prefs.setString(_prefKeyAuthToken, token);
            await prefs.setString(_prefKeyCurrentUser, jsonEncode(user));
            await prefs.setString(_prefKeyActiveBranch, jsonEncode(_branch));
            await prefs.setString(_prefKeyAccessibleBranches, jsonEncode(_accessibleBranches));
            await prefs.setBool(_prefKeyCanSwitchBranch, _canSwitchBranch);
          } catch (_) {}
        }

        notifyListeners();
        // Fetch latest catalog on login for assigned branch
        unawaited(fetchCatalog(branchId: _branch['id']));

        return {
          'success': true,
          'message': 'Login berhasil',
          'user': user,
        };
      }

      return {
        'success': false,
        'message': body['message'] ?? 'Login gagal (HTTP ${response.statusCode})',
      };
    } catch (e) {
      // Offline fallback: If offline and credential matches 6-digit PIN pattern or default
      if (credential.length == 6) {
        currentUser = {
          'id': 1,
          'name': 'Kasir Offline ($identifier)',
          'username': identifier,
          'role': 'cashier',
          'branch': _branch,
        };
        _statusMessage = 'Mode Offline: Masuk menggunakan sesi lokal';
        notifyListeners();
        return {
          'success': true,
          'offline': true,
          'message': 'Mode Offline: Berhasil masuk ke sesi kasir lokal',
          'user': currentUser,
        };
      }
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server backend: $e',
      };
    }
  }

  /// Perform Tablet Device Activation via Activation Code
  Future<Map<String, dynamic>> activateDevice({
    required String activationCode,
    required String deviceName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/device-activate');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'activation_code': activationCode,
          'device_name': deviceName,
        }),
      ).timeout(const Duration(seconds: 6));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'message': body['message'] ?? 'Perangkat berhasil diaktivasi',
          'device': body['device'],
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Aktivasi gagal (HTTP ${response.statusCode})',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal menghubungkan ke server aktivasi: $e',
      };
    }
  }

  /// Switch operating branch for multi-branch users (Owner / Admin Pusat / Area Manager)
  Future<bool> switchBranch(Map<String, dynamic> newBranch) async {
    if (!_canSwitchBranch && currentUser?['branch_id'] != null) {
      return false; // Forbidden: restricted to assigned branch
    }
    _branch = newBranch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyActiveBranch, jsonEncode(newBranch));
    } catch (_) {}
    _currentShift = null;
    notifyListeners();
    await fetchCurrentShift();
    return await fetchCatalog(branchId: newBranch['id']);
  }

  /// Logout current session
  Future<void> logout() async {
    try {
      final uri = Uri.parse('$baseUrl/auth/logout');
      await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}

    authToken = '';
    currentUser = null;
    _accessibleBranches = [];
    _canSwitchBranch = false;
    _branch = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyCurrentUser);
      await prefs.remove(_prefKeyAuthToken);
      await prefs.remove(_prefKeyActiveBranch);
      await prefs.remove(_prefKeyAccessibleBranches);
      await prefs.remove(_prefKeyCanSwitchBranch);
    } catch (_) {}

    notifyListeners();
  }

  // ───────────────────────── Shift Management API ─────────────────────────
  Map<String, dynamic>? _currentShift;
  Map<String, dynamic>? get currentShift => _currentShift;
  bool get hasActiveShift => _currentShift != null && _currentShift!['status'] == 'open';

  Future<Map<String, dynamic>> fetchCurrentShift() async {
    try {
      final targetBranchId = _branch['id'] ?? currentUser?['branch_id'];
      String shiftUrl = '$baseUrl/shifts/current';
      if (targetBranchId != null) {
        shiftUrl += '?branch_id=$targetBranchId';
      }
      final uri = Uri.parse(shiftUrl);
      final headers = <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      };
      if (targetBranchId != null) {
        headers['X-Branch-Id'] = targetBranchId.toString();
      }

      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 4));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        if (body['has_active_shift'] == true) {
          _currentShift = body['shift'] as Map<String, dynamic>?;
        } else {
          _currentShift = null;
        }
        notifyListeners();
        return {'success': true, 'shift': _currentShift};
      }
      return {'success': false, 'message': body['message'] ?? 'Gagal mengambil data shift'};
    } catch (e) {
      // In offline mode, keep locally mocked or active shift
      return {'success': false, 'message': 'Mode Offline: $e'};
    }
  }

  Future<Map<String, dynamic>> openShift(int startingCash) async {
    try {
      final targetBranchId = _branch['id'] ?? currentUser?['branch_id'];
      final uri = Uri.parse('$baseUrl/shifts/open');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      };
      if (targetBranchId != null) {
        headers['X-Branch-Id'] = targetBranchId.toString();
      }
      final payload = <String, dynamic>{
        'starting_cash': startingCash,
      };
      if (targetBranchId != null) {
        payload['branch_id'] = targetBranchId;
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201 && body['success'] == true) {
        _currentShift = body['shift'] as Map<String, dynamic>?;
        notifyListeners();
        return {'success': true, 'shift': _currentShift};
      }
      return {'success': false, 'message': body['message'] ?? 'Gagal membuka shift'};
    } catch (e) {
      // Offline fallback
      _currentShift = {
        'id': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'branch_id': _branch['id'] ?? 1,
        'starting_cash': startingCash,
        'expected_cash': startingCash,
        'opened_at': DateTime.now().toIso8601String(),
        'status': 'open',
      };
      notifyListeners();
      return {'success': true, 'offline': true, 'shift': _currentShift};
    }
  }

  Future<Map<String, dynamic>> closeShift(int actualCash) async {
    try {
      final targetBranchId = _branch['id'] ?? currentUser?['branch_id'];
      final uri = Uri.parse('$baseUrl/shifts/close');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      };
      if (targetBranchId != null) {
        headers['X-Branch-Id'] = targetBranchId.toString();
      }
      final payload = <String, dynamic>{
        'actual_cash': actualCash,
      };
      if (targetBranchId != null) {
        payload['branch_id'] = targetBranchId;
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final closed = body['shift'] as Map<String, dynamic>?;
        final report = body['report'] as Map<String, dynamic>?;
        _currentShift = null;
        notifyListeners();
        return {'success': true, 'shift': closed, 'report': report};
      }
      return {
        'success': false,
        'error_code': body['error_code'],
        'message': body['message'] ?? 'Gagal menutup shift',
        'held_bills': body['held_bills'],
      };
    } catch (e) {
      final old = _currentShift;
      _currentShift = null;
      notifyListeners();
      return {
        'success': true,
        'offline': true,
        'shift': {
          ...?old,
          'actual_cash': actualCash,
          'status': 'closed',
        },
        'report': generateLocalReport(old, actualCash),
      };
    }
  }

  /// Generate structured report map for offline shift closures
  Map<String, dynamic> generateLocalReport(Map<String, dynamic>? shiftData, int actualCash) {
    final startCash = (shiftData?['starting_cash'] as num?)?.toInt() ?? 0;
    final expCash = (shiftData?['expected_cash'] as num?)?.toInt() ?? startCash;
    final diff = actualCash - expCash;
    final user = currentUser;

    return {
      'shift_info': {
        'company_name': appName,
        'branch_name': _branch['name'] ?? 'Hiroshima Japanese Street Food',
        'branch_code': _branch['code'] ?? 'HRS',
        'cashier_name': user?['name'] ?? user?['username'] ?? 'Kasir',
        'cashier_username': user?['username'] ?? 'kasir',
        'shift_id': shiftData?['id'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'opened_at': shiftData?['opened_at'] ?? DateTime.now().toIso8601String(),
        'closed_at': DateTime.now().toIso8601String(),
        'printed_at': DateTime.now().toIso8601String(),
        'close_type': 'manual',
        'status': 'closed',
      },
      'menu_summary': {
        'items': <Map<String, dynamic>>[],
        'total': {
          'total_qty': 0,
          'total_sales': 0,
        },
      },
      'transaction_summary': {
        'completed_transaction_count': 0,
        'gross_sales': 0,
        'total_discount': 0,
        'discount_breakdown': {'promo': 0, 'voucher': 0, 'loyalty': 0, 'manual': 0},
        'tax_amount': 0,
        'service_charge_amount': 0,
        'rounding_amount': 0,
        'net_sales': 0,
        'payments_by_method': <Map<String, dynamic>>[],
        'cash_reconciliation': {
          'starting_cash': startCash,
          'expected_cash': expCash,
          'actual_cash': actualCash,
          'cash_difference': diff,
        },
      },
    };
  }

  /// Fetch Close Shift Report for specified shift or latest closed shift
  Future<Map<String, dynamic>?> fetchCurrentShiftReport({int? shiftId}) async {
    try {
      final targetBranchId = _branch['id'] ?? currentUser?['branch_id'];
      String url = shiftId != null
          ? '$baseUrl/shifts/$shiftId/report'
          : '$baseUrl/shifts/current/report';
      if (targetBranchId != null) {
        url += '?branch_id=$targetBranchId';
      }
      final uri = Uri.parse(url);
      final headers = <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      };
      if (targetBranchId != null) {
        headers['X-Branch-Id'] = targetBranchId.toString();
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return body['report'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      debugPrint('[PosSyncService] Error fetching shift report: $e');
    }
    return null;
  }

  // ───────────────────────── Hold Bill API ─────────────────────────

  Future<Map<String, dynamic>> holdOrder(Map<String, dynamic> payload) async {
    try {
      final targetBranchId = _branch['id'] ?? currentUser?['branch_id'];
      final uri = Uri.parse('$baseUrl/orders/hold');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      };
      if (targetBranchId != null) {
        headers['X-Branch-Id'] = targetBranchId.toString();
      }
      final payloadWithBranch = <String, dynamic>{
        ...payload,
        if (targetBranchId != null && !payload.containsKey('branch_id'))
          'branch_id': targetBranchId,
      };

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payloadWithBranch),
      ).timeout(const Duration(seconds: 6));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201 && body['success'] == true) {
        await fetchHeldOrders();
        return {'success': true, 'order': body['order']};
      }
      return {'success': false, 'message': body['message'] ?? 'Gagal menahan pesanan.'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal koneksi ke server Hold Bill: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> fetchHeldOrders() async {
    try {
      final targetBranchId = _branch['id'] ?? currentUser?['branch_id'];
      String heldUrl = '$baseUrl/orders/held';
      if (targetBranchId != null) {
        heldUrl += '?branch_id=$targetBranchId';
      }
      final uri = Uri.parse(heldUrl);
      final headers = <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      };
      if (targetBranchId != null) {
        headers['X-Branch-Id'] = targetBranchId.toString();
      }

      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final list = (body['held_bills'] as List<dynamic>?) ?? [];
        _heldOrders = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        notifyListeners();
        return _heldOrders;
      }
    } catch (_) {}
    return _heldOrders;
  }

  Future<Map<String, dynamic>> resumeHeldOrder(int orderId) async {
    try {
      final uri = Uri.parse('$baseUrl/orders/$orderId/resume');
      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 6));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        await fetchHeldOrders();
        return {'success': true, 'order': body['order']};
      }
      return {'success': false, 'message': body['message'] ?? 'Gagal melanjutkan pesanan.'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal menghubungi server: $e'};
    }
  }

  Future<Map<String, dynamic>> cancelHeldOrder(int orderId, String reason) async {
    try {
      final uri = Uri.parse('$baseUrl/orders/$orderId/cancel-hold');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'reason': reason}),
      ).timeout(const Duration(seconds: 6));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        await fetchHeldOrders();
        return {'success': true, 'order': body['order']};
      }
      return {'success': false, 'message': body['message'] ?? 'Gagal membatalkan pesanan.'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal menghubungi server: $e'};
    }
  }

  Future<void> _loadSavedBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefKeyBaseUrl)) {
        await prefs.remove(_prefKeyBaseUrl);
      }
    } catch (_) {
      // In isolated tests without binding, keep defaultBaseUrl gracefully
    }
    baseUrl = defaultBaseUrl;
  }

  /// Change and persist Backend API Base URL
  Future<void> setBaseUrl(String newUrl) async {
    String clean = newUrl.trim();
    if (!clean.endsWith('/api/v1') && !clean.contains('/api/v1')) {
      if (clean.endsWith('/')) {
        clean = '${clean}api/v1';
      } else {
        clean = '$clean/api/v1';
      }
    }
    baseUrl = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyBaseUrl, clean);
    } catch (_) {}
    notifyListeners();

    // Trigger instant catalog fetch with new URL
    await fetchCatalog();
  }

  /// Test connection to a backend server URL
  Future<Map<String, dynamic>> testConnection(String testUrl) async {
    String clean = testUrl.trim();
    if (!clean.endsWith('/api/v1') && !clean.contains('/api/v1')) {
      clean = clean.endsWith('/') ? '${clean}api/v1' : '$clean/api/v1';
    }

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('$clean/sync/pull');
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 4));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final branchData = body['data']?['branch'] as Map<String, dynamic>?;
          final branchName = branchData?['name'] ?? 'Hiroshima Japanese Street Food';
          final prodCount = (body['data']?['products'] as List?)?.length ?? 0;
          return {
            'success': true,
            'message': 'Koneksi berhasil ($prodCount produk aktif)',
            'branch': branchName,
            'latency': stopwatch.elapsedMilliseconds,
          };
        }
      }
      return {
        'success': false,
        'message': 'Respon server HTTP ${response.statusCode}',
        'latency': stopwatch.elapsedMilliseconds,
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'message': 'Gagal terhubung: $e',
        'latency': stopwatch.elapsedMilliseconds,
      };
    }
  }

  /// Start background auto-sync timer
  void startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (OutboxManager().queueSize > 0 || !_isOnline) {
        flushOutbox();
      }
    });
  }

  /// Stop background auto-sync timer
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  /// Load catalog from local disk cache / SharedPreferences
  Future<bool> _loadCacheFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_prefKeyCatalogCache);
      if (content != null && content.isNotEmpty) {
        final json = jsonDecode(content) as Map<String, dynamic>;
        _applyCatalogData(json);
        _statusMessage = 'Dimuat dari cache lokal (Offline)';
        notifyListeners();
        return true;
      }
    } catch (_) {}

    try {
      if (_cacheFile.existsSync()) {
        final content = _cacheFile.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _applyCatalogData(json);
        _statusMessage = 'Dimuat dari cache lokal (Offline)';
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[PosSyncService] Error reading cache file: $e');
    }
    return false;
  }

  /// Save catalog data to local disk cache & SharedPreferences
  void _saveCacheToDisk(Map<String, dynamic> data) async {
    final str = jsonEncode(data);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyCatalogCache, str);
    } catch (_) {}

    try {
      _cacheFile.writeAsStringSync(str);
    } catch (e) {
      debugPrint('[PosSyncService] Error writing cache file: $e');
    }
  }

  /// Load pending outbox items from disk
  void _loadOutboxFromDisk() {
    try {
      if (_outboxFile.existsSync()) {
        final content = _outboxFile.readAsStringSync();
        final list = jsonDecode(content) as List<dynamic>;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          OutboxManager().enqueue(OutboxItem(
            uuid: map['uuid'] as String,
            orderNo: map['order_no'] as String,
            clientCreatedAt: DateTime.parse(map['client_created_at'] as String),
            payload: map['payload'] as Map<String, dynamic>,
          ));
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PosSyncService] Error reading outbox file: $e');
    }
  }

  /// Save pending outbox items to disk
  void _saveOutboxToDisk() {
    try {
      final items = OutboxManager().getPendingItems(limit: 1000);
      final list = items.map((e) => e.toMap()).toList();
      _outboxFile.writeAsStringSync(jsonEncode(list));
    } catch (e) {
      debugPrint('[PosSyncService] Error writing outbox file: $e');
    }
  }

  /// Fetch full catalog from backend (`/api/v1/sync/pull`)
  Future<bool> fetchCatalog({dynamic branchId}) async {
    _isSyncing = true;
    notifyListeners();

    try {
      final targetBranchId = branchId ?? _branch['id'] ?? currentUser?['branch_id'];
      String pullUrl = '$baseUrl/sync/pull';
      if (targetBranchId != null) {
        pullUrl += '?branch_id=$targetBranchId';
      }
      final uri = Uri.parse(pullUrl);
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      if (targetBranchId != null) {
        headers['X-Branch-Id'] = targetBranchId.toString();
      }

      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'] as Map<String, dynamic>;
          _applyCatalogData(data);
          _saveCacheToDisk(data);

          if (data['server_time'] != null) {
            TrustedClock().syncWithServer(DateTime.parse(data['server_time'] as String));
          }

          _isOnline = true;
          _lastSyncTime = DateTime.now();
          _statusMessage = 'Data backend tersinkronisasi';
          _isSyncing = false;
          notifyListeners();
          return true;
        }
      }
      throw HttpException('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[PosSyncService] Pull failed: $e. Operating in OFFLINE mode.');
      _isOnline = false;
      _statusMessage = 'Mode Offline (Menggunakan cache lokal)';
      // Fallback to cache if available
      _loadCacheFromDisk();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  @visibleForTesting
  void applyCatalogDataForTesting(Map<String, dynamic> data) => _applyCatalogData(data);

  void _applyCatalogData(Map<String, dynamic> data) {
    _branch = (data['branch'] as Map<String, dynamic>?) ?? {};
    _categories = ((data['categories'] as List<dynamic>?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    _products = ((data['products'] as List<dynamic>?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    _orderTypes = ((data['order_types'] as List<dynamic>?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    _tables = ((data['tables'] as List<dynamic>?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    _paymentMethods = ((data['payment_methods'] as List<dynamic>?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    _cashiers = ((data['users'] as List<dynamic>?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _systemSettings = (data['settings'] as Map<String, dynamic>?) ?? {};

    // Map multi-prices from product_prices
    _productPrices = ((data['product_prices'] as List<dynamic>?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    for (final p in _products) {
      final pId = p['id'];
      final defaultOtId = _orderTypes.isNotEmpty ? _orderTypes.first['id'] : 1;
      p['price'] = getProductPrice(pId, defaultOtId, defaultPrice: (p['manual_cost'] as num?)?.toInt() ?? 0);
    }
  }

  /// Get specific product price for the selected order type
  int getProductPrice(dynamic productId, dynamic orderTypeId, {int defaultPrice = 0}) {
    if (_productPrices.isEmpty) return defaultPrice;

    // 1. Match exact sellable_id and order_type_id
    final exact = _productPrices.firstWhere(
      (pr) => pr['sellable_id'] == productId && pr['order_type_id'] == orderTypeId,
      orElse: () => {},
    );
    if (exact.isNotEmpty && exact['price'] != null) {
      return (exact['price'] as num).toInt();
    }

    // 2. Fallback to any price for this sellable_id
    final anyPrice = _productPrices.firstWhere(
      (pr) => pr['sellable_id'] == productId,
      orElse: () => {},
    );
    if (anyPrice.isNotEmpty && anyPrice['price'] != null) {
      return (anyPrice['price'] as num).toInt();
    }

    return defaultPrice;
  }

  /// Enqueue order to outbox and immediately attempt auto-sync
  Future<bool> submitOrder(Map<String, dynamic> orderPayload) async {
    final uuid = orderPayload['uuid'] as String;
    final orderNo = orderPayload['order_no'] as String;

    final item = OutboxItem(
      uuid: uuid,
      orderNo: orderNo,
      clientCreatedAt: DateTime.parse(orderPayload['client_created_at'] as String),
      payload: orderPayload,
    );

    // Guarantee persistence locally first
    OutboxManager().enqueue(item);
    _saveOutboxToDisk();
    notifyListeners();

    // Attempt instant push
    return await flushOutbox();
  }

  /// Flush pending outbox queue to backend (`/api/v1/sync/push`)
  Future<bool> flushOutbox() async {
    if (OutboxManager().queueSize == 0) {
      return true;
    }

    final pending = OutboxManager().getPendingItems(limit: 50);
    if (pending.isEmpty) return true;

    _isSyncing = true;
    notifyListeners();

    try {
      final itemsPayload = pending.map((e) => e.payload).toList();
      final uri = Uri.parse('$baseUrl/sync/push');
      final targetBranchId = _branch['id'] ?? currentUser?['branch_id'];

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      };
      if (targetBranchId != null) {
        headers['X-Branch-Id'] = targetBranchId.toString();
      }

      final bodyMap = <String, dynamic>{
        'items': itemsPayload,
      };
      if (targetBranchId != null) {
        bodyMap['branch_id'] = targetBranchId;
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(bodyMap),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (body['results'] as List<dynamic>?) ?? [];

        for (final res in results) {
          final resMap = res as Map<String, dynamic>;
          final uuid = resMap['uuid'] as String?;
          final status = resMap['status'] as String?;
          if (uuid != null && (status == 'processed' || status == 'duplicate_ok' || status == 'auto_resolved')) {
            OutboxManager().acknowledgeFinalStatus(uuid);
          }
        }

        _saveOutboxToDisk();
        _isOnline = true;
        _lastSyncTime = DateTime.now();
        _statusMessage = 'Semua antrean offline berhasil disinkronkan';
        _isSyncing = false;
        notifyListeners();
        return true;
      }
      throw HttpException('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[PosSyncService] Push failed: $e. Outbox orders retained safely.');
      _isOnline = false;
      _statusMessage = 'Offline (${OutboxManager().queueSize} antrean tersimpan lokal)';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }
}
