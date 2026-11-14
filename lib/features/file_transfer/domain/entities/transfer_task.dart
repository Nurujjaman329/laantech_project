import 'package:equatable/equatable.dart';

enum TransferType { upload, download }

enum TransferStatus { queued, running, paused, completed, failed, cancelled }

class TransferTask extends Equatable {
  final String id;
  final String fileName;
  final String localPath;
  /// User-facing public Downloads label after MediaStore publish, e.g.
  /// `Downloads/POS_Transfers/catalog.csv`.
  final String? publicPathLabel;
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
    this.publicPathLabel,
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
    String? publicPathLabel,
    String? remoteUrl,
    TransferType? type,
    TransferStatus? status,
    int? bytesTransferred,
    int? totalBytes,
    double? progress,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return TransferTask(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      publicPathLabel: publicPathLabel ?? this.publicPathLabel,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      type: type ?? this.type,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      progress: progress ?? this.progress,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'localPath': localPath,
      'publicPathLabel': publicPathLabel,
      'remoteUrl': remoteUrl,
      'type': type.name,
      'status': status.name,
      'bytesTransferred': bytesTransferred,
      'totalBytes': totalBytes,
      'progress': progress,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory TransferTask.fromJson(Map<String, dynamic> json) {
    return TransferTask(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      localPath: json['localPath'] as String,
      publicPathLabel: json['publicPathLabel'] as String?,
      remoteUrl: json['remoteUrl'] as String?,
      type: TransferType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransferType.upload,
      ),
      status: TransferStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransferStatus.queued,
      ),
      bytesTransferred: json['bytesTransferred'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fileName,
        localPath,
        publicPathLabel,
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
