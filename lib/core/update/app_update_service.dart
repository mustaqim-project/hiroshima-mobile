// @req FR-POS-10, FSD-09
// In-App OTA Update & Version Checker Service for Hiroshima POS

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../sync/pos_sync_service.dart';

class AppUpdateService extends ChangeNotifier {
  static final AppUpdateService instance = AppUpdateService._internal();
  factory AppUpdateService() => instance;
  AppUpdateService._internal();

  String currentVersion = '1.0.7';
  String currentBuildNumber = '8';
  bool _initialized = false;

  bool isChecking = false;
  bool isDownloading = false;
  int downloadProgress = 0;
  String updateStatusText = '';
  String? errorMessage;

  bool hasUpdate = false;
  String? latestVersion;
  int? latestBuildNumber;
  String? downloadUrl;
  String? changelog;
  bool isMandatory = false;
  String? releaseDate;

  StreamSubscription<OtaEvent>? _otaSubscription;

  /// Initialize package info from platform safely
  Future<void> init() async {
    if (_initialized) return;
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version.isNotEmpty ? info.version : currentVersion;
      currentBuildNumber = info.buildNumber.isNotEmpty ? info.buildNumber : currentBuildNumber;
      _initialized = true;
      notifyListeners();
    } catch (_) {
      // In isolated tests without method channels, retain default fallback version
      _initialized = true;
    }
  }

  /// Check backend for available app updates
  Future<Map<String, dynamic>> checkForUpdate({String? customBaseUrl}) async {
    await init();
    isChecking = true;
    errorMessage = null;
    notifyListeners();

    try {
      final baseUrl = customBaseUrl ?? PosSyncService.instance.baseUrl;
      final uri = Uri.parse(
        '$baseUrl/app/check-update?version_name=$currentVersion&build_number=$currentBuildNumber',
      );

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          hasUpdate = body['has_update'] == true;
          latestVersion = body['latest_version']?.toString();
          latestBuildNumber = (body['latest_build_number'] as num?)?.toInt();
          downloadUrl = body['download_url']?.toString();
          changelog = body['changelog']?.toString();
          isMandatory = body['is_mandatory'] == true;
          releaseDate = body['release_date']?.toString();

          isChecking = false;
          notifyListeners();
          return {
            'success': true,
            'has_update': hasUpdate,
            'latest_version': latestVersion,
            'latest_build_number': latestBuildNumber,
            'download_url': downloadUrl,
            'changelog': changelog,
            'is_mandatory': isMandatory,
          };
        } else {
          errorMessage = body['message']?.toString() ?? 'Gagal memproses respons server';
        }
      } else {
        errorMessage = 'Server pembaruan mengembalikan status ${response.statusCode}';
      }

      isChecking = false;
      notifyListeners();
      return {'success': false, 'message': errorMessage ?? 'Gagal memeriksa pembaruan server'};
    } catch (e) {
      isChecking = false;
      errorMessage = 'Tidak dapat terhubung ke server pembaruan: $e';
      notifyListeners();
      return {'success': false, 'message': errorMessage};
    }
  }

  /// Start OTA APK download and trigger in-place update (Android)
  Future<void> startOtaUpdate({
    required String targetUrl,
    Function(int progress)? onProgress,
    Function(String error)? onError,
    VoidCallback? onComplete,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      const err = 'Fitur pembaruan langsung (OTA Update) hanya didukung pada perangkat tablet/HP Android.';
      errorMessage = err;
      onError?.call(err);
      notifyListeners();
      return;
    }

    try {
      await _otaSubscription?.cancel();
      isDownloading = true;
      downloadProgress = 0;
      updateStatusText = 'Mempersiapkan unduhan...';
      errorMessage = null;
      notifyListeners();

      _otaSubscription = OtaUpdate()
          .execute(targetUrl, destinationFilename: 'hiroshima_pos_update.apk')
          .listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final val = int.tryParse(event.value ?? '0') ?? 0;
              downloadProgress = val;
              updateStatusText = 'Mengunduh pembaruan ($val%)...';
              onProgress?.call(val);
              notifyListeners();
              break;
            case OtaStatus.INSTALLING:
            case OtaStatus.INSTALLATION_DONE:
              downloadProgress = 100;
              updateStatusText = 'Memasang pembaruan sistem...';
              isDownloading = false;
              notifyListeners();
              onComplete?.call();
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              isDownloading = false;
              errorMessage = 'Proses unduhan pembaruan sedang berjalan.';
              onError?.call(errorMessage!);
              notifyListeners();
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              isDownloading = false;
              errorMessage = 'Izin pemasangan aplikasi dari sumber ini belum diberikan.';
              onError?.call(errorMessage!);
              notifyListeners();
              break;
            case OtaStatus.INTERNAL_ERROR:
              isDownloading = false;
              errorMessage = 'Terjadi kesalahan sistem saat mengunduh pembaruan.';
              onError?.call(errorMessage!);
              notifyListeners();
              break;
            case OtaStatus.DOWNLOAD_ERROR:
              isDownloading = false;
              errorMessage = 'Gagal mengunduh file APK dari server.';
              onError?.call(errorMessage!);
              notifyListeners();
              break;
            case OtaStatus.CHECKSUM_ERROR:
              isDownloading = false;
              errorMessage = 'Verifikasi berkas APK gagal (Checksum Error).';
              onError?.call(errorMessage!);
              notifyListeners();
              break;
            case OtaStatus.INSTALLATION_ERROR:
              isDownloading = false;
              errorMessage = 'Gagal memasang paket pembaruan APK.';
              onError?.call(errorMessage!);
              notifyListeners();
              break;
            default:
              isDownloading = false;
              notifyListeners();
              break;
          }
        },
        onError: (dynamic error) {
          isDownloading = false;
          errorMessage = 'Gagal memproses pembaruan: $error';
          onError?.call(errorMessage!);
          notifyListeners();
        },
      );
    } catch (e) {
      isDownloading = false;
      errorMessage = 'Gagal memulai unduhan: $e';
      onError?.call(errorMessage!);
      notifyListeners();
    }
  }

  void cancelDownload() {
    _otaSubscription?.cancel();
    isDownloading = false;
    downloadProgress = 0;
    updateStatusText = '';
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _otaSubscription?.cancel();
    _initialized = false;
    currentVersion = '1.0.7';
    currentBuildNumber = '8';
    hasUpdate = false;
    latestVersion = null;
    latestBuildNumber = null;
    downloadUrl = null;
    changelog = null;
    isMandatory = false;
    isChecking = false;
    isDownloading = false;
    downloadProgress = 0;
    updateStatusText = '';
    errorMessage = null;
  }
}
