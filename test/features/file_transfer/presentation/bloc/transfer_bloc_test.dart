import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/features/file_transfer/domain/entities/transfer_task.dart';
import 'package:laantech_task/features/file_transfer/domain/repositories/file_transfer_repository.dart';
import 'package:laantech_task/features/file_transfer/domain/usecases/transfer_usecases.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/transfer_bloc.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/transfer_event.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/transfer_state.dart';

class MockFileTransferRepository extends Mock implements FileTransferRepository {}
class MockStartUploadUseCase extends Mock implements StartUploadUseCase {}
class MockStartDownloadUseCase extends Mock implements StartDownloadUseCase {}
class MockPauseTransferUseCase extends Mock implements PauseTransferUseCase {}
class MockResumeTransferUseCase extends Mock implements ResumeTransferUseCase {}
class MockCancelTransferUseCase extends Mock implements CancelTransferUseCase {}
class MockRetryTransferUseCase extends Mock implements RetryTransferUseCase {}

void main() {
  late MockFileTransferRepository mockRepository;
  late MockStartUploadUseCase mockStartUploadUseCase;
  late MockStartDownloadUseCase mockStartDownloadUseCase;
  late MockPauseTransferUseCase mockPauseTransferUseCase;
  late MockResumeTransferUseCase mockResumeTransferUseCase;
  late MockCancelTransferUseCase mockCancelTransferUseCase;
  late MockRetryTransferUseCase mockRetryTransferUseCase;
  late StreamController<TransferTask> streamController;
  late TransferBloc transferBloc;

  setUpAll(() {
    registerFallbackValue(const UploadParams(filePath: '', fileName: ''));
    registerFallbackValue(const DownloadParams(fileName: ''));
    registerFallbackValue(const TaskActionParams(''));
  });

  setUp(() {
    mockRepository = MockFileTransferRepository();
    mockStartUploadUseCase = MockStartUploadUseCase();
    mockStartDownloadUseCase = MockStartDownloadUseCase();
    mockPauseTransferUseCase = MockPauseTransferUseCase();
    mockResumeTransferUseCase = MockResumeTransferUseCase();
    mockCancelTransferUseCase = MockCancelTransferUseCase();
    mockRetryTransferUseCase = MockRetryTransferUseCase();
    streamController = StreamController<TransferTask>.broadcast();

    when(() => mockRepository.transferStream).thenAnswer((_) => streamController.stream);
    when(() => mockRepository.getAllTasks()).thenReturn([]);

    transferBloc = TransferBloc(
      repository: mockRepository,
      startUploadUseCase: mockStartUploadUseCase,
      startDownloadUseCase: mockStartDownloadUseCase,
      pauseTransferUseCase: mockPauseTransferUseCase,
      resumeTransferUseCase: mockResumeTransferUseCase,
      cancelTransferUseCase: mockCancelTransferUseCase,
      retryTransferUseCase: mockRetryTransferUseCase,
    );
  });

  tearDown(() {
    transferBloc.close();
    streamController.close();
  });

  final sampleTask = TransferTask(
    id: 'task_1',
    fileName: 'catalog.csv',
    localPath: '/tmp/catalog.csv',
    type: TransferType.upload,
    status: TransferStatus.running,
    progress: 0.5,
    bytesTransferred: 50,
    totalBytes: 100,
    createdAt: DateTime.now(),
  );

  test('initial state has empty task map', () {
    expect(transferBloc.state.tasks, isEmpty);
  });

  group('TransferBloc task updates via stream', () {
    blocTest<TransferBloc, TransferState>(
      'emits updated task map when repository emits a task on transferStream',
      build: () => transferBloc,
      act: (bloc) => streamController.add(sampleTask),
      expect: () => [
        TransferState(tasks: {'task_1': sampleTask}),
      ],
    );
  });

  group('TransferBloc user actions', () {
    blocTest<TransferBloc, TransferState>(
      'TransferUploadRequested calls startUploadUseCase and adds task to state',
      build: () {
        when(() => mockStartUploadUseCase(any())).thenAnswer((_) async => sampleTask);
        return transferBloc;
      },
      act: (bloc) => bloc.add(const TransferUploadRequested(
        filePath: '/tmp/catalog.csv',
        fileName: 'catalog.csv',
      )),
      expect: () => [
        TransferState(tasks: {'task_1': sampleTask}),
      ],
      verify: (_) {
        verify(() => mockStartUploadUseCase(const UploadParams(
              filePath: '/tmp/catalog.csv',
              fileName: 'catalog.csv',
            ))).called(1);
      },
    );

    blocTest<TransferBloc, TransferState>(
      'TransferPauseRequested calls pauseTransferUseCase',
      build: () {
        when(() => mockPauseTransferUseCase(any())).thenAnswer((_) async {});
        return transferBloc;
      },
      act: (bloc) => bloc.add(const TransferPauseRequested('task_1')),
      verify: (_) {
        verify(() => mockPauseTransferUseCase(const TaskActionParams('task_1'))).called(1);
      },
    );

    blocTest<TransferBloc, TransferState>(
      'TransferResumeRequested calls resumeTransferUseCase',
      build: () {
        when(() => mockResumeTransferUseCase(any())).thenAnswer((_) async {});
        return transferBloc;
      },
      act: (bloc) => bloc.add(const TransferResumeRequested('task_1')),
      verify: (_) {
        verify(() => mockResumeTransferUseCase(const TaskActionParams('task_1'))).called(1);
      },
    );

    blocTest<TransferBloc, TransferState>(
      'TransferCancelRequested calls cancelTransferUseCase',
      build: () {
        when(() => mockCancelTransferUseCase(any())).thenAnswer((_) async {});
        return transferBloc;
      },
      act: (bloc) => bloc.add(const TransferCancelRequested('task_1')),
      verify: (_) {
        verify(() => mockCancelTransferUseCase(const TaskActionParams('task_1'))).called(1);
      },
    );
  });
}
