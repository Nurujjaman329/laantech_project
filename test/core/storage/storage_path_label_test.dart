import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/storage/storage_path_label.dart';

void main() {
  group('friendlyStoragePath', () {
    test('formats android-style app documents path', () {
      final label = friendlyStoragePath(
        '/data/user/0/com.example.laantech_task/app_flutter/pos_downloads/catalog.csv',
      );
      expect(label, 'Documents/pos_downloads/catalog.csv');
    });

    test('formats windows-style path with backslashes', () {
      final label = friendlyStoragePath(
        r'C:\Users\qa\Documents\pos_downloads\report.csv',
      );
      expect(label, 'Documents/pos_downloads/report.csv');
    });

    test('falls back to filename under pos_downloads', () {
      final label = friendlyStoragePath('/tmp/orphan/file.bin');
      expect(label, 'Documents/pos_downloads/file.bin');
    });
  });
}
