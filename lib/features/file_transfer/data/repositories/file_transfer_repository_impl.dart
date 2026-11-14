import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/error_message_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/notifications/transfer_foreground_service.dart';
import '../../../../core/storage/public_downloads_publisher.dart';
import '../../../../core/storage/storage_path_label.dart';
import '../../../../core/storage/upload_file_validator.dart';
import '../../domain/entities/file_item.dart';
import '../../domain/entities/transfer_task.dart';
import '../../domain/repositories/file_transfer_repository.dart';
import '../datasources/file_remote_data_source.dart';

class FileTransferRepositoryImpl implements FileTransferRepository {
  final FileRemoteDataSource remoteDataSource;
  final NotificationService notificationService;
  final SharedPreferences? sharedPreferences;
  final TransferForegroundService foregroundService;
  final PublicDownloadsPublisher publicDownloadsPublisher;

  /// Injectable clock for unit tests (progress / persist / FGS throttles).
  final DateTime Function() _now;

  final Map<String, TransferTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final StreamController<TransferTask> _streamController =
      StreamController<TransferTask>.broadcast();
  final StreamController<void> _authExpiredController =
      StreamController<void>.broadcast();

  /// Ensures pause→resume does not reopen `.part` before the prior IOSink closes.
  final Map<String, Future<void>> _downloadRunGates = {};

  /// Last progress value that was pushed on [transferStream] per task.
  final Map<String, double> _lastStreamedProgress = {};
  final Map<String, DateTime> _lastStreamEmitAt = {};
  DateTime? _lastPersistAt;
  String? _lastActiveSignature;
  DateTime? _lastFgsTextAt;

  static const String _storageKey = 'cached_transfer_tasks';
  static const Duration _streamThrottle = Duration(milliseconds: 250);
  static const double _streamProgressStep = 0.01; // 1%
  static const Duration _persistThrottle = Duration(seconds: 2);
  static const Duration _fgsTextThrottle = Duration(seconds: 1);

  FileTransferRepositoryImpl({
    required this.remoteDataSource,
    required this.notificationService,
    this.sharedPreferences,
    TransferForegroundService? foregroundService,
    PublicDownloadsPublisher? publicDownloadsPublisher,
    DateTime Function()? now,
  })  : foregroundService =
            foregroundService ?? NoopTransferForegroundService(),
        publicDownloadsPublisher =
            publicDownloadsPublisher ?? PublicDownloadsPublisher(),
        _now = now ?? DateTime.now {
    _loadSavedTasks();
  }

