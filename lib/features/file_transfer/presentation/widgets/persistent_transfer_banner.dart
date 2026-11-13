import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_state.dart';
import 'persistent_transfer_sheet.dart';

class PersistentTransferBanner extends StatelessWidget {
  const PersistentTransferBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TransferBloc, TransferState>(
      builder: (context, state) {
        if (!state.hasActiveTransfers) {
          return const SizedBox.shrink();
        }

        final activeCount = state.activeTasks.length;
        final progress = state.overallProgress;

        return Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.primaryContainer,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => PersistentTransferSheet.show(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            value: progress > 0 ? progress : null,
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$activeCount active ${activeCount == 1 ? 'transfer' : 'transfers'} (${(progress * 100).toStringAsFixed(0)}%)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        Text(
                          'View',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        minHeight: 4,
                        backgroundColor: theme.colorScheme.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
