import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/transfer_task.dart';
import '../../domain/repositories/file_transfer_repository.dart';
import '../../domain/usecases/transfer_usecases.dart';
import 'transfer_event.dart';
import 'transfer_state.dart';

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  final FileTransferRepository repository;
  final StartUploadUseCase startUploadUseCase;
  final StartDownloadUseCase startDownloadUseCase;
  final PauseTransferUseCase pauseTransferUseCase;
  final ResumeTransferUseCase resumeTransferUseCase;
  final CancelTransferUseCase cancelTransferUseCase;
  final RetryTransferUseCase retryTransferUseCase;

  StreamSubscription<TransferTask>? _transferSubscription;

  TransferBloc({
    required this.repository,
    required this.startUploadUseCase,
    required this.startDownloadUseCase,
    required this.pauseTransferUseCase,
    required this.resumeTransferUseCase,
    required this.cancelTransferUseCase,
    required this.retryTransferUseCase,
  }) : super(const TransferState()) {
    on<TransferInitializeRequested>(_onInitialize);
    on<TransferTaskUpdated>(_onTaskUpdated);
    on<TransferUploadRequested>(_onUploadRequested);
    on<TransferDownloadRequested>(_onDownloadRequested);
    on<TransferPauseRequested>(_onPauseRequested);
    on<TransferResumeRequested>(_onResumeRequested);
    on<TransferCancelRequested>(_onCancelRequested);
    on<TransferRetryRequested>(_onRetryRequested);
    on<TransferClearCompletedRequested>(_onClearCompletedRequested);

    // Subscribe to transfer stream
    _transferSubscription = repository.transferStream.listen((task) {
      add(TransferTaskUpdated(task));
    });
  }

  void _onInitialize(
    TransferInitializeRequested event,
    Emitter<TransferState> emit,
  ) {
    final existing = repository.getAllTasks();
    final taskMap = <String, TransferTask>{
      for (final t in existing) t.id: t,
    };
    emit(state.copyWith(tasks: taskMap));
  }

  void _onTaskUpdated(
    TransferTaskUpdated event,
    Emitter<TransferState> emit,
  ) {
    final updatedMap = Map<String, TransferTask>.from(state.tasks);
    updatedMap[event.task.id] = event.task;
    emit(state.copyWith(tasks: updatedMap, clearError: true));
  }

  Future<void> _onUploadRequested(
    TransferUploadRequested event,
    Emitter<TransferState> emit,
  ) async {
    try {
      final task = await startUploadUseCase(UploadParams(
        filePath: event.filePath,
        fileName: event.fileName,
      ));
      final updatedMap = Map<String, TransferTask>.from(state.tasks);
      updatedMap[task.id] = task;
      emit(state.copyWith(tasks: updatedMap));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to start upload: $e'));
    }
  }

  Future<void> _onDownloadRequested(
    TransferDownloadRequested event,
    Emitter<TransferState> emit,
  ) async {
    try {
      final task = await startDownloadUseCase(DownloadParams(
        fileName: event.fileName,
        customSavePath: event.customSavePath,
      ));
      final updatedMap = Map<String, TransferTask>.from(state.tasks);
      updatedMap[task.id] = task;
      emit(state.copyWith(tasks: updatedMap));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to start download: $e'));
    }
  }

  Future<void> _onPauseRequested(
    TransferPauseRequested event,
    Emitter<TransferState> emit,
  ) async {
    try {
      await pauseTransferUseCase(TaskActionParams(event.taskId));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to pause transfer: $e'));
    }
  }

  Future<void> _onResumeRequested(
    TransferResumeRequested event,
    Emitter<TransferState> emit,
  ) async {
    try {
      await resumeTransferUseCase(TaskActionParams(event.taskId));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to resume transfer: $e'));
    }
  }

  Future<void> _onCancelRequested(
    TransferCancelRequested event,
    Emitter<TransferState> emit,
  ) async {
    try {
      await cancelTransferUseCase(TaskActionParams(event.taskId));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to cancel transfer: $e'));
    }
  }

  Future<void> _onRetryRequested(
    TransferRetryRequested event,
    Emitter<TransferState> emit,
  ) async {
    try {
      await retryTransferUseCase(TaskActionParams(event.taskId));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to retry transfer: $e'));
    }
  }

  void _onClearCompletedRequested(
    TransferClearCompletedRequested event,
    Emitter<TransferState> emit,
  ) {
    final filtered = Map<String, TransferTask>.from(state.tasks)
      ..removeWhere((_, task) => task.isCompleted || task.isCancelled);
    emit(state.copyWith(tasks: filtered));
  }

  @override
  Future<void> close() {
    _transferSubscription?.cancel();
    return super.close();
  }
}