  void _loadSavedTasks() {
    if (sharedPreferences == null) return;
    try {
      final jsonStr = sharedPreferences!.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            var task = TransferTask.fromJson(item);
            // If the app was forcefully killed while running, mark as paused/interrupted
            if (task.isRunning || task.status == TransferStatus.queued) {
              task = task.copyWith(
                status: TransferStatus.paused,
                errorMessage: 'Transfer paused (app was closed)',
              );
            }
            _tasks[task.id] = task;
          }
        }
      }
    } catch (_) {}
  }

  void _persistTasks() {
    if (sharedPreferences == null) return;
    try {
      final list = _tasks.values.map((t) => t.toJson()).toList();
      sharedPreferences!.setString(_storageKey, jsonEncode(list));
    } catch (_) {}
  }

  @override
  Stream<TransferTask> get transferStream => _streamController.stream;

  @override
  Stream<void> get authExpiredStream => _authExpiredController.stream;

  @override
  List<TransferTask> getAllTasks() => _tasks.values.toList();

  void _signalAuthExpired() {
    if (!_authExpiredController.isClosed) {
      _authExpiredController.add(null);
    }
  }

  bool _isAuthFailure(Object e) =>
      e is AuthException ||
      (e is ServerException && e.statusCode == 401);

  @override
  Future<List<FileItem>> getFiles() async {
    return await remoteDataSource.listFiles();
  }

  @override
  Future<void> deleteFile(String fileName) async {
    await remoteDataSource.deleteFile(fileName);
  }

  int _notificationId(String taskId) => taskId.hashCode.abs() % 100000;

  String _activeSignature(Iterable<TransferTask> tasks) {
    final active = tasks
        .where(
          (t) =>
              t.status == TransferStatus.running ||
              t.status == TransferStatus.queued,
        )
        .map((t) => '${t.id}:${t.status.name}')
        .toList()
      ..sort();
    return active.join('|');
  }

  bool _isTerminal(TransferTask task) =>
      task.isCompleted ||
      task.isFailed ||
      task.isCancelled ||
      task.isPaused;

  /// Always updates in-memory map. Stream / prefs / FGS are throttled so chunk
  /// callbacks do not jsonEncode + hit the platform channel on every byte.
  void _emitTask(TransferTask task) {
    final previous = _tasks[task.id];
    final statusChanged = previous?.status != task.status;
    final terminal = _isTerminal(task);
    final completeProgress = task.progress >= 1.0;
    final force = statusChanged || terminal || completeProgress;

    _tasks[task.id] = task;

    final now = _now();

    // --- transferStream (≤250ms or ≥1% progress; always for force) ---
    final lastProgress = _lastStreamedProgress[task.id];
    final lastEmitAt = _lastStreamEmitAt[task.id];
    final progressDelta =
        lastProgress == null ? 1.0 : (task.progress - lastProgress).abs();
    final dueByTime = lastEmitAt == null ||
        now.difference(lastEmitAt) >= _streamThrottle;
    final dueByProgress = progressDelta >= _streamProgressStep;

    if (force || dueByTime || dueByProgress) {
      _lastStreamedProgress[task.id] = task.progress;
      _lastStreamEmitAt[task.id] = now;
      if (!_streamController.isClosed) {
        _streamController.add(task);
      }
    }

    // --- SharedPreferences (immediate on status/terminal; else ≤ every 2s) ---
    if (force ||
        _lastPersistAt == null ||
        now.difference(_lastPersistAt!) >= _persistThrottle) {
      _persistTasks();
      _lastPersistAt = now;
    }

    // --- FGS: sync when active set/status changes; text ≤ ~1/s ---
    final signature = _activeSignature(_tasks.values);
    final activeSetChanged = signature != _lastActiveSignature;
    final fgsTextDue = _lastFgsTextAt == null ||
        now.difference(_lastFgsTextAt!) >= _fgsTextThrottle;

    if (activeSetChanged || statusChanged || terminal || fgsTextDue) {
      if (activeSetChanged || statusChanged || terminal) {
        _lastActiveSignature = signature;
      }
      if (fgsTextDue || activeSetChanged || statusChanged || terminal) {
        _lastFgsTextAt = now;
      }
      unawaited(foregroundService.syncWithTasks(_tasks.values));
    }
  }

  @override
  Future<TransferTask> startUpload({
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    final exists = await file.exists();
    final fileLength = exists ? await file.length() : 0;
    final validationError = UploadFileValidator.validate(
      exists: exists,
      sizeBytes: fileLength,
      maxBytes: ApiConstants.maxUploadBytes,
    );
    if (validationError != null) {
      throw TransferException(message: validationError);
    }

    final taskId = 'up_${DateTime.now().millisecondsSinceEpoch}';

    final initialTask = TransferTask(
      id: taskId,
      fileName: fileName,
      localPath: filePath,
      type: TransferType.upload,
      status: TransferStatus.running,
      bytesTransferred: 0,
      totalBytes: fileLength,
      progress: 0.0,
      createdAt: DateTime.now(),
    );

    _emitTask(initialTask);
    _executeUpload(initialTask);
    return initialTask;
  }

  Future<void> _executeUpload(TransferTask task) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;
    final notifId = _notificationId(task.id);

    try {
      await remoteDataSource.uploadFile(
        filePath: task.localPath,
        fileName: task.fileName,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (cancelToken.isCancelled) return;
          final progress = total > 0 ? (sent / total).clamp(0.0, 1.0) : 0.0;
          final updated = task.copyWith(
            bytesTransferred: sent,
            totalBytes: total,
            progress: progress,
            status: TransferStatus.running,
          );
          _emitTask(updated);

          // Skip per-task progress tray while FGS already shows an ongoing notif.
          if (!foregroundService.coversProgressNotification) {
            notificationService.showProgressNotification(
              id: notifId,
              title: 'Uploading ${task.fileName}',
              body: '${(progress * 100).toStringAsFixed(1)}% completed',
              progress: (progress * 100).toInt(),
              maxProgress: 100,
              payload: 'upload_${task.id}',
            );
          }
        },
      );

      // Completed successfully
      final completedTask = task.copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
        bytesTransferred: task.totalBytes,
        completedAt: DateTime.now(),
      );
      _cancelTokens.remove(task.id);
      _emitTask(completedTask);

      // Persistent system notification on finish
      await notificationService.showCompletionNotification(
        id: notifId,
        title: 'Upload Complete',
        body: '${task.fileName} uploaded successfully.',
        payload: 'upload_${task.id}',
      );
    } catch (e) {
      if (cancelToken.isCancelled) {
        // Paused or Cancelled handled in respective functions
        return;
      }
      if (_isAuthFailure(e)) {
        _signalAuthExpired();
      }
      final failedTask = task.copyWith(
        status: TransferStatus.failed,
        errorMessage: ErrorMessageMapper.from(
          e,
          fallback: 'Upload failed.',
        ),
      );
      _cancelTokens.remove(task.id);
      _emitTask(failedTask);

      await notificationService.showErrorNotification(
        id: notifId,
        title: 'Upload Failed',
        body: '${task.fileName}: ${failedTask.errorMessage}',
        payload: 'upload_${task.id}',
      );
    }
  }

  @override
  Future<TransferTask> startDownload({
    required String fileName,
    String? customSavePath,
  }) async {
    final taskId = 'down_${DateTime.now().millisecondsSinceEpoch}';

    String savePath = customSavePath ?? '';
    if (savePath.isEmpty) {
      final dir = await _resolveStorageDirectory();
      savePath = '${dir.path}/$fileName';
    }

    final initialTask = TransferTask(
      id: taskId,
      fileName: fileName,
      localPath: savePath,
      type: TransferType.download,
      status: TransferStatus.running,
      bytesTransferred: 0,
      totalBytes: 0,
      progress: 0.0,
      createdAt: DateTime.now(),
    );

    _emitTask(initialTask);
    _executeDownload(initialTask);
    return initialTask;
  }

  Future<Directory> _resolveStorageDirectory() async {
    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
      final downloadFolder = Directory('${dir.path}/pos_downloads');
      if (!await downloadFolder.exists()) {
        await downloadFolder.create(recursive: true);
      }
      return downloadFolder;
    } catch (_) {
      dir = Directory.systemTemp;
      return dir;
    }
  }

  Future<void> _awaitPriorDownloadRun(String taskId) async {
    final prior = _downloadRunGates[taskId];
    if (prior == null) return;
    try {
      await prior;
    } catch (_) {}
  }

  Future<void> _finalizeDownloadFromPart({
    required TransferTask task,
    required File partFile,
    required int downloadedBytes,
    required int notifId,
  }) async {
    final finalFile = File(task.localPath);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    await partFile.rename(task.localPath);

    final publicLabel = await publicDownloadsPublisher.publish(
      sourcePath: task.localPath,
      fileName: task.fileName,
    );

    final completedTask = task.copyWith(
      status: TransferStatus.completed,
      progress: 1.0,
      bytesTransferred: downloadedBytes,
      totalBytes: downloadedBytes,
      completedAt: DateTime.now(),
      publicPathLabel: publicLabel,
    );
    _cancelTokens.remove(task.id);
    _emitTask(completedTask);

    await notificationService.showCompletionNotification(
      id: notifId,
      title: 'Download Complete',
      body:
          '${task.fileName} saved to ${friendlyStoragePath(task.localPath, publicPathLabel: publicLabel)}',
      payload: 'download_${task.id}',
    );
  }

  bool _isRangeNotSatisfiable(Object e) {
    if (e is ServerException && e.statusCode == 416) return true;
    if (e is DioException && e.response?.statusCode == 416) return true;
    return false;
  }

  Future<void> _executeDownload(TransferTask task) async {
    // Wait until any previous run for this task has closed its IOSink.
    await _awaitPriorDownloadRun(task.id);

    final runDone = Completer<void>();
    _downloadRunGates[task.id] = runDone.future;
    try {
      await _runDownloadAttempt(task, allowRestartFromZero: true);
    } finally {
      if (!runDone.isCompleted) {
        runDone.complete();
      }
    }
  }

  Future<void> _runDownloadAttempt(
    TransferTask task, {
    required bool allowRestartFromZero,
  }) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;
    final notifId = _notificationId(task.id);

    final partFilePath = '${task.localPath}.part';
    final partFile = File(partFilePath);

    int existingBytes = 0;
    if (await partFile.exists()) {
      existingBytes = await partFile.length();
    }

    IOSink? sink;

    try {
      final response = await remoteDataSource.downloadFileStream(
        fileName: task.fileName,
        startByte: existingBytes,
        cancelToken: cancelToken,
      );

      // HTTP 416: range not satisfiable — .part is often already complete.
      if (response.statusCode == 416) {
        if (existingBytes > 0 && await partFile.exists()) {
          await _finalizeDownloadFromPart(
            task: task,
            partFile: partFile,
            downloadedBytes: existingBytes,
            notifId: notifId,
          );
          return;
        }
        if (allowRestartFromZero) {
          if (await partFile.exists()) {
            await partFile.delete();
          }
          await _runDownloadAttempt(
            task.copyWith(bytesTransferred: 0, progress: 0),
            allowRestartFromZero: false,
          );
          return;
        }
        throw const ServerException(
          message: 'Download range not satisfiable.',
          statusCode: 416,
        );
      }

      final isPartial = response.statusCode == 206;
      final contentLengthHeader =
          response.headers.value(HttpHeaders.contentLengthHeader);
      final remainingBytes = contentLengthHeader != null
          ? int.tryParse(contentLengthHeader) ?? 0
          : 0;

      final int totalBytes =
          isPartial ? (existingBytes + remainingBytes) : remainingBytes;

      if (!isPartial && existingBytes > 0) {
        // Server doesn't support range or restarted from 0
        existingBytes = 0;
        await partFile.writeAsBytes([], mode: FileMode.write);
      }

      sink = partFile.openWrite(mode: FileMode.append);
      int downloadedBytes = existingBytes;

      await for (final chunk in response.data!.stream) {
        if (cancelToken.isCancelled) {
          break;
        }
        sink.add(chunk);
        downloadedBytes += chunk.length;

        final progress = totalBytes > 0
            ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;

        final updated = task.copyWith(
          bytesTransferred: downloadedBytes,
          totalBytes: totalBytes,
          progress: progress,
          status: TransferStatus.running,
        );
        _emitTask(updated);

        if (!foregroundService.coversProgressNotification) {
          notificationService.showProgressNotification(
            id: notifId,
            title: 'Downloading ${task.fileName}',
            body: '${(progress * 100).toStringAsFixed(1)}% completed',
            progress: (progress * 100).toInt(),
            maxProgress: 100,
            payload: 'download_${task.id}',
          );
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (cancelToken.isCancelled) return;

      await _finalizeDownloadFromPart(
        task: task,
        partFile: partFile,
        downloadedBytes: downloadedBytes,
        notifId: notifId,
      );
    } catch (e) {
      if (sink != null) {
        try {
          await sink.flush();
        } catch (_) {}
        await sink.close();
        sink = null;
      }
      if (cancelToken.isCancelled) return;

      // Dio may still surface 416 as an exception depending on adapter.
      if (_isRangeNotSatisfiable(e) &&
          existingBytes > 0 &&
          await partFile.exists()) {
        await _finalizeDownloadFromPart(
          task: task,
          partFile: partFile,
          downloadedBytes: existingBytes,
          notifId: notifId,
        );
        return;
      }

      if (_isAuthFailure(e)) {
        _signalAuthExpired();
      }

      final failedTask = task.copyWith(
        status: TransferStatus.failed,
        errorMessage: ErrorMessageMapper.from(
          e,
          fallback: 'Download failed.',
        ),
      );
      _cancelTokens.remove(task.id);
      _emitTask(failedTask);

      await notificationService.showErrorNotification(
        id: notifId,
        title: 'Download Failed',
        body: '${task.fileName}: ${failedTask.errorMessage}',
        payload: 'download_${task.id}',
      );
    }
  }

  @override
  Future<void> pauseTransfer(String taskId, {String? reason}) async {
    final task = _tasks[taskId];
    if (task == null || task.status != TransferStatus.running) return;

    final token = _cancelTokens[taskId];
    if (token != null && !token.isCancelled) {
      token.cancel(reason ?? 'User requested pause');
    }
    _cancelTokens.remove(taskId);

    final pausedTask = task.copyWith(
      status: TransferStatus.paused,
      errorMessage: reason,
    );
    _emitTask(pausedTask);

    final notifId = _notificationId(taskId);
    await notificationService.cancel(notifId);
  }

  @override
  Future<void> resumeTransfer(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != TransferStatus.paused) return;

    final runningTask = task.copyWith(
      status: TransferStatus.running,
      clearErrorMessage: true,
    );
    _emitTask(runningTask);

    if (task.type == TransferType.download) {
      // Gate inside _executeDownload waits for prior sink close.
      unawaited(_executeDownload(runningTask));
    } else {
      _executeUpload(runningTask);
    }
  }

  @override
  Future<void> cancelTransfer(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    final token = _cancelTokens[taskId];
    if (token != null && !token.isCancelled) {
      token.cancel('User cancelled transfer');
    }
    _cancelTokens.remove(taskId);

    // If downloading, clean up partial file
    if (task.type == TransferType.download) {
      try {
        final partFile = File('${task.localPath}.part');
        if (await partFile.exists()) {
          await partFile.delete();
        }
      } catch (_) {}
    }

    final cancelledTask = task.copyWith(
      status: TransferStatus.cancelled,
      errorMessage: 'Cancelled by user',
    );
    _emitTask(cancelledTask);

    final notifId = _notificationId(taskId);
    await notificationService.cancel(notifId);
  }

  @override
  Future<void> retryTransfer(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    final retryingTask = task.copyWith(
      status: TransferStatus.running,
      clearErrorMessage: true,
    );
    _emitTask(retryingTask);

    if (task.type == TransferType.download) {
      _executeDownload(retryingTask);
    } else {
      _executeUpload(retryingTask);
    }
  }

  @override
  Future<void> clearFinishedTasks() async {
    final removedIds = _tasks.entries
        .where((e) => e.value.isCompleted || e.value.isCancelled)
        .map((e) => e.key)
        .toList();

    if (removedIds.isEmpty) return;

    for (final id in removedIds) {
      _tasks.remove(id);
      _lastStreamedProgress.remove(id);
      _lastStreamEmitAt.remove(id);
      _cancelTokens.remove(id);
      _downloadRunGates.remove(id);
    }

    _persistTasks();
    // Refresh FGS / active signature after finished tasks disappear.
    _lastActiveSignature = null;
    unawaited(foregroundService.syncWithTasks(_tasks.values));
  }

  void dispose() {
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) {
        token.cancel('Repository disposed');
      }
    }
    _cancelTokens.clear();
    _streamController.close();
    _authExpiredController.close();
  }
}
