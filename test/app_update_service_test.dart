import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/update/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService Tests', () {
    late AppUpdateService service;

    setUp(() {
      service = AppUpdateService.instance;
      service.resetForTesting();
    });

    test('Initial state has default version and no pending update', () {
      expect(service.currentVersion, '1.0.7');
      expect(service.currentBuildNumber, '8');
      expect(service.hasUpdate, false);
      expect(service.isDownloading, false);
      expect(service.isChecking, false);
      expect(service.downloadProgress, 0);
      expect(service.errorMessage, isNull);
    });

    test('resetForTesting clears all state variables', () {
      service.hasUpdate = true;
      service.latestVersion = '2.0.0';
      service.downloadProgress = 50;
      service.errorMessage = 'Some error';

      service.resetForTesting();

      expect(service.hasUpdate, false);
      expect(service.latestVersion, isNull);
      expect(service.downloadProgress, 0);
      expect(service.errorMessage, isNull);
    });

    test('startOtaUpdate gracefully guards on non-Android test environments', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        String? caughtError;
        await service.startOtaUpdate(
          targetUrl: 'http://example.com/test.apk',
          onError: (err) => caughtError = err,
        );

        expect(caughtError, isNotNull);
        expect(caughtError, contains('hanya didukung pada perangkat tablet/HP Android'));
        expect(service.errorMessage, contains('hanya didukung pada perangkat tablet/HP Android'));
        expect(service.isDownloading, false);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('checkForUpdate with unreachable server returns graceful error map', () async {
      final res = await service.checkForUpdate(customBaseUrl: 'http://127.0.0.1:54321/api/v1');
      expect(res['success'], false);
      expect(service.hasUpdate, false);
      expect(service.isChecking, false);
      expect(service.errorMessage, isNotNull);
    });

    test('cancelDownload stops downloading and resets progress', () {
      service.isDownloading = true;
      service.downloadProgress = 75;
      service.updateStatusText = 'Mengunduh...';

      service.cancelDownload();

      expect(service.isDownloading, false);
      expect(service.downloadProgress, 0);
      expect(service.updateStatusText, '');
    });
  });
}
