import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/storage/storage_path_label.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/file_item.dart';
import '../../domain/entities/transfer_task.dart';
import '../bloc/file_list_bloc.dart';
import '../bloc/file_list_event.dart';
import '../bloc/file_list_state.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
import '../widgets/section_header.dart';
import '../widgets/status_panel.dart';
import '../widgets/transfer_item_tile.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FileListBloc>().add(const FileListFetchRequested());
  }

  void _downloadFile(String fileName) {
    context.read<TransferBloc>().add(
          TransferDownloadRequested(fileName: fileName),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading $fileName…'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await OpenFilex.open(path);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found on device storage'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, FileItem file) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text(
          'Remove "${file.name}" from the POS server? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<FileListBloc>().add(
                    FileListDeleteRequested(file.name),
                  );
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  TransferTask? _latestDownloadFor(
    List<TransferTask> downloads,
    String fileName,
  ) {
    for (final task in downloads) {
      if (task.fileName == fileName) return task;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Files & download'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh file list',
            onPressed: () {
              context.read<FileListBloc>().add(const FileListRefreshRequested());
            },
          ),
        ],
      ),
      body: BlocBuilder<TransferBloc, TransferState>(
        builder: (context, transferState) {
          final downloadTasks = transferState.allTasks
              .where((t) => t.type == TransferType.download)
              .toList();
          final activeDownloads = downloadTasks
              .where((t) => t.isRunning || t.isPaused || t.status == TransferStatus.queued)
              .toList();
          final recentDownloads = downloadTasks
              .where((t) => t.isCompleted || t.isFailed || t.isCancelled)
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              context.read<FileListBloc>().add(const FileListRefreshRequested());
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
              children: [
                if (activeDownloads.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Active downloads',
                    count: activeDownloads.length,
                  ),
                  ...activeDownloads.map(
                    (task) => TransferItemTile(
                      task: task,
                      onPause: () => context.read<TransferBloc>().add(
                            TransferPauseRequested(task.id),
                          ),
                      onResume: () => context.read<TransferBloc>().add(
                            TransferResumeRequested(task.id),
                          ),
                      onCancel: () => context.read<TransferBloc>().add(
                            TransferCancelRequested(task.id),
                          ),
                      onRetry: () => context.read<TransferBloc>().add(
                            TransferRetryRequested(task.id),
                          ),
                      onOpen: () => _openFile(task.localPath),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (recentDownloads.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Recent on this device',
                    count: recentDownloads.length,
                  ),
                  ...recentDownloads.map(
                    (task) => TransferItemTile(
                      task: task,
                      onResume: () => context.read<TransferBloc>().add(
                            TransferResumeRequested(task.id),
                          ),
                      onCancel: () => context.read<TransferBloc>().add(
                            TransferCancelRequested(task.id),
                          ),
                      onRetry: () => context.read<TransferBloc>().add(
                            TransferRetryRequested(task.id),
                          ),
                      onOpen: task.isCompleted
                          ? () => _openFile(task.localPath)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                const SectionHeader(
                  title: 'Uploaded files',
                  subtitle: 'Files available on the POS server',
                ),

                BlocBuilder<FileListBloc, FileListState>(
                  builder: (context, state) {
                    if (state is FileListLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (state is FileListError) {
                      return StatusPanel(
                        icon: Icons.cloud_off_rounded,
                        iconColor: colorScheme.error,
                        title: 'Couldn’t load files',
                        message: state.message,
                        actionLabel: 'Retry',
                        onAction: () {
                          context.read<FileListBloc>().add(
                                const FileListFetchRequested(),
                              );
                        },
                      );
                    }

                    if (state is FileListLoaded) {
                      if (state.files.isEmpty) {
                        return const StatusPanel(
                          icon: Icons.folder_off_outlined,
                          title: 'No uploaded files yet',
                          message:
                              'Upload a catalog or media file from the Upload tab, then pull to refresh.',
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (final file in state.files) ...[
                              _RemoteFileCard(
                                file: file,
                                localTask: _latestDownloadFor(
                                  downloadTasks,
                                  file.name,
                                ),
                                onDownload: () => _downloadFile(file.name),
                                onOpen: (path) => _openFile(path),
                                onDelete: () => _confirmDelete(context, file),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RemoteFileCard extends StatelessWidget {
  final FileItem file;
  final TransferTask? localTask;
  final VoidCallback onDownload;
  final ValueChanged<String> onOpen;
  final VoidCallback onDelete;

  const _RemoteFileCard({
    required this.file,
    required this.localTask,
    required this.onDownload,
    required this.onOpen,
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
                      'Saved to ${friendlyStoragePath(localTask!.localPath)}',
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
            if (saved)
              TextButton(
                onPressed: () => onOpen(localTask!.localPath),
                child: const Text('Open'),
              )
            else
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
