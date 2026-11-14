import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/transfer_task.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
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
            title: const Text(
              'Transfer Manager',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              if (failedCount > 0)
                TextButton.icon(
                  onPressed: () {
                    for (final task in state.failedTasks) {
                      context.read<TransferBloc>().add(TransferRetryRequested(task.id));
                    }
                  },
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: const Text('Retry All'),
                ),
            ],
          ),
          body: Column(
            children: [
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
    final theme = Theme.of(context);

    String message = 'No transfer records found';
    IconData icon = Icons.inbox_rounded;

    if (_selectedFilter == TransferFilter.active) {
      message = 'No active uploads or downloads';
      icon = Icons.sync_disabled_rounded;
    } else if (_selectedFilter == TransferFilter.completed) {
      message = 'No completed transfers yet';
      icon = Icons.check_circle_outline_rounded;
    } else if (_selectedFilter == TransferFilter.failed) {
      message = 'No failed transfers. System running cleanly!';
      icon = Icons.verified_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: colorScheme.outline.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'No match for "$_searchQuery"',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
