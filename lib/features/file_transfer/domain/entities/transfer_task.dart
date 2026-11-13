import 'package:equatable/equatable.dart';

enum TransferType { upload, download }

enum TransferStatus { queued, running, paused, completed, failed, cancelled }

class TransferTask extends Equatable {
  final String id;
  final String fileName;
  final String localPath;
  final String? remoteUrl;
  final TransferType type;
  final TransferStatus status;
  final int bytesTransferred;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const TransferTask({
    required this.id,
    required this.fileName,
    required this.localPath,
    this.remoteUrl,
    required this.type,
    this.status = TransferStatus.queued,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  bool get isRunning => status == TransferStatus.running;
  bool get isPaused => status == TransferStatus.paused;
  bool get isCompleted => status == TransferStatus.completed;
  bool get isFailed => status == TransferStatus.failed;
  bool get isCancelled => status == TransferStatus.cancelled;

  TransferTask copyWith({
    String? id,
    String? fileName,
    String? localPath,
    String? remoteUrl,
    TransferType? type,
    TransferStatus? status,
    int? bytesTransferred,
    int? totalBytes,
    double? progress,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return TransferTask(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      type: type ?? this.type,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fileName,
        localPath,
        remoteUrl,
        type,
        status,
        bytesTransferred,
        totalBytes,
        progress,
        errorMessage,
        createdAt,
        completedAt,
      ];
}
