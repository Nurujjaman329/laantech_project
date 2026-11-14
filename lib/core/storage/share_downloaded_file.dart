import 'dart:io';

import 'package:share_plus/share_plus.dart';

/// Shares a completed download via the platform share sheet.
Future<bool> shareDownloadedFile(String path, {String? fileName}) async {
  final file = File(path);
  if (!await file.exists()) return false;

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path, name: fileName ?? file.uri.pathSegments.last)],
      subject: fileName ?? file.uri.pathSegments.last,
    ),
  );
  return true;
}
