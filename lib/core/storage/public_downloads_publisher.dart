import 'dart:io';

import 'package:flutter/services.dart';

/// Publishes a completed download into the device public Downloads folder
/// (Android MediaStore) so it appears in the system file manager.
class PublicDownloadsPublisher {
  static const _channel = MethodChannel('laantech_task/public_downloads');

  /// Copies [sourcePath] into `Download/POS_Transfers/[fileName]`.
  /// Returns a user-facing label like `Downloads/POS_Transfers/file.csv`,
  /// or null when unavailable / non-Android.
  Future<String?> publish({
    required String sourcePath,
    required String fileName,
  }) async {
    if (!Platform.isAndroid) return null;

    final source = File(sourcePath);
    if (!await source.exists()) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'publishToDownloads',
        {
          'sourcePath': sourcePath,
          'fileName': fileName,
          'relativePath': 'Download/POS_Transfers',
        },
      );
      final displayPath = result?['displayPath'] as String?;
      if (displayPath != null && displayPath.isNotEmpty) {
        return displayPath;
      }
    } catch (_) {
      // Fall through — app-private file remains usable via Open/Share.
    }
    return null;
  }
}
