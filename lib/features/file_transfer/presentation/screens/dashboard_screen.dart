import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
import '../widgets/dashboard_metrics_grid.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/dashboard_store_header.dart';
import '../widgets/transfer_item_tile.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigateToTab;

  const DashboardScreen({
    super.key,
    this.onNavigateToTab,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<TransferBloc, TransferState>(
      builder: (context, state) {
        final activeTasks = state.activeTasks;
        final completedTasks = state.completedTasks;
        final failedTasks = state.failedTasks;
        final allTasks = state.allTasks;

        final totalBytesTransferred = allTasks.fold<int>(
          0,
          (sum, task) => sum + task.bytesTransferred,
        );

        final displayTasks = activeTasks.isNotEmpty
            ? activeTasks.take(3).toList()
            : allTasks.take(3).toList();

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<TransferBloc>().add(const TransferInitializeRequested());
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // Top Store Status Banner
                DashboardStoreHeader(activeCount: activeTasks.length),

                const SizedBox(height: 16),

                // Metrics Overview (2x2 Grid)
                DashboardMetricsGrid(
                  activeCount: activeTasks.length,
                  completedCount: completedTasks.length,
                  failedCount: failedTasks.length,
                  totalVolume: _formatBytes(totalBytesTransferred),
                  onNavigateToTab: onNavigateToTab,
                ),

                const SizedBox(height: 24),

                // Quick POS Actions
                Text(
                  'Quick Operations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                DashboardQuickActions(onNavigateToTab: onNavigateToTab),

                const SizedBox(height: 24),

                // Active Transfers / Recent Activity Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activeTasks.isNotEmpty ? 'Live Transfers' : 'Recent Transfers',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (allTasks.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => onNavigateToTab?.call(3), // Go to Transfers tab
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('View All'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Tasks List
                if (allTasks.isEmpty)
                  _buildEmptyState(context, colorScheme)
                else
                  ...displayTasks.map(
                    (task) => TransferItemTile(
                      task: task,
                      onPause: () => context.read<TransferBloc>().add(TransferPauseRequested(task.id)),
                      onResume: () => context.read<TransferBloc>().add(TransferResumeRequested(task.id)),
                      onCancel: () => context.read<TransferBloc>().add(TransferCancelRequested(task.id)),
                      onRetry: () => context.read<TransferBloc>().add(TransferRetryRequested(task.id)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 40,
            color: colorScheme.outline.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Text(
            'Transfer queue is idle',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start an upload or download operation to track real-time progress.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
