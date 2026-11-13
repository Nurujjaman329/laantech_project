import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import '../../domain/entities/transfer_task.dart';
import '../bloc/file_list_bloc.dart';
import '../bloc/file_list_event.dart';
import '../bloc/file_list_state.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
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
      SnackBar(content: Text('Starting download: $fileName')),
    );
  }

  void _openFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await OpenFilex.open(path);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found on storage')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Files & Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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

          return RefreshIndicator(
            onRefresh: () async {
              context.read<FileListBloc>().add(const FileListRefreshRequested());
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                // Active Download Tasks Section
                if (downloadTasks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Download Queue',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Badge.count(
                          count: downloadTasks.length,
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          textColor: theme.colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                  ...downloadTasks.map((task) => Column(
                        children: [
                          TransferItemTile(
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
                          ),
                          if (task.isCompleted)
                            Padding(
                              padding: const EdgeInsets.only(right: 20, bottom: 4),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.folder_open, size: 16),
                                  label: const Text('Open File'),
                                  onPressed: () => _openFile(task.localPath),
                                ),
                              ),
                            ),
                        ],
                      )),
                  const Divider(height: 24),
                ],

                // Server Files Section Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Available Files on POS Server',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Server File List
                BlocConsumer<FileListBloc, FileListState>(
                  listener: (context, state) {
                    if (state is FileListError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is FileListLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (state is FileListLoaded) {
                      if (state.files.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.folder_off_outlined,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No files found on server.\nUpload files from the Upload tab.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.files.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final file = state.files[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.description_outlined),
                            ),
                            title: Text(
                              file.name,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(file.formattedSize),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download_rounded),
                                  tooltip: 'Download file',
                                  color: theme.colorScheme.primary,
                                  onPressed: () => _downloadFile(file.name),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete file',
                                  color: theme.colorScheme.error,
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete File?'),
                                        content: Text(
                                            'Are you sure you want to delete "${file.name}" from the POS server?'),
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
                                            child: const Text('Delete',
                                                style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
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
