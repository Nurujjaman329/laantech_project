import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/core/usecase/usecase.dart';
import 'package:laantech_task/features/file_transfer/domain/entities/file_item.dart';
import 'package:laantech_task/features/file_transfer/domain/usecases/transfer_usecases.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/file_list_bloc.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/file_list_event.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/file_list_state.dart';

class MockGetFilesUseCase extends Mock implements GetFilesUseCase {}
class MockDeleteFileUseCase extends Mock implements DeleteFileUseCase {}

void main() {
  late MockGetFilesUseCase mockGetFilesUseCase;
  late MockDeleteFileUseCase mockDeleteFileUseCase;
  late FileListBloc fileListBloc;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(const DeleteFileParams(''));
  });

  setUp(() {
    mockGetFilesUseCase = MockGetFilesUseCase();
    mockDeleteFileUseCase = MockDeleteFileUseCase();
    fileListBloc = FileListBloc(
      getFilesUseCase: mockGetFilesUseCase,
      deleteFileUseCase: mockDeleteFileUseCase,
    );
  });

  tearDown(() {
    fileListBloc.close();
  });

  const sampleFiles = [
    FileItem(name: 'inventory_2026.csv', size: 2048),
    FileItem(name: 'pos_receipt.png', size: 1024),
  ];

  test('initial state is FileListInitial', () {
    expect(fileListBloc.state, const FileListInitial());
  });

  group('FileListFetchRequested', () {
    blocTest<FileListBloc, FileListState>(
      'emits [FileListLoading, FileListLoaded] when fetching succeeds',
      build: () {
        when(() => mockGetFilesUseCase(any())).thenAnswer((_) async => sampleFiles);
        return fileListBloc;
      },
      act: (bloc) => bloc.add(const FileListFetchRequested()),
      expect: () => [
        const FileListLoading(),
        const FileListLoaded(sampleFiles),
      ],
      verify: (_) {
        verify(() => mockGetFilesUseCase(NoParams())).called(1);
      },
    );

    blocTest<FileListBloc, FileListState>(
      'emits [FileListLoading, FileListError] when fetching fails',
      build: () {
        when(() => mockGetFilesUseCase(any())).thenThrow(Exception('Server unreachable'));
        return fileListBloc;
      },
      act: (bloc) => bloc.add(const FileListFetchRequested()),
      expect: () => [
        const FileListLoading(),
        const FileListError('Server unreachable'),
      ],
    );
  });

  group('FileListDeleteRequested', () {
    blocTest<FileListBloc, FileListState>(
      'calls deleteFileUseCase and refreshes list',
      build: () {
        when(() => mockDeleteFileUseCase(any())).thenAnswer((_) async {});
        when(() => mockGetFilesUseCase(any())).thenAnswer((_) async => [sampleFiles[1]]);
        return fileListBloc;
      },
      act: (bloc) => bloc.add(const FileListDeleteRequested('inventory_2026.csv')),
      expect: () => [
        FileListLoaded([sampleFiles[1]]),
      ],
      verify: (_) {
        verify(() => mockDeleteFileUseCase(const DeleteFileParams('inventory_2026.csv'))).called(1);
        verify(() => mockGetFilesUseCase(NoParams())).called(1);
      },
    );
  });
}
