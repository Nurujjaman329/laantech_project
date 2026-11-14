import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/pos_terminal_banner.dart';
import '../../domain/entities/transfer_task.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
import '../widgets/status_panel.dart';
import '../widgets/transfer_item_tile.dart';

enum TransferFilter { all, active, completed, failed }

class TransferManagerScreen extends StatefulWidget {
  const TransferManagerScreen({super.key});

  @override
  State<TransferManagerScreen> createState() => _TransferManagerScreenState();
}

class _TransferManagerScreenState extends State<TransferManagerScreen> {
  TransferFilter _selectedFilter = TransferFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransferTask> _filterTasks(TransferState state) {
    List<TransferTask> list;
    switch (_selectedFilter) {
      case TransferFilter.all:
        list = state.allTasks;
        break;
      case TransferFilter.active:
        list = state.activeTasks;
        break;
      case TransferFilter.completed:
        list = state.completedTasks;
        break;
      case TransferFilter.failed:
        list = state.failedTasks;
        break;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((t) => t.fileName.toLowerCase().contains(query)).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<TransferBloc, TransferState>(
      builder: (context, state) {
        final filteredTasks = _filterTasks(state);
        final activeCount = state.activeTasks.length;
        final completedCount = state.completedTasks.length;
        final failedCount = state.failedTasks.length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Transfers'),
            actions: [
              if (failedCount > 0)
                TextButton.icon(
                  onPressed: () {
                    for (final task in state.failedTasks) {
                      context.read<TransferBloc>().add(TransferRetryRequested(task.id));
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.posWarm),
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: const Text('Retry All'),
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: PosTerminalBanner(
                  title: 'Transfer console',
                  subtitle: 'Monitor import / export jobs for this terminal',
                  icon: Icons.swap_vert_circle_rounded,
                  statusLabel: activeCount > 0 ? '$activeCount LIVE' : 'IDLE',
                ),
              ),
              // Search Input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: AppTextField(
                  controller: _searchController,
                  variant: AppTextFieldVariant.filled,
                  isDense: true,
                  hintText: 'Search transfers by filename...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),

              // Filter Segment Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip(
                      context,
                      filter: TransferFilter.all,
                      label: 'All (${state.tasks.length})',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      filter: TransferFilter.active,
                      label: 'Active ($activeCount)',
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      filter: TransferFilter.completed,
                      label: 'Completed ($completedCount)',
                      color: colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      filter: TransferFilter.failed,
                      label: 'Failed ($failedCount)',
                      color: colorScheme.error,
                    ),
                  ],
                ),
              ),

              const Divider(height: 16),

              // Task List
              Expanded(
                child: filteredTasks.isEmpty
                    ? _buildEmptyState(context, colorScheme)
                    : RefreshIndicator(
                        onRefresh: () async {
                          context.read<TransferBloc>().add(const TransferInitializeRequested());
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            return TransferItemTile(
                              task: task,
                              onPause: () => context.read<TransferBloc>().add(TransferPauseRequested(task.id)),
                              onResume: () => context.read<TransferBloc>().add(TransferResumeRequested(task.id)),
                              onCancel: () => context.read<TransferBloc>().add(TransferCancelRequested(task.id)),
                              onRetry: () => context.read<TransferBloc>().add(TransferRetryRequested(task.id)),
                              onOpen: task.isCompleted &&
                                      task.type == TransferType.download
                                  ? () async {
                                      final file = File(task.localPath);
                                      if (await file.exists()) {
                                        await OpenFilex.open(task.localPath);
                                      }
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required TransferFilter filter,
    required String label,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedFilter == filter;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? (color ?? colorScheme.primary) : colorScheme.onSurfaceVariant,
        fontSize: 13,
      ),
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      selectedColor: (color ?? colorScheme.primary).withValues(alpha: 0.15),
      side: BorderSide(
        color: isSelected
            ? (color ?? colorScheme.primary)
            : colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (_) {
        setState(() {
          _selectedFilter = filter;
        });
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    String title = 'No transfers yet';
    String message = 'Start an upload or download to see activity here.';
    IconData icon = Icons.inbox_rounded;

    if (_selectedFilter == TransferFilter.active) {
      title = 'No active transfers';
      message = 'Nothing is uploading or downloading right now.';
      icon = Icons.sync_disabled_rounded;
    } else if (_selectedFilter == TransferFilter.completed) {
      title = 'No completed transfers';
      message = 'Finished uploads and downloads will appear here.';
      icon = Icons.check_circle_outline_rounded;
    } else if (_selectedFilter == TransferFilter.failed) {
      title = 'No failed transfers';
      message = 'Looking good — no failures in the queue.';
      icon = Icons.verified_rounded;
    }

    if (_searchQuery.isNotEmpty) {
      title = 'No matches';
      message = 'No transfer matched “$_searchQuery”.';
      icon = Icons.search_off_rounded;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: StatusPanel(
                icon: icon,
                iconColor: colorScheme.outline.withValues(alpha: 0.7),
                title: title,
                message: message,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              ),
            ),
          ),
        );
      },
    );
  }
}
