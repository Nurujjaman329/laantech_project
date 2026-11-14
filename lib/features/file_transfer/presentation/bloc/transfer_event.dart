import 'package:equatable/equatable.dart';
import '../../domain/entities/transfer_task.dart';

abstract class TransferEvent extends Equatable {
  const TransferEvent();

  @override
  List<Object?> get props => [];
}

class TransferInitializeRequested extends TransferEvent {
  const TransferInitializeRequested();
}

class TransferTaskUpdated extends TransferEvent {
  final TransferTask task;
  const TransferTaskUpdated(this.task);

  @override
  List<Object?> get props => [task];
}

class TransferUploadRequested extends TransferEvent {
  final String filePath;
  final String fileName;

  const TransferUploadRequested({
    required this.filePath,
    required this.fileName,
  });

  @override
  List<Object?> get props => [filePath, fileName];
}

class TransferDownloadRequested extends TransferEvent {
  final String fileName;
  final String? customSavePath;

  const TransferDownloadRequested({
    required this.fileName,
    this.customSavePath,
  });

  @override
  List<Object?> get props => [fileName, customSavePath];
}

class TransferPauseRequested extends TransferEvent {
  final String taskId;
  const TransferPauseRequested(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class TransferResumeRequested extends TransferEvent {
  final String taskId;
  const TransferResumeRequested(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class TransferCancelRequested extends TransferEvent {
  final String taskId;
  const TransferCancelRequested(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class TransferRetryRequested extends TransferEvent {
  final String taskId;
  const TransferRetryRequested(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class TransferClearCompletedRequested extends TransferEvent {
  const TransferClearCompletedRequested();
}

class TransferConnectivityChanged extends TransferEvent {
  final bool isOnline;
  const TransferConnectivityChanged(this.isOnline);

  @override
  List<Object?> get props => [isOnline];
}

class TransferResumeNetworkPausedRequested extends TransferEvent {
  const TransferResumeNetworkPausedRequested();
}

class TransferDismissNetworkPromptRequested extends TransferEvent {
  const TransferDismissNetworkPromptRequested();
}
