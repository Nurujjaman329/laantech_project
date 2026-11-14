import '../entities/file_item.dart';
import '../entities/transfer_task.dart';

abstract class FileTransferRepository {
  /// Stream of transfer updates for UI and notification listeners
  Stream<TransferTask> get transferStream;

  /// Fetch list of files currently on server
  Future<List<FileItem>> getFiles();

  /// Delete a file from the server
  Future<void> deleteFile(String fileName);

  /// Start uploading a local file
  Future<TransferTask> startUpload({
    required String filePath,
    required String fileName,
  });

  /// Start downloading a remote file
  Future<TransferTask> startDownload({
    required String fileName,
    String? customSavePath,
  });

  /// Pause an ongoing transfer. Optional [reason] is stored on the task.
  Future<void> pauseTransfer(String taskId, {String? reason});

  /// Resume a paused transfer
  Future<void> resumeTransfer(String taskId);

  /// Cancel and abort an ongoing/paused transfer
  Future<void> cancelTransfer(String taskId);

  /// Retry a failed or cancelled transfer
  Future<void> retryTransfer(String taskId);

  /// Get current snapshot of all active/recent tasks
  List<TransferTask> getAllTasks();
}
