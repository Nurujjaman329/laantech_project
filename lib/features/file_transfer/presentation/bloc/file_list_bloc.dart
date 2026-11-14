import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/error_message_mapper.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/transfer_usecases.dart';
import 'file_list_event.dart';
import 'file_list_state.dart';

class FileListBloc extends Bloc<FileListEvent, FileListState> {
  final GetFilesUseCase getFilesUseCase;
  final DeleteFileUseCase deleteFileUseCase;

  FileListBloc({
    required this.getFilesUseCase,
    required this.deleteFileUseCase,
  }) : super(const FileListInitial()) {
    on<FileListFetchRequested>(_onFetchRequested);
    on<FileListRefreshRequested>(_onRefreshRequested);
    on<FileListDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onFetchRequested(
    FileListFetchRequested event,
    Emitter<FileListState> emit,
  ) async {
    // Keep existing items visible on silent refresh (upload-complete / tab switch).
    final silent = state is FileListLoaded;
    if (!silent) {
      emit(const FileListLoading());
    }
    try {
      final files = await getFilesUseCase(NoParams());
      emit(FileListLoaded(files));
    } catch (e) {
      emit(FileListError(
        ErrorMessageMapper.from(e, fallback: 'Could not load server files.'),
      ));
    }
  }

  Future<void> _onRefreshRequested(
    FileListRefreshRequested event,
    Emitter<FileListState> emit,
  ) async {
    try {
      final files = await getFilesUseCase(NoParams());
      emit(FileListLoaded(files));
    } catch (e) {
      emit(FileListError(
        ErrorMessageMapper.from(e, fallback: 'Could not refresh server files.'),
      ));
    }
  }

  Future<void> _onDeleteRequested(
    FileListDeleteRequested event,
    Emitter<FileListState> emit,
  ) async {
    try {
      await deleteFileUseCase(DeleteFileParams(event.fileName));
      // Refresh list after deletion
      final files = await getFilesUseCase(NoParams());
      emit(FileListLoaded(files));
    } catch (e) {
      emit(FileListError(
        ErrorMessageMapper.from(
          e,
          fallback: 'Failed to delete ${event.fileName}.',
        ),
      ));
    }
  }
}
