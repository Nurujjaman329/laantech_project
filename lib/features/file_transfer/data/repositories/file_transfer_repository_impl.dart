import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../domain/entities/file_item.dart';
import '../../domain/entities/transfer_task.dart';
import '../../domain/repositories/file_transfer_repository.dart';
import '../datasources/file_remote_data_source.dart';

class FileTransferRepositoryImpl implements FileTransferRepository {
  final FileRemoteDataSource remoteDataSource;
  final NotificationService notificationService;
  final SharedPreferences? sharedPreferences;

  final Map<String, TransferTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final StreamController<TransferTask> _streamController =
      StreamController<TransferTask>.broadcast();

  static const String _storageKey = 'cached_transfer_tasks';

  FileTransferRepositoryImpl({
    required this.remoteDataSource,
    required this.notificationService,
    this.sharedPreferences,
  }) {
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
  List<TransferTask> getAllTasks() => _tasks.values.toList();

  @override
  Future<List<FileItem>> getFiles() async {
    return await remoteDataSource.listFiles();
  }

  @override
  Future<void> deleteFile(String fileName) async {
    await remoteDataSource.deleteFile(fileName);
  }

  int _notificationId(String taskId) => taskId.hashCode.abs() % 100000;

  void _emitTask(TransferTask task) {
    _tasks[task.id] = task;
    _persistTasks();
    if (!_streamController.isClosed) {
      _streamController.add(task);
    }
  }

  @override
  Future<TransferTask> startUpload({
    required String filePath,
    required String fileName,
  }) async {
    final taskId = 'up_${DateTime.now().millisecondsSinceEpoch}';
    final file = File(filePath);
    final fileLength = await file.exists() ? await file.length() : 0;

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

          // Update system tray progress notification
          notificationService.showProgressNotification(
            id: notifId,
            title: 'Uploading ${task.fileName}',
            body: '${(progress * 100).toStringAsFixed(1)}% completed',
            progress: (progress * 100).toInt(),
            maxProgress: 100,
            payload: 'upload_${task.id}',
          );
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
      final failedTask = task.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      _cancelTokens.remove(task.id);
      _emitTask(failedTask);

      await notificationService.showErrorNotification(
        id: notifId,
        title: 'Upload Failed',
        body: 'Error uploading ${task.fileName}: ${failedTask.errorMessage}',
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

  Future<void> _executeDownload(TransferTask task) async {
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

      final isPartial = response.statusCode == 206;
      final contentLengthHeader = response.headers.value(HttpHeaders.contentLengthHeader);
      final remainingBytes = contentLengthHeader != null ? int.tryParse(contentLengthHeader) ?? 0 : 0;
      
      final int totalBytes = isPartial ? (existingBytes + remainingBytes) : remainingBytes;

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

        // Update system notification
        notificationService.showProgressNotification(
          id: notifId,
          title: 'Downloading ${task.fileName}',
          body: '${(progress * 100).toStringAsFixed(1)}% completed',
          progress: (progress * 100).toInt(),
          maxProgress: 100,
          payload: 'download_${task.id}',
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (cancelToken.isCancelled) return;

      // Rename .part file to final destination
      final finalFile = File(task.localPath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await partFile.rename(task.localPath);

      final completedTask = task.copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
        bytesTransferred: downloadedBytes,
        totalBytes: downloadedBytes,
        completedAt: DateTime.now(),
      );
      _cancelTokens.remove(task.id);
      _emitTask(completedTask);

      await notificationService.showCompletionNotification(
        id: notifId,
        title: 'Download Complete',
        body: '${task.fileName} saved to device.',
        payload: 'download_${task.id}',
      );
    } catch (e) {
      if (sink != null) {
        await sink.close();
      }
      if (cancelToken.isCancelled) return;

      final failedTask = task.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      _cancelTokens.remove(task.id);
      _emitTask(failedTask);

      await notificationService.showErrorNotification(
        id: notifId,
        title: 'Download Failed',
        body: 'Error downloading ${task.fileName}: ${failedTask.errorMessage}',
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
      _executeDownload(runningTask);
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

  void dispose() {
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) {
        token.cancel('Repository disposed');
      }
    }
    _cancelTokens.clear();
    _streamController.close();
  }
}
