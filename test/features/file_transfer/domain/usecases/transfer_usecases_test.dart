import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/core/usecase/usecase.dart';
import 'package:laantech_task/features/file_transfer/domain/entities/file_item.dart';
import 'package:laantech_task/features/file_transfer/domain/entities/transfer_task.dart';
import 'package:laantech_task/features/file_transfer/domain/repositories/file_transfer_repository.dart';
import 'package:laantech_task/features/file_transfer/domain/usecases/transfer_usecases.dart';

class MockFileTransferRepository extends Mock implements FileTransferRepository {}

void main() {
  late MockFileTransferRepository mockRepository;
  late GetFilesUseCase getFilesUseCase;
  late DeleteFileUseCase deleteFileUseCase;
  late StartUploadUseCase startUploadUseCase;
  late StartDownloadUseCase startDownloadUseCase;
  late PauseTransferUseCase pauseTransferUseCase;
  late ResumeTransferUseCase resumeTransferUseCase;
  late CancelTransferUseCase cancelTransferUseCase;

  setUp(() {
    mockRepository = MockFileTransferRepository();
    getFilesUseCase = GetFilesUseCase(mockRepository);
    deleteFileUseCase = DeleteFileUseCase(mockRepository);
    startUploadUseCase = StartUploadUseCase(mockRepository);
    startDownloadUseCase = StartDownloadUseCase(mockRepository);
    pauseTransferUseCase = PauseTransferUseCase(mockRepository);
    resumeTransferUseCase = ResumeTransferUseCase(mockRepository);
    cancelTransferUseCase = CancelTransferUseCase(mockRepository);
  });

  final testTask = TransferTask(
    id: 't1',
    fileName: 'catalog.csv',
    localPath: '/tmp/catalog.csv',
    type: TransferType.upload,
    createdAt: DateTime.now(),
  );

  test('GetFilesUseCase delegates to repository.getFiles', () async {
    const files = [FileItem(name: 'test.csv')];
    when(() => mockRepository.getFiles()).thenAnswer((_) async => files);

    final result = await getFilesUseCase(NoParams());

    expect(result, files);
    verify(() => mockRepository.getFiles()).called(1);
  });

  test('DeleteFileUseCase delegates to repository.deleteFile', () async {
    when(() => mockRepository.deleteFile('old.csv')).thenAnswer((_) async {});

    await deleteFileUseCase(const DeleteFileParams('old.csv'));

    verify(() => mockRepository.deleteFile('old.csv')).called(1);
  });

  test('StartUploadUseCase delegates to repository.startUpload', () async {
    when(() => mockRepository.startUpload(
          filePath: '/path/file.csv',
          fileName: 'file.csv',
        )).thenAnswer((_) async => testTask);

    final result = await startUploadUseCase(const UploadParams(
      filePath: '/path/file.csv',
      fileName: 'file.csv',
    ));

    expect(result, testTask);
    verify(() => mockRepository.startUpload(
          filePath: '/path/file.csv',
          fileName: 'file.csv',
        )).called(1);
  });

  test('StartDownloadUseCase delegates to repository.startDownload', () async {
    when(() => mockRepository.startDownload(
          fileName: 'file.csv',
          customSavePath: null,
        )).thenAnswer((_) async => testTask);

    final result = await startDownloadUseCase(const DownloadParams(fileName: 'file.csv'));

    expect(result, testTask);
    verify(() => mockRepository.startDownload(
          fileName: 'file.csv',
          customSavePath: null,
        )).called(1);
  });

  test('PauseTransferUseCase delegates to repository.pauseTransfer', () async {
    when(() => mockRepository.pauseTransfer(any(), reason: any(named: 'reason')))
        .thenAnswer((_) async {});
    await pauseTransferUseCase(const TaskActionParams('t1'));
    verify(() => mockRepository.pauseTransfer('t1', reason: null)).called(1);
  });

  test('ResumeTransferUseCase delegates to repository.resumeTransfer', () async {
    when(() => mockRepository.resumeTransfer('t1')).thenAnswer((_) async {});
    await resumeTransferUseCase(const TaskActionParams('t1'));
    verify(() => mockRepository.resumeTransfer('t1')).called(1);
  });

  test('CancelTransferUseCase delegates to repository.cancelTransfer', () async {
    when(() => mockRepository.cancelTransfer('t1')).thenAnswer((_) async {});
    await cancelTransferUseCase(const TaskActionParams('t1'));
    verify(() => mockRepository.cancelTransfer('t1')).called(1);
  });
}
