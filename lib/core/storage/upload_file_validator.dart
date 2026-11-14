import '../constants/api_constants.dart';

/// Shared upload pre-checks (UI + repository). No I/O — callers pass file stats.
class UploadFileValidator {
  UploadFileValidator._();

  static const String missingFileMessage =
      'File not found, please pick it again.';
  static const String emptyFileMessage = 'This file is empty.';

  static String tooLargeMessage(int maxBytes) {
    final mb = (maxBytes / (1024 * 1024)).round();
    return 'File is too large. Maximum size is ${mb}MB.';
  }

  /// Returns a friendly error message, or null when the file is valid.
  static String? validate({
    required bool exists,
    required int sizeBytes,
    int maxBytes = ApiConstants.maxUploadBytes,
  }) {
    if (!exists) return missingFileMessage;
    if (sizeBytes <= 0) return emptyFileMessage;
    if (sizeBytes > maxBytes) return tooLargeMessage(maxBytes);
    return null;
  }
}
