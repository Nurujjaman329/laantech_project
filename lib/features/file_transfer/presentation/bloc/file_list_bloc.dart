import 'package:flutter_bloc/flutter_bloc.dart';
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
    emit(const FileListLoading());
    try {
      final files = await getFilesUseCase(NoParams());
      emit(FileListLoaded(files));
    } catch (e) {
      emit(FileListError(e.toString().replaceFirst('Exception: ', '')));
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
      emit(FileListError(e.toString().replaceFirst('Exception: ', '')));
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
      emit(FileListError('Failed to delete ${event.fileName}: $e'));
    }
  }
}
