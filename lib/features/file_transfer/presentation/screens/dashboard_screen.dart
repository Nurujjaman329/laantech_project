import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
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
                _buildStoreHeader(context, colorScheme, activeTasks.length),

                const SizedBox(height: 16),

                // Metrics Overview (2x2 Grid)
                _buildMetricsGrid(
                  context,
                  colorScheme,
                  activeCount: activeTasks.length,
                  completedCount: completedTasks.length,
                  failedCount: failedTasks.length,
                  totalVolume: _formatBytes(totalBytesTransferred),
                ),

                const SizedBox(height: 24),

                // Quick POS Actions
                Text(
                  'Quick Operations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.posInk,
                  ),
                ),
                const SizedBox(height: 12),
                _buildQuickActions(context, colorScheme),

                const SizedBox(height: 24),

                // Active Transfers / Recent Activity Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activeTasks.isNotEmpty ? 'Live Transfers' : 'Recent Transfers',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.posInk,
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

  Widget _buildStoreHeader(BuildContext context, ColorScheme colorScheme, int activeCount) {
    final nowFormatted = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());
    final statusColor =
        activeCount > 0 ? AppColors.posWarm : AppColors.posAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.posNavy, AppColors.posInk, AppColors.posPanel],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.posNavy.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POS Terminal #104',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nowFormatted,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activeCount > 0
                      ? Icons.sync_rounded
                      : Icons.check_circle_rounded,
                  size: 14,
                  color: statusColor,
                ),
                const SizedBox(width: 4),
                Text(
                  activeCount > 0 ? '$activeCount Syncing' : 'Online',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(
    BuildContext context,
    ColorScheme colorScheme, {
    required int activeCount,
    required int completedCount,
    required int failedCount,
    required String totalVolume,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context,
              width: cardWidth,
              title: 'Active Syncs',
              value: '$activeCount',
              icon: Icons.sync_rounded,
              color: colorScheme.primary,
              containerColor: colorScheme.primaryContainer,
              onTap: () => onNavigateToTab?.call(3),
            ),
            _buildStatCard(
              context,
              width: cardWidth,
              title: 'Completed',
              value: '$completedCount',
              icon: Icons.done_all_rounded,
              color: colorScheme.tertiary,
              containerColor: colorScheme.tertiaryContainer,
              onTap: () => onNavigateToTab?.call(3),
            ),
            _buildStatCard(
              context,
              width: cardWidth,
              title: 'Failed / Pending',
              value: '$failedCount',
              icon: Icons.error_outline_rounded,
              color: failedCount > 0 ? colorScheme.error : colorScheme.outline,
              containerColor: failedCount > 0
                  ? colorScheme.errorContainer
                  : colorScheme.surfaceContainerHighest,
              onTap: () => onNavigateToTab?.call(3),
            ),
            _buildStatCard(
              context,
              width: cardWidth,
              title: 'Total Volume',
              value: totalVolume,
              icon: Icons.data_usage_rounded,
              color: colorScheme.secondary,
              containerColor: colorScheme.secondaryContainer,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color containerColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: width,
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: containerColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _buildActionItem(
            context,
            icon: Icons.upload_file_rounded,
            label: 'Import Catalog',
            subtitle: 'Upload 50MB+ data',
            color: colorScheme.primary,
            onTap: () => onNavigateToTab?.call(1), // Upload tab
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionItem(
            context,
            icon: Icons.download_for_offline_rounded,
            label: 'Export / Pull',
            subtitle: 'Download server files',
            color: colorScheme.tertiary,
            onTap: () => onNavigateToTab?.call(2), // Download tab
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
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
