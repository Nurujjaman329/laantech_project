import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/constants/api_constants.dart';

void main() {
  group('ApiConstants Tests', () {
    test('should have expected base URLs and endpoints', () {
      expect(ApiConstants.baseUrl, 'http://108.136.142.112:90');
      expect(ApiConstants.tokenEndpoint, '/token');
      expect(ApiConstants.listFilesEndpoint, '/get');
      expect(ApiConstants.uploadEndpoint, '/upload');
      expect(ApiConstants.downloadEndpoint, '/get');
      expect(ApiConstants.deleteEndpoint, '/delete');
    });

    test('should have sensible timeout durations', () {
      expect(ApiConstants.connectTimeout.inSeconds, 30);
      expect(ApiConstants.receiveTimeout.inSeconds, 60);
      expect(ApiConstants.sendTimeout.inMinutes, 5);
      // Upload send deadline must be much longer than the default 5-minute cap.
      expect(
        ApiConstants.uploadSendTimeout,
        greaterThan(ApiConstants.sendTimeout),
      );
      expect(ApiConstants.uploadSendTimeout.inHours, greaterThanOrEqualTo(1));
      expect(ApiConstants.maxUploadBytes, greaterThan(50 * 1024 * 1024));
    });
  });
}
