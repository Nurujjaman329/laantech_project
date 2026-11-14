import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laantech_task/core/errors/exceptions.dart';
import 'package:laantech_task/core/notifications/notification_service.dart';
import 'package:laantech_task/core/notifications/transfer_foreground_service.dart';
import 'package:laantech_task/core/storage/public_downloads_publisher.dart';
import 'package:laantech_task/core/storage/upload_file_validator.dart';
import 'package:laantech_task/features/file_transfer/data/datasources/file_remote_data_source.dart';
import 'package:laantech_task/features/file_transfer/data/models/file_item_model.dart';
import 'package:laantech_task/features/file_transfer/data/repositories/file_transfer_repository_impl.dart';
import 'package:laantech_task/features/file_transfer/domain/entities/transfer_task.dart';

class MockFileRemoteDataSource extends Mock implements FileRemoteDataSource {}
class MockNotificationService extends Mock implements NotificationService {}
class FakeCancelToken extends Fake implements CancelToken {}

class RecordingForegroundService implements TransferForegroundService {
  int syncCalls = 0;
  bool coverProgress;

  RecordingForegroundService({this.coverProgress = false});

  @override
  Future<void> init() async {}

  @override
  Future<void> syncWithTasks(Iterable<TransferTask> tasks) async {
    syncCalls++;
    // Mimic production: once active transfers exist, FGS covers progress.
    final active = tasks.any(
      (t) =>
          t.status == TransferStatus.running ||
          t.status == TransferStatus.queued,
    );
    if (active) coverProgress = true;
    if (!active) coverProgress = false;
  }

  @override
  bool get coversProgressNotification => coverProgress;
}

class _RecordingPublisher extends PublicDownloadsPublisher {
  int calls = 0;

  @override
  Future<String?> publish({
    required String sourcePath,
    required String fileName,
  }) async {
    calls++;
    return 'Downloads/POS_Transfers/$fileName';
  }
}

Future<File> _tempUploadFile({
  String name = 'upload_valid.csv',
  String contents = 'id,sku\n1,A\n',
}) async {
  final file = File('${Directory.systemTemp.path}/$name');
  await file.writeAsString(contents);
  return file;
}

