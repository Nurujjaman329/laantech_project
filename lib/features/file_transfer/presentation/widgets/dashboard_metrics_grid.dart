import 'package:flutter/material.dart';

class DashboardMetricsGrid extends StatelessWidget {
  final int activeCount;
  final int completedCount;
  final int failedCount;
  final String totalVolume;
  final ValueChanged<int>? onNavigateToTab;

  const DashboardMetricsGrid({
    super.key,
    required this.activeCount,
    required this.completedCount,
    required this.failedCount,
    required this.totalVolume,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DashboardStatCard(
              width: cardWidth,
              title: 'Active Syncs',
              value: '$activeCount',
              icon: Icons.sync_rounded,
              color: colorScheme.primary,
              containerColor: colorScheme.primaryContainer,
              onTap: () => onNavigateToTab?.call(3),
            ),
            DashboardStatCard(
              width: cardWidth,
              title: 'Completed',
              value: '$completedCount',
              icon: Icons.done_all_rounded,
              color: colorScheme.tertiary,
              containerColor: colorScheme.tertiaryContainer,
              onTap: () => onNavigateToTab?.call(3),
            ),
            DashboardStatCard(
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
            DashboardStatCard(
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
}

class DashboardStatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color containerColor;
  final VoidCallback? onTap;

  const DashboardStatCard({
    super.key,
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.containerColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}
