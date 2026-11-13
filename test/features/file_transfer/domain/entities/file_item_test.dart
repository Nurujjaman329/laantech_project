import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/features/file_transfer/domain/entities/file_item.dart';

void main() {
  group('FileItem Entity Tests', () {
    test('formattedSize converts bytes to readable string', () {
      const item1 = FileItem(name: 'doc.txt', size: 1024);
      expect(item1.formattedSize, '1.0 KB');

      const item2 = FileItem(name: 'video.mp4', size: 52428800); // 50MB
      expect(item2.formattedSize, '50.0 MB');

      const item3 = FileItem(name: 'empty.dat', size: 0);
      expect(item3.formattedSize, 'Unknown size');
    });
  });
}