void main() {
  late MockFileRemoteDataSource mockRemoteDataSource;
  late MockNotificationService mockNotificationService;
  late FileTransferRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(FakeCancelToken());
  });

  setUp(() {
    mockRemoteDataSource = MockFileRemoteDataSource();
    mockNotificationService = MockNotificationService();
    repository = FileTransferRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      notificationService: mockNotificationService,
    );
  });

  tearDown(() {
    repository.dispose();
  });

  group('FileTransferRepositoryImpl getFiles & deleteFile', () {
    test('getFiles returns list from remoteDataSource', () async {
      final items = [const FileItemModel(name: 'test.csv', size: 100)];
      when(() => mockRemoteDataSource.listFiles()).thenAnswer((_) async => items);

      final result = await repository.getFiles();

      expect(result, items);
      verify(() => mockRemoteDataSource.listFiles()).called(1);
    });

    test('deleteFile delegates to remoteDataSource', () async {
      when(() => mockRemoteDataSource.deleteFile('item.csv')).thenAnswer((_) async {});

      await repository.deleteFile('item.csv');

      verify(() => mockRemoteDataSource.deleteFile('item.csv')).called(1);
    });
  });

  group('FileTransferRepositoryImpl pause & cancel', () {
    test('pauseTransfer transitions task to paused state and cancels active notification', () async {
      final localFile = await _tempUploadFile(name: 'pause_upload.csv');
      addTearDown(() async {
        if (await localFile.exists()) await localFile.delete();
      });

      when(() => mockNotificationService.cancel(any())).thenAnswer((_) async {});
      when(() => mockRemoteDataSource.uploadFile(
            filePath: any(named: 'filePath'),
            fileName: any(named: 'fileName'),
            onSendProgress: any(named: 'onSendProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((invocation) async {
        // Simulate a transfer that remains in progress until cancelled
        final cancelToken = invocation.namedArguments[#cancelToken] as CancelToken;
        while (!cancelToken.isCancelled) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
        throw DioException(
          requestOptions: RequestOptions(path: '/upload'),
          type: DioExceptionType.cancel,
        );
      });

      final task = await repository.startUpload(
        filePath: localFile.path,
        fileName: 'test.csv',
      );

      await repository.pauseTransfer(task.id);

      final updatedTask = repository.getAllTasks().firstWhere((t) => t.id == task.id);
      expect(updatedTask.status, TransferStatus.paused);
      verify(() => mockNotificationService.cancel(any())).called(1);
    });

    test('cancelTransfer transitions task to cancelled state', () async {
      final localFile = await _tempUploadFile(name: 'cancel_upload.csv');
      addTearDown(() async {
        if (await localFile.exists()) await localFile.delete();
      });

      when(() => mockNotificationService.cancel(any())).thenAnswer((_) async {});
      when(() => mockRemoteDataSource.uploadFile(
            filePath: any(named: 'filePath'),
            fileName: any(named: 'fileName'),
            onSendProgress: any(named: 'onSendProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((invocation) async {
        final cancelToken = invocation.namedArguments[#cancelToken] as CancelToken;
        while (!cancelToken.isCancelled) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
        throw DioException(
          requestOptions: RequestOptions(path: '/upload'),
          type: DioExceptionType.cancel,
        );
      });

      final task = await repository.startUpload(
        filePath: localFile.path,
        fileName: 'test.csv',
      );

      await repository.cancelTransfer(task.id);

      final updatedTask = repository.getAllTasks().firstWhere((t) => t.id == task.id);
      expect(updatedTask.status, TransferStatus.cancelled);
    });
  });

  group('FileTransferRepositoryImpl notification dedupe', () {
    test('skips per-task progress notifications when FGS covers progress',
        () async {
      final localFile =
          await _tempUploadFile(name: 'notif_dedupe_upload.csv');
      addTearDown(() async {
        if (await localFile.exists()) await localFile.delete();
      });

      final foreground = RecordingForegroundService(coverProgress: true);
      final repo = FileTransferRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        notificationService: mockNotificationService,
        foregroundService: foreground,
      );
      addTearDown(repo.dispose);

      when(() => mockRemoteDataSource.uploadFile(
            filePath: any(named: 'filePath'),
            fileName: any(named: 'fileName'),
            onSendProgress: any(named: 'onSendProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onSendProgress] as ProgressCallback;
        onProgress(50, 100);
        onProgress(100, 100);
        return Response(
          requestOptions: RequestOptions(path: '/upload'),
          statusCode: 200,
        );
      });
      when(() => mockNotificationService.showCompletionNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      await repo.startUpload(
        filePath: localFile.path,
        fileName: 'notif_dedupe_upload.csv',
      );

      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (repo.getAllTasks().every((t) => !t.isCompleted) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      verifyNever(
        () => mockNotificationService.showProgressNotification(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          progress: any(named: 'progress'),
          maxProgress: any(named: 'maxProgress'),
          payload: any(named: 'payload'),
        ),
      );
      verify(
        () => mockNotificationService.showCompletionNotification(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });
  });

  group('FileTransferRepositoryImpl download resilience', () {
    test('HTTP 416 with existing .part finalizes as completed (not failed)',
        () async {
      final dir = await Directory.systemTemp.createTemp('pos_416_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final savePath = '${dir.path}/catalog.bin';
      final part = File('$savePath.part');
      await part.writeAsBytes([1, 2, 3, 4, 5]);

      when(() => mockRemoteDataSource.downloadFileStream(
            fileName: any(named: 'fileName'),
            startByte: any(named: 'startByte'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer(
        (_) async => Response<ResponseBody>(
          requestOptions: RequestOptions(path: '/get'),
          statusCode: 416,
          data: ResponseBody.fromString('', 416),
        ),
      );
      when(() => mockNotificationService.showCompletionNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      final publisher = _RecordingPublisher();
      final repo = FileTransferRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        notificationService: mockNotificationService,
        publicDownloadsPublisher: publisher,
      );
      addTearDown(repo.dispose);

      final events = <TransferTask>[];
      final sub = repo.transferStream.listen(events.add);

      await repo.startDownload(
        fileName: 'catalog.bin',
        customSavePath: savePath,
      );

      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (!events.any((e) => e.isCompleted) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await sub.cancel();

      expect(events.any((e) => e.isFailed), isFalse);
      expect(events.any((e) => e.isCompleted), isTrue);
      expect(await File(savePath).exists(), isTrue);
      expect(await part.exists(), isFalse);
      expect(publisher.calls, 1);
    });

    test('AuthException on download signals authExpiredStream', () async {
      final dir = await Directory.systemTemp.createTemp('pos_401_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final savePath = '${dir.path}/secure.bin';

      when(() => mockRemoteDataSource.downloadFileStream(
            fileName: any(named: 'fileName'),
            startByte: any(named: 'startByte'),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(const AuthException(message: 'Unauthorized'));
      when(() => mockNotificationService.showErrorNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      final repo = FileTransferRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        notificationService: mockNotificationService,
      );
      addTearDown(repo.dispose);

      var authExpired = false;
      final authSub = repo.authExpiredStream.listen((_) => authExpired = true);
      final events = <TransferTask>[];
      final sub = repo.transferStream.listen(events.add);

      await repo.startDownload(
        fileName: 'secure.bin',
        customSavePath: savePath,
      );

      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (!events.any((e) => e.isFailed) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await sub.cancel();
      await authSub.cancel();

      expect(authExpired, isTrue);
      expect(events.any((e) => e.isFailed), isTrue);
      expect(
        events.last.errorMessage?.toLowerCase(),
        contains('session expired'),
      );
    });
  });

  group('FileTransferRepositoryImpl clearFinishedTasks', () {
    test('removes completed/cancelled from memory and SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final completed = TransferTask(
        id: 'done_1',
        fileName: 'done.csv',
        localPath: '/tmp/done.csv',
        type: TransferType.upload,
        status: TransferStatus.completed,
        progress: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        completedAt: DateTime.utc(2026, 1, 1, 1),
      );
      final cancelled = TransferTask(
        id: 'cancel_1',
        fileName: 'cancel.csv',
        localPath: '/tmp/cancel.csv',
        type: TransferType.download,
        status: TransferStatus.cancelled,
        createdAt: DateTime.utc(2026, 1, 2),
      );
      final running = TransferTask(
        id: 'run_1',
        fileName: 'run.csv',
        localPath: '/tmp/run.csv',
        type: TransferType.upload,
        status: TransferStatus.running,
        progress: 0.4,
        createdAt: DateTime.utc(2026, 1, 3),
      );

      await prefs.setString(
        'cached_transfer_tasks',
        jsonEncode([
          completed.toJson(),
          cancelled.toJson(),
          running.toJson(),
        ]),
      );

      final repo = FileTransferRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        notificationService: mockNotificationService,
        sharedPreferences: prefs,
      );
      addTearDown(repo.dispose);

      expect(repo.getAllTasks().length, 3);

      await repo.clearFinishedTasks();

      final remaining = repo.getAllTasks();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'run_1');
      // Running→paused on load (interrupted); clear must keep this active task.
      expect(remaining.first.status, TransferStatus.paused);

      // Survives reload from prefs (finished stay gone).
      final reloaded = FileTransferRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        notificationService: mockNotificationService,
        sharedPreferences: prefs,
      );
      addTearDown(reloaded.dispose);

      expect(reloaded.getAllTasks().length, 1);
      expect(reloaded.getAllTasks().first.id, 'run_1');
      expect(
        reloaded.getAllTasks().any((t) => t.isCompleted || t.isCancelled),
        isFalse,
      );
    });
  });

  group('FileTransferRepositoryImpl upload validation', () {
    test('rejects missing file before creating a task', () async {
      expect(
        () => repository.startUpload(
          filePath: '${Directory.systemTemp.path}/missing_upload_xyz.csv',
          fileName: 'missing.csv',
        ),
        throwsA(
          isA<TransferException>().having(
            (e) => e.message,
            'message',
            UploadFileValidator.missingFileMessage,
          ),
        ),
      );
      expect(repository.getAllTasks(), isEmpty);
    });

    test('rejects empty file before creating a task', () async {
      final empty = File('${Directory.systemTemp.path}/empty_upload.csv');
      await empty.writeAsBytes(const []);
      addTearDown(() async {
        if (await empty.exists()) await empty.delete();
      });

      expect(
        () => repository.startUpload(
          filePath: empty.path,
          fileName: 'empty.csv',
        ),
        throwsA(
          isA<TransferException>().having(
            (e) => e.message,
            'message',
            UploadFileValidator.emptyFileMessage,
          ),
        ),
      );
      expect(repository.getAllTasks(), isEmpty);
    });
  });

  group('FileTransferRepositoryImpl progress throttling', () {
    test('throttles rapid progress stream emits but always emits 100% completion',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final foreground = RecordingForegroundService();
      var clock = DateTime.utc(2026, 1, 1, 12, 0, 0);

      final throttledRepo = FileTransferRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        notificationService: mockNotificationService,
        sharedPreferences: prefs,
        foregroundService: foreground,
        now: () => clock,
      );

      when(() => mockNotificationService.showProgressNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            progress: any(named: 'progress'),
            maxProgress: any(named: 'maxProgress'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});
      when(() => mockNotificationService.showCompletionNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      when(() => mockRemoteDataSource.uploadFile(
            filePath: any(named: 'filePath'),
            fileName: any(named: 'fileName'),
            onSendProgress: any(named: 'onSendProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onSendProgress] as ProgressCallback;
        // 50 tiny progress ticks at the same clock → should coalesce.
        for (var i = 1; i <= 50; i++) {
          onProgress(i * 10, 100000); // 0.01% steps — below 1% until many ticks
        }
        // Jump by >= 1% still at same time → one more emit allowed by progress step.
        onProgress(2000, 100000); // 2%
        // Advance clock past stream throttle and bump progress again.
        clock = clock.add(const Duration(milliseconds: 300));
        onProgress(5000, 100000); // 5%
        return Response(
          requestOptions: RequestOptions(path: '/upload'),
          statusCode: 200,
        );
      });

      final localFile = await _tempUploadFile(name: 'throttle_upload.csv');
      addTearDown(() async {
        if (await localFile.exists()) await localFile.delete();
      });

      final events = <TransferTask>[];
      final sub = throttledRepo.transferStream.listen(events.add);

      await throttledRepo.startUpload(
        filePath: localFile.path,
        fileName: 'any.csv',
      );

      // Wait until completion is forced through the throttle.
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (!events.any((e) => e.isCompleted) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await sub.cancel();

      // Initial running + throttled progress + completion (force).
      // Must be far fewer than 50+ progress callbacks.
      expect(events.any((e) => e.isCompleted), isTrue);
      expect(events.length, lessThan(15));
      expect(events.first.status, TransferStatus.running);
      expect(events.last.status, TransferStatus.completed);
      expect(events.last.progress, 1.0);

      // FGS not called once per chunk either.
      expect(foreground.syncCalls, lessThan(20));

      throttledRepo.dispose();
    });

    test('status change (pause) always emits and syncs FGS + persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final clock = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final foreground = RecordingForegroundService();
      final throttledRepo = FileTransferRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        notificationService: mockNotificationService,
        sharedPreferences: prefs,
        foregroundService: foreground,
        now: () => clock,
      );

      when(() => mockNotificationService.cancel(any())).thenAnswer((_) async {});
      when(() => mockNotificationService.showProgressNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            progress: any(named: 'progress'),
            maxProgress: any(named: 'maxProgress'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      when(() => mockRemoteDataSource.uploadFile(
            filePath: any(named: 'filePath'),
            fileName: any(named: 'fileName'),
            onSendProgress: any(named: 'onSendProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onSendProgress] as ProgressCallback;
        final cancelToken =
            invocation.namedArguments[#cancelToken] as CancelToken;
        for (var i = 1; i <= 30; i++) {
          if (cancelToken.isCancelled) {
            throw DioException(
              requestOptions: RequestOptions(path: '/upload'),
              type: DioExceptionType.cancel,
            );
          }
          onProgress(i * 100, 100000);
        }
        while (!cancelToken.isCancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        throw DioException(
          requestOptions: RequestOptions(path: '/upload'),
          type: DioExceptionType.cancel,
        );
      });

      final localFile = await _tempUploadFile(name: 'throttle_pause.csv');
      addTearDown(() async {
        if (await localFile.exists()) await localFile.delete();
      });

      final events = <TransferTask>[];
      final sub = throttledRepo.transferStream.listen(events.add);

      final task = await throttledRepo.startUpload(
        filePath: localFile.path,
        fileName: 'any.csv',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final syncBeforePause = foreground.syncCalls;
      await throttledRepo.pauseTransfer(task.id);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events.any((e) => e.status == TransferStatus.paused), isTrue);
      // Pause (status change) must trigger another FGS sync.
      expect(foreground.syncCalls, greaterThan(syncBeforePause));

      // Cached tasks still contain paused entry after restart path via prefs.
      final cached = prefs.getString('cached_transfer_tasks');
      expect(cached, isNotNull);
      expect(cached!, contains('paused'));

      throttledRepo.dispose();
    });
  });
}
