import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/notifications/transfer_foreground_service.dart';
import 'package:laantech_task/features/file_transfer/domain/entities/transfer_task.dart';

TransferTask _task({
  required String id,
  required String fileName,
  required TransferType type,
  TransferStatus status = TransferStatus.running,
  double progress = 0,
}) {
  return TransferTask(
    id: id,
    fileName: fileName,
    localPath: '/tmp/$fileName',
    type: type,
    status: status,
    progress: progress,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('formatTransferForegroundProgressText', () {
    test('single upload shows verb, name, and percent', () {
      final text = formatTransferForegroundProgressText([
        _task(
          id: '1',
          fileName: 'catalog.csv',
          type: TransferType.upload,
          progress: 0.63,
        ),
      ]);
      expect(text, 'Uploading catalog.csv · 63%');
    });

    test('single download uses Downloading verb', () {
      final text = formatTransferForegroundProgressText([
        _task(
          id: '1',
          fileName: 'report.pdf',
          type: TransferType.download,
          progress: 0.4,
        ),
      ]);
      expect(text, 'Downloading report.pdf · 40%');
    });

    test('multiple transfers show count and average percent', () {
      final text = formatTransferForegroundProgressText([
        _task(
          id: '1',
          fileName: 'a.csv',
          type: TransferType.upload,
          progress: 0.2,
        ),
        _task(
          id: '2',
          fileName: 'b.csv',
          type: TransferType.download,
          progress: 0.62,
        ),
      ]);
      expect(text, '2 transfers · 41% avg');
    });
  });

  group('TransferForegroundServiceImpl coversProgressNotification', () {
    late bool running;
    late List<({String title, String text})> started;
    late List<({String title, String text})> updated;
    late DateTime clock;

    TransferForegroundServiceImpl build({
      Future<ServiceRequestResult> Function({
        required String notificationTitle,
        required String notificationText,
      })? startService,
      Future<ServiceRequestResult> Function({
        required String notificationTitle,
        required String notificationText,
      })? updateService,
    }) {
      return TransferForegroundServiceImpl(
        now: () => clock,
        isAndroid: () => true,
        bypassNativeInit: true,
        isRunningService: () async => running,
        startService: startService ??
            ({
              required String notificationTitle,
              required String notificationText,
            }) async {
              started.add((title: notificationTitle, text: notificationText));
              running = true;
              return const ServiceRequestSuccess();
            },
        updateService: updateService ??
            ({
              required String notificationTitle,
              required String notificationText,
            }) async {
              updated.add((title: notificationTitle, text: notificationText));
              return const ServiceRequestSuccess();
            },
        stopService: () async {
          running = false;
          return const ServiceRequestSuccess();
        },
      );
    }

    setUp(() {
      running = false;
      started = [];
      updated = [];
      clock = DateTime.utc(2026, 1, 1, 12);
    });

    test('sets coversProgress only after successful start', () async {
      final svc = build();
      expect(svc.coversProgressNotification, isFalse);

      await svc.syncWithTasks([
        _task(
          id: '1',
          fileName: 'catalog.csv',
          type: TransferType.upload,
          progress: 0.63,
        ),
      ]);

      expect(svc.coversProgressNotification, isTrue);
      expect(started, hasLength(1));
      expect(started.first.text, 'Uploading catalog.csv · 63%');
    });

    test('sets coversProgress false when start fails', () async {
      final svc = build(
        startService: ({
          required String notificationTitle,
          required String notificationText,
        }) async {
          return ServiceRequestFailure(error: Exception('denied'));
        },
      );

      await svc.syncWithTasks([
        _task(
          id: '1',
          fileName: 'catalog.csv',
          type: TransferType.upload,
          progress: 0.1,
        ),
      ]);

      expect(svc.coversProgressNotification, isFalse);
      expect(running, isFalse);
    });

    test('throttles text updates to at most once per second', () async {
      final svc = build();
      final task = _task(
        id: '1',
        fileName: 'catalog.csv',
        type: TransferType.upload,
        progress: 0.1,
      );

      await svc.syncWithTasks([task]);
      expect(started, hasLength(1));

      running = true;
      clock = clock.add(const Duration(milliseconds: 400));
      await svc.syncWithTasks([task.copyWith(progress: 0.2)]);
      expect(updated, isEmpty);

      clock = clock.add(const Duration(milliseconds: 700));
      await svc.syncWithTasks([task.copyWith(progress: 0.41)]);
      expect(updated, hasLength(1));
      expect(updated.first.text, 'Uploading catalog.csv · 41%');
      expect(svc.coversProgressNotification, isTrue);
    });

    test('clears coversProgress when no active transfers', () async {
      final svc = build();
      await svc.syncWithTasks([
        _task(
          id: '1',
          fileName: 'catalog.csv',
          type: TransferType.upload,
          progress: 0.5,
        ),
      ]);
      expect(svc.coversProgressNotification, isTrue);

      await svc.syncWithTasks(const []);
      expect(svc.coversProgressNotification, isFalse);
    });
  });
}
