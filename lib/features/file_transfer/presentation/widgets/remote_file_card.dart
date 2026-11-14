import 'package:flutter/material.dart';

import '../../../../core/storage/storage_path_label.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/file_item.dart';
import '../../domain/entities/transfer_task.dart';

class RemoteFileCard extends StatelessWidget {
  final FileItem file;
  final TransferTask? localTask;
  final VoidCallback onDownload;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onShare;
  final VoidCallback onDelete;

  const RemoteFileCard({
    super.key,
    required this.file,
    required this.localTask,
    required this.onDownload,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final saved = localTask?.isCompleted == true;
    final downloading = localTask?.isRunning == true || localTask?.isPaused == true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.description_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file.formattedSize,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (saved) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Saved to ${friendlyStoragePath(
                        localTask!.localPath,
                        publicPathLabel: localTask!.publicPathLabel,
                      )}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else if (downloading) ...[
                    const SizedBox(height: 4),
                    Text(
                      localTask!.isPaused ? 'Paused' : 'Downloading…',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: localTask!.isPaused
                            ? AppColors.paused
                            : colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (saved) ...[
              IconButton(
                tooltip: 'Share',
                onPressed: () => onShare(localTask!.localPath),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              TextButton(
                onPressed: () => onOpen(localTask!.localPath),
                child: const Text('Open'),
              ),
            ] else
              FilledButton.tonal(
                onPressed: downloading ? null : onDownload,
                child: Text(downloading ? 'Busy' : 'Download'),
              ),
            IconButton(
              tooltip: 'Delete from server',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}
