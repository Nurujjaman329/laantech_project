import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/notifications/transfer_notification_router.dart';

void main() {
  group('TransferDeepLink.tryParse', () {
    test('maps upload payload to Upload tab', () {
      final link = TransferDeepLink.tryParse('upload_up_123');
      expect(link?.tabIndex, 1);
      expect(link?.taskId, 'up_123');
      expect(link?.showSheet, isTrue);
    });

    test('maps download payload to Download tab', () {
      final link = TransferDeepLink.tryParse('download_dl_456');
      expect(link?.tabIndex, 2);
      expect(link?.taskId, 'dl_456');
    });

    test('maps unknown/empty payload to Transfers tab', () {
      expect(TransferDeepLink.tryParse(null)?.tabIndex, 3);
      expect(TransferDeepLink.tryParse('')?.tabIndex, 3);
      expect(TransferDeepLink.tryParse('other')?.tabIndex, 3);
    });
  });

  group('TransferNotificationRouter', () {
    test('handlePayload sets pending and consume clears it', () {
      final router = TransferNotificationRouter();
      router.handlePayload('download_task_1');
      expect(router.pending.value?.tabIndex, 2);
      expect(router.pending.value?.taskId, 'task_1');

      router.consume();
      expect(router.pending.value, isNull);
      router.dispose();
    });
  });
}
