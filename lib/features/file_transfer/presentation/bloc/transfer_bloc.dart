import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/connectivity_service.dart';
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
  final ConnectivityService? connectivityService;

  StreamSubscription<TransferTask>? _transferSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  static const String networkPauseReason = 'Paused — network offline';

  TransferBloc({
    required this.repository,
    required this.startUploadUseCase,
    required this.startDownloadUseCase,
    required this.pauseTransferUseCase,
    required this.resumeTransferUseCase,
    required this.cancelTransferUseCase,
    required this.retryTransferUseCase,
    this.connectivityService,
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
    on<TransferConnectivityChanged>(_onConnectivityChanged);
    on<TransferResumeNetworkPausedRequested>(_onResumeNetworkPaused);
    on<TransferDismissNetworkPromptRequested>(_onDismissNetworkPrompt);

    _transferSubscription = repository.transferStream.listen((task) {
      add(TransferTaskUpdated(task));
    });

    final connectivity = connectivityService;
    if (connectivity != null) {
      _connectivitySubscription =
          connectivity.onConnectivityChanged.listen((isOnline) {
        add(TransferConnectivityChanged(isOnline));
      });
      connectivity.isOnline.then((online) {
        if (!isClosed) {
          add(TransferConnectivityChanged(online));
        }
      });
    }
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
      final remaining = state.networkPausedTaskIds
          .where((id) => id != event.taskId)
          .toList();
      if (remaining.length != state.networkPausedTaskIds.length) {
        emit(state.copyWith(networkPausedTaskIds: remaining));
      }
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
      final remaining = state.networkPausedTaskIds
          .where((id) => id != event.taskId)
          .toList();
      emit(state.copyWith(networkPausedTaskIds: remaining));
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
      final remaining = state.networkPausedTaskIds
          .where((id) => id != event.taskId)
          .toList();
      emit(state.copyWith(networkPausedTaskIds: remaining));
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

  Future<void> _onConnectivityChanged(
    TransferConnectivityChanged event,
    Emitter<TransferState> emit,
  ) async {
    if (!event.isOnline) {
      final runningIds = state.tasks.values
          .where((t) => t.isRunning)
          .map((t) => t.id)
          .toList();

      final pausedByNetwork = <String>{...state.networkPausedTaskIds};
      for (final id in runningIds) {
        await pauseTransferUseCase(
          TaskActionParams(id, reason: networkPauseReason),
        );
        pausedByNetwork.add(id);
      }

      emit(state.copyWith(
        isOffline: true,
        networkPausedTaskIds: pausedByNetwork.toList(),
        showNetworkRestoredPrompt: false,
      ));
      return;
    }

    // Back online
    final hadNetworkPauses = state.networkPausedTaskIds.isNotEmpty;
    emit(state.copyWith(
      isOffline: false,
      showNetworkRestoredPrompt: hadNetworkPauses,
    ));
  }

  Future<void> _onResumeNetworkPaused(
    TransferResumeNetworkPausedRequested event,
    Emitter<TransferState> emit,
  ) async {
    final ids = List<String>.from(state.networkPausedTaskIds);
    for (final id in ids) {
      try {
        await resumeTransferUseCase(TaskActionParams(id));
      } catch (_) {
        // Continue remaining tasks; individual failures surface via stream.
      }
    }
    emit(state.copyWith(
      networkPausedTaskIds: const [],
      showNetworkRestoredPrompt: false,
    ));
  }

  void _onDismissNetworkPrompt(
    TransferDismissNetworkPromptRequested event,
    Emitter<TransferState> emit,
  ) {
    if (state.showNetworkRestoredPrompt) {
      emit(state.copyWith(showNetworkRestoredPrompt: false));
    }
  }

  @override
  Future<void> close() {
    _transferSubscription?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
