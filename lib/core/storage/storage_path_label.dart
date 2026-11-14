/// Formats an absolute download path into a short, user-facing label.
///
/// Prefer [publicPathLabel] when a MediaStore / public Downloads publish
/// succeeded (e.g. `Downloads/POS_Transfers/catalog.csv`).
///
/// Example fallback:
/// `/data/.../app_flutter/pos_downloads/catalog.csv`
/// → `Documents/pos_downloads/catalog.csv`
String friendlyStoragePath(
  String absolutePath, {
  String? publicPathLabel,
}) {
  if (publicPathLabel != null && publicPathLabel.isNotEmpty) {
    return publicPathLabel;
  }

  if (absolutePath.isEmpty) return 'Documents/pos_downloads';

  final normalized = absolutePath.replaceAll('\\', '/');

  if (normalized.contains('/Download/POS_Transfers/') ||
      normalized.contains('/Downloads/POS_Transfers/')) {
    final fileName = normalized.split('/').last;
    return 'Downloads/POS_Transfers/$fileName';
  }

  final marker = '/pos_downloads/';
  final index = normalized.toLowerCase().indexOf(marker);

  if (index >= 0) {
    final relative = normalized.substring(index + 1); // pos_downloads/...
    return 'Documents/$relative';
  }

  final fileName = normalized.split('/').last;
  if (fileName.isEmpty) return 'Documents/pos_downloads';
  return 'Documents/pos_downloads/$fileName';
}
