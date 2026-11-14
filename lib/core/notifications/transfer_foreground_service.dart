import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../features/file_transfer/domain/entities/transfer_task.dart';

/// Top-level entry for the FGS isolate. Dio transfers stay on the main isolate;
/// this handler only keeps the Android process eligible to continue while minimized.
@pragma('vm:entry-point')
void startTransferForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_TransferForegroundTaskHandler());
}

class _TransferForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat only — network work continues on the UI/main isolate.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}
}

/// Starts / updates / stops a typed `dataSync` foreground service based on
/// active transfer tasks so uploads/downloads can continue when minimized.
abstract class TransferForegroundService {
  Future<void> init();
  Future<void> syncWithTasks(Iterable<TransferTask> tasks);
}

class NoopTransferForegroundService implements TransferForegroundService {
  @override
  Future<void> init() async {}

  @override
  Future<void> syncWithTasks(Iterable<TransferTask> tasks) async {}
}

class TransferForegroundServiceImpl implements TransferForegroundService {
  static const _serviceId = 1042;
  static const _channelId = 'pos_transfer_foreground';

  bool _initialized = false;
  String? _lastText;

  @override
  Future<void> init() async {
    if (_initialized || !Platform.isAndroid) {
      _initialized = true;
      return;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: 'POS active transfers',
        channelDescription:
            'Ongoing notification while catalog uploads/downloads run.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    _initialized = true;
  }

  @override
  Future<void> syncWithTasks(Iterable<TransferTask> tasks) async {
    if (!Platform.isAndroid) return;
    if (!_initialized) await init();

    final active = tasks
        .where(
          (t) =>
              t.status == TransferStatus.running ||
              t.status == TransferStatus.queued,
        )
        .toList();

    if (active.isEmpty) {
      _lastText = null;
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      return;
    }

    final title = active.length == 1
        ? (active.first.type == TransferType.upload
            ? 'Uploading ${active.first.fileName}'
            : 'Downloading ${active.first.fileName}')
        : 'POS transfers running';

    final avgProgress = active
            .map((t) => t.progress)
            .fold<double>(0, (a, b) => a + b) /
        active.length;
    final text = active.length == 1
        ? '${(active.first.progress * 100).toStringAsFixed(0)}% · tap to return'
        : '${active.length} jobs · ${(avgProgress * 100).toStringAsFixed(0)}% avg · tap to return';

    if (await FlutterForegroundTask.isRunningService) {
      if (_lastText == text) return;
      _lastText = text;
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
      return;
    }

    _lastText = text;
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: title,
      notificationText: text,
      callback: startTransferForegroundCallback,
    );
  }
}
