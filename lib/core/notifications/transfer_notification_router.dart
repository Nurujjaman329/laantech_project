import 'package:flutter/foundation.dart';

/// Parsed deep link from a transfer notification payload.
class TransferDeepLink {
  /// HomeShell tab: 1 = Upload, 2 = Download, 3 = Transfers.
  final int tabIndex;
  final String? taskId;
  final bool showSheet;

  const TransferDeepLink({
    required this.tabIndex,
    this.taskId,
    this.showSheet = true,
  });

  /// Payload format used by [FileTransferRepositoryImpl]:
  /// `upload_<taskId>` or `download_<taskId>`.
  static TransferDeepLink? tryParse(String? payload) {
    if (payload == null || payload.isEmpty) {
      return const TransferDeepLink(tabIndex: 3);
    }

    if (payload.startsWith('upload_')) {
      final taskId = payload.substring('upload_'.length);
      return TransferDeepLink(
        tabIndex: 1,
        taskId: taskId.isEmpty ? null : taskId,
      );
    }

    if (payload.startsWith('download_')) {
      final taskId = payload.substring('download_'.length);
      return TransferDeepLink(
        tabIndex: 2,
        taskId: taskId.isEmpty ? null : taskId,
      );
    }

    return const TransferDeepLink(tabIndex: 3);
  }
}

/// Holds a pending notification deep link until [HomeShellScreen] can consume it
/// (works for foreground taps and cold-start launches).
class TransferNotificationRouter {
  final ValueNotifier<TransferDeepLink?> pending =
      ValueNotifier<TransferDeepLink?>(null);

  void handlePayload(String? payload) {
    pending.value = TransferDeepLink.tryParse(payload);
  }

  void consume() {
    pending.value = null;
  }

  void dispose() {
    pending.dispose();
  }
}
