/// Formats an absolute download path into a short, user-facing label.
///
/// Example:
/// `/data/.../app_flutter/pos_downloads/catalog.csv`
/// → `Documents/pos_downloads/catalog.csv`
String friendlyStoragePath(String absolutePath) {
  if (absolutePath.isEmpty) return 'Documents/pos_downloads';

  final normalized = absolutePath.replaceAll('\\', '/');
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
