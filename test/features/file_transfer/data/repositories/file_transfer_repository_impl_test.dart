import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/core/notifications/notification_service.dart';
import 'package:laantech_task/features/file_transfer/data/datasources/file_remote_data_source.dart';
import 'package:laantech_task/features/file_transfer/data/models/file_item_model.dart';
import 'package:laantech_task/features/file_transfer/data/repositories/file_transfer_repository_impl.dart';
import 'package:laantech_task/features/file_transfer/domain/entities/transfer_task.dart';

class MockFileRemoteDataSource extends Mock implements FileRemoteDataSource {}
class MockNotificationService extends Mock implements NotificationService {}
class FakeCancelToken extends Fake implements CancelToken {}

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
        filePath: 'non_existent_path.csv',
        fileName: 'test.csv',
      );

      await repository.pauseTransfer(task.id);

      final updatedTask = repository.getAllTasks().firstWhere((t) => t.id == task.id);
      expect(updatedTask.status, TransferStatus.paused);
      verify(() => mockNotificationService.cancel(any())).called(1);
    });

    test('cancelTransfer transitions task to cancelled state', () async {
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
        filePath: 'non_existent_path.csv',
        fileName: 'test.csv',
      );

      await repository.cancelTransfer(task.id);

      final updatedTask = repository.getAllTasks().firstWhere((t) => t.id == task.id);
      expect(updatedTask.status, TransferStatus.cancelled);
    });
  });
}
