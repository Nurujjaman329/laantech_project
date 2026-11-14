import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/storage/share_downloaded_file.dart';
import '../../domain/entities/transfer_task.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
import 'status_panel.dart';
import 'transfer_item_tile.dart';

class PersistentTransferSheet extends StatelessWidget {
  const PersistentTransferSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<TransferBloc>(),
        child: const PersistentTransferSheet(),
      ),
    );
  }

  Future<void> _openDownloadedFile(BuildContext context, String path) async {
    final file = File(path);
    if (await file.exists()) {
      await OpenFilex.open(path);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found on device storage'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareDownloadedFile(
    BuildContext context,
    TransferTask task,
  ) async {
    final ok = await shareDownloadedFile(
      task.localPath,
      fileName: task.fileName,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found on device storage'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.sync_alt_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transfers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    context.read<TransferBloc>().add(
                          const TransferClearCompletedRequested(),
                        );
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<TransferBloc, TransferState>(
              builder: (context, state) {
                final tasks = state.allTasks;
                if (tasks.isEmpty) {
                  return const StatusPanel(
                    icon: Icons.cloud_done_outlined,
                    title: 'No transfers yet',
                    message:
                        'Uploads and downloads will show up here with live status.',
                    padding: EdgeInsets.fromLTRB(24, 48, 24, 24),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return TransferItemTile(
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
                      onOpen: task.isCompleted &&
                              task.type == TransferType.download
                          ? () => _openDownloadedFile(context, task.localPath)
                          : null,
                      onShare: task.isCompleted &&
                              task.type == TransferType.download
                          ? () => _shareDownloadedFile(context, task)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
