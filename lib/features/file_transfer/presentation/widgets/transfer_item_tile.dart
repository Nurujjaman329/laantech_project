import 'package:flutter/material.dart';

import '../../../../core/errors/error_message_mapper.dart';
import '../../../../core/storage/storage_path_label.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/transfer_task.dart';
import 'transfer_status_badge.dart';

class TransferItemTile extends StatelessWidget {
  final TransferTask task;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onOpen;

  const TransferItemTile({
    super.key,
    required this.task,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onOpen,
  });

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double b = bytes.toDouble();
    while (b >= 1024 && i < suffixes.length - 1) {
      b /= 1024;
      i++;
    }
    return '${b.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Color _getStatusColor(ThemeData theme) {
    switch (task.status) {
      case TransferStatus.running:
        return theme.colorScheme.primary;
      case TransferStatus.paused:
        return AppColors.paused;
      case TransferStatus.completed:
        return AppColors.success;
      case TransferStatus.failed:
        return theme.colorScheme.error;
      case TransferStatus.cancelled:
        return AppColors.cancelled;
      case TransferStatus.queued:
        return AppColors.queued;
    }
  }

  String get _failedMessage {
    final raw = task.errorMessage;
    if (raw == null || raw.trim().isEmpty) {
      return 'Connection lost. Retry when you\'re online.';
    }
    return ErrorMessageMapper.from(
      raw,
      fallback: 'Transfer failed. Please try again.',
    );
  }

  String get _pausedMessage {
    final raw = task.errorMessage;
    if (raw == null || raw.trim().isEmpty) {
      return 'Transfer paused. Tap Resume to continue.';
    }
    return ErrorMessageMapper.from(
      raw,
      fallback: 'Transfer paused. Tap Resume to continue.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUpload = task.type == TransferType.upload;
    final statusColor = _getStatusColor(theme);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: task.isFailed
              ? colorScheme.error.withValues(alpha: 0.35)
              : colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(
                    task.isFailed
                        ? Icons.error_outline_rounded
                        : (isUpload
                            ? Icons.upload_rounded
                            : Icons.download_rounded),
                    size: 20,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TransferStatusBadge(task: task),
                        ],
                      ),
                      if (!task.isFailed) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_formatBytes(task.bytesTransferred)} of ${_formatBytes(task.totalBytes)} • ${(task.progress * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (task.isRunning)
                  IconButton(
                    icon: const Icon(
                      Icons.pause_circle_outline,
                      color: AppColors.paused,
                    ),
                    tooltip: 'Pause',
                    onPressed: onPause,
                  )
                else if (task.isPaused)
                  IconButton(
                    icon: const Icon(
                      Icons.play_circle_outline,
                      color: AppColors.success,
                    ),
                    tooltip: 'Resume',
                    onPressed: onResume,
                  ),
                if (!task.isCompleted &&
                    !task.isCancelled &&
                    !task.isFailed)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Cancel',
                    onPressed: onCancel,
                  ),
              ],
            ),
            if (task.isRunning || task.isPaused || task.isCompleted) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.isCompleted
                      ? 1.0
                      : (task.progress > 0 ? task.progress : null),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
            ],
            if (task.isPaused) ...[
              const SizedBox(height: 8),
              Text(
                _pausedMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (onResume != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Resume'),
                  ),
                ),
              ],
            ],
            if (task.isFailed) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _failedMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Dismiss'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ],
            if (task.isCompleted && task.type == TransferType.download) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.folder_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Saved to ${friendlyStoragePath(task.localPath)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onOpen != null)
                    TextButton(
                      onPressed: onOpen,
                      child: const Text('Open'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
