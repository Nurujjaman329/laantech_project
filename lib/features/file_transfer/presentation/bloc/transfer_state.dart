import 'package:equatable/equatable.dart';
import '../../domain/entities/transfer_task.dart';

class TransferState extends Equatable {
  final Map<String, TransferTask> tasks;
  final String? errorMessage;

  const TransferState({
    this.tasks = const {},
    this.errorMessage,
  });

  List<TransferTask> get allTasks => tasks.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<TransferTask> get activeTasks =>
      allTasks.where((t) => t.isRunning || t.isPaused || t.status == TransferStatus.queued).toList();

  List<TransferTask> get completedTasks =>
      allTasks.where((t) => t.isCompleted).toList();

  List<TransferTask> get failedTasks =>
      allTasks.where((t) => t.isFailed).toList();

  bool get hasActiveTransfers => activeTasks.isNotEmpty;

  double get overallProgress {
    if (activeTasks.isEmpty) return 0.0;
    final totalProgress = activeTasks.fold<double>(0.0, (acc, t) => acc + t.progress);
    return totalProgress / activeTasks.length;
  }

  TransferState copyWith({
    Map<String, TransferTask>? tasks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TransferState(
      tasks: tasks ?? this.tasks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [tasks, errorMessage];
}
