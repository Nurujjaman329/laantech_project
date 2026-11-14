import 'dart:io';

import 'package:flutter/foundation.dart';
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

/// Builds the FGS notification body for active (running/queued) transfers.
@visibleForTesting
String formatTransferForegroundProgressText(List<TransferTask> active) {
  if (active.isEmpty) return '';
  if (active.length == 1) {
    final t = active.first;
    final verb =
        t.type == TransferType.upload ? 'Uploading' : 'Downloading';
    final pct = (t.progress * 100).round();
    return '$verb ${t.fileName} · $pct%';
  }
  final avg =
      active.map((t) => t.progress).reduce((a, b) => a + b) / active.length;
  final pct = (avg * 100).round();
  return '${active.length} transfers · $pct% avg';
}

/// Starts / updates / stops a typed `dataSync` foreground service based on
/// active transfer tasks so uploads/downloads can continue when minimized.
abstract class TransferForegroundService {
  Future<void> init();
  Future<void> syncWithTasks(Iterable<TransferTask> tasks);

  /// When true, the FGS ongoing notification already covers progress — skip
  /// duplicate per-task progress tray notifications (completion/error still show).
  bool get coversProgressNotification;
}

class NoopTransferForegroundService implements TransferForegroundService {
  @override
  Future<void> init() async {}

  @override
  Future<void> syncWithTasks(Iterable<TransferTask> tasks) async {}

  @override
  bool get coversProgressNotification => false;
}

class TransferForegroundServiceImpl implements TransferForegroundService {
  static const _serviceId = 1042;
  static const _channelId = 'pos_transfer_foreground';
  static const _textThrottle = Duration(seconds: 1);

  /// Optional clock for tests.
  final DateTime Function() _now;
  final bool Function() _isAndroid;
  final Future<bool> Function() _isRunningService;
  final Future<ServiceRequestResult> Function({
    required String notificationTitle,
    required String notificationText,
  }) _startService;
  final Future<ServiceRequestResult> Function({
    required String notificationTitle,
    required String notificationText,
  }) _updateService;
  final Future<ServiceRequestResult> Function() _stopService;
  final bool _bypassNativeInit;

  bool _initialized = false;
  bool _coversProgress = false;
  String? _lastText;
  String? _lastActiveSignature;
  DateTime? _lastTextUpdateAt;

  TransferForegroundServiceImpl({
    DateTime Function()? now,
    bool Function()? isAndroid,
    Future<bool> Function()? isRunningService,
    Future<ServiceRequestResult> Function({
      required String notificationTitle,
      required String notificationText,
    })? startService,
    Future<ServiceRequestResult> Function({
      required String notificationTitle,
      required String notificationText,
    })? updateService,
    Future<ServiceRequestResult> Function()? stopService,
    this._bypassNativeInit = false,
  })  : _now = now ?? DateTime.now,
        _isAndroid = isAndroid ?? (() => Platform.isAndroid),
        _isRunningService = isRunningService ??
            (() => FlutterForegroundTask.isRunningService),
        _startService = startService ??
            (({
              required String notificationTitle,
              required String notificationText,
            }) =>
                FlutterForegroundTask.startService(
                  serviceId: _serviceId,
                  serviceTypes: const [ForegroundServiceTypes.dataSync],
                  notificationTitle: notificationTitle,
                  notificationText: notificationText,
                  callback: startTransferForegroundCallback,
                )),
        _updateService = updateService ??
            (({
              required String notificationTitle,
              required String notificationText,
            }) =>
                FlutterForegroundTask.updateService(
                  notificationTitle: notificationTitle,
                  notificationText: notificationText,
                )),
        _stopService = stopService ?? FlutterForegroundTask.stopService;

  @override
  bool get coversProgressNotification => _coversProgress;

  @override
  Future<void> init() async {
    if (_initialized || !_isAndroid() || _bypassNativeInit) {
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

  String _signature(List<TransferTask> active) {
    final parts = active.map((t) => '${t.id}:${t.status.name}').toList()
      ..sort();
    return parts.join('|');
  }

  @override
  Future<void> syncWithTasks(Iterable<TransferTask> tasks) async {
    if (!_isAndroid()) {
      _coversProgress = false;
      return;
    }
    if (!_initialized) await init();

    final active = tasks
        .where(
          (t) =>
              t.status == TransferStatus.running ||
              t.status == TransferStatus.queued,
        )
        .toList();

    final signature = _signature(active);
    final activeSetChanged = signature != _lastActiveSignature;
    final now = _now();

    if (active.isEmpty) {
      _coversProgress = false;
      _lastText = null;
      _lastActiveSignature = signature;
      _lastTextUpdateAt = null;
      if (await _isRunningService()) {
        await _stopService();
      }
      return;
    }

    final title = active.length == 1
        ? 'POS transfer'
        : '${active.length} POS transfers';
    final text = formatTransferForegroundProgressText(active);
    final combined = '$title|$text';

    final textDue = _lastTextUpdateAt == null ||
        now.difference(_lastTextUpdateAt!) >= _textThrottle;
    final textChanged = combined != _lastText;

    if (await _isRunningService()) {
      if (!activeSetChanged && !(textDue && textChanged)) {
        return;
      }
      final result = await _updateService(
        notificationTitle: title,
        notificationText: text,
      );
      if (result is ServiceRequestSuccess) {
        _coversProgress = true;
        _lastActiveSignature = signature;
        _lastText = combined;
        _lastTextUpdateAt = now;
      }
      return;
    }

    final result = await _startService(
      notificationTitle: title,
      notificationText: text,
    );
    if (result is ServiceRequestSuccess) {
      _coversProgress = true;
      _lastActiveSignature = signature;
      _lastText = combined;
      _lastTextUpdateAt = now;
    } else {
      _coversProgress = false;
    }
  }
}
