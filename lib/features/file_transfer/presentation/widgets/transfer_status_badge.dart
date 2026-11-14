import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/transfer_task.dart';

/// Colored status chip for transfer rows (Uploading / Paused / Failed / Done…).
class TransferStatusBadge extends StatelessWidget {
  final TransferTask task;

  const TransferStatusBadge({
    super.key,
    required this.task,
  });

  String get _label {
    switch (task.status) {
      case TransferStatus.running:
        return task.type == TransferType.upload ? 'Uploading' : 'Downloading';
      case TransferStatus.paused:
        return 'Paused';
      case TransferStatus.completed:
        return 'Done';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
      case TransferStatus.queued:
        return 'Queued';
    }
  }

  Color _color(ColorScheme scheme) {
    switch (task.status) {
      case TransferStatus.running:
        return scheme.primary;
      case TransferStatus.paused:
        return AppColors.paused;
      case TransferStatus.completed:
        return AppColors.success;
      case TransferStatus.failed:
        return scheme.error;
      case TransferStatus.cancelled:
        return AppColors.cancelled;
      case TransferStatus.queued:
        return AppColors.queued;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(Theme.of(context).colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
