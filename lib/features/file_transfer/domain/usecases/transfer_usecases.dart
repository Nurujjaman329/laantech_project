import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/file_item.dart';
import '../entities/transfer_task.dart';
import '../repositories/file_transfer_repository.dart';

class GetFilesUseCase implements UseCase<List<FileItem>, NoParams> {
  final FileTransferRepository repository;

  GetFilesUseCase(this.repository);

  @override
  Future<List<FileItem>> call(NoParams params) async {
    return await repository.getFiles();
  }
}

class DeleteFileParams extends Equatable {
  final String fileName;
  const DeleteFileParams(this.fileName);

  @override
  List<Object?> get props => [fileName];
}

class DeleteFileUseCase implements UseCase<void, DeleteFileParams> {
  final FileTransferRepository repository;

  DeleteFileUseCase(this.repository);

  @override
  Future<void> call(DeleteFileParams params) async {
    await repository.deleteFile(params.fileName);
  }
}

class UploadParams extends Equatable {
  final String filePath;
  final String fileName;

  const UploadParams({required this.filePath, required this.fileName});

  @override
  List<Object?> get props => [filePath, fileName];
}

class StartUploadUseCase implements UseCase<TransferTask, UploadParams> {
  final FileTransferRepository repository;

  StartUploadUseCase(this.repository);

  @override
  Future<TransferTask> call(UploadParams params) async {
    return await repository.startUpload(
      filePath: params.filePath,
      fileName: params.fileName,
    );
  }
}

class DownloadParams extends Equatable {
  final String fileName;
  final String? customSavePath;

  const DownloadParams({required this.fileName, this.customSavePath});

  @override
  List<Object?> get props => [fileName, customSavePath];
}

class StartDownloadUseCase implements UseCase<TransferTask, DownloadParams> {
  final FileTransferRepository repository;

  StartDownloadUseCase(this.repository);

  @override
  Future<TransferTask> call(DownloadParams params) async {
    return await repository.startDownload(
      fileName: params.fileName,
      customSavePath: params.customSavePath,
    );
  }
}

class TaskActionParams extends Equatable {
  final String taskId;
  const TaskActionParams(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class PauseTransferUseCase implements UseCase<void, TaskActionParams> {
  final FileTransferRepository repository;

  PauseTransferUseCase(this.repository);

  @override
  Future<void> call(TaskActionParams params) async {
    await repository.pauseTransfer(params.taskId);
  }
}

class ResumeTransferUseCase implements UseCase<void, TaskActionParams> {
  final FileTransferRepository repository;

  ResumeTransferUseCase(this.repository);

  @override
  Future<void> call(TaskActionParams params) async {
    await repository.resumeTransfer(params.taskId);
  }
}

class CancelTransferUseCase implements UseCase<void, TaskActionParams> {
  final FileTransferRepository repository;

  CancelTransferUseCase(this.repository);

  @override
  Future<void> call(TaskActionParams params) async {
    await repository.cancelTransfer(params.taskId);
  }
}

class RetryTransferUseCase implements UseCase<void, TaskActionParams> {
  final FileTransferRepository repository;

  RetryTransferUseCase(this.repository);

  @override
  Future<void> call(TaskActionParams params) async {
    await repository.retryTransfer(params.taskId);
  }
}
