import 'package:flutter/material.dart';
import '../../domain/entities/transfer_task.dart';

class TransferItemTile extends StatelessWidget {
  final TransferTask task;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const TransferItemTile({
    super.key,
    required this.task,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
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
        return Colors.orange;
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return theme.colorScheme.error;
      case TransferStatus.cancelled:
        return Colors.grey;
      case TransferStatus.queued:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUpload = task.type == TransferType.upload;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _getStatusColor(theme).withValues(alpha: 0.15),
                  child: Icon(
                    isUpload ? Icons.upload_rounded : Icons.download_rounded,
                    size: 20,
                    color: _getStatusColor(theme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatBytes(task.bytesTransferred)} of ${_formatBytes(task.totalBytes)} • ${(task.progress * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                if (task.isRunning)
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline, color: Colors.orange),
                    tooltip: 'Pause',
                    onPressed: onPause,
                  )
                else if (task.isPaused)
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline, color: Colors.green),
                    tooltip: 'Resume',
                    onPressed: onResume,
                  )
                else if (task.isFailed)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.blue),
                    tooltip: 'Retry',
                    onPressed: onRetry,
                  ),
                if (!task.isCompleted)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Cancel',
                    onPressed: onCancel,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.isCompleted ? 1.0 : (task.progress > 0 ? task.progress : null),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(theme)),
                minHeight: 6,
              ),
            ),
            if (task.errorMessage != null && task.isFailed) ...[
              const SizedBox(height: 6),
              Text(
                task.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
