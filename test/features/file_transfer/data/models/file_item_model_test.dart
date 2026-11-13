import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/features/file_transfer/data/models/file_item_model.dart';

void main() {
  group('FileItemModel Tests', () {
    test('fromDynamic parses String file name', () {
      final model = FileItemModel.fromDynamic('catalog_2026.csv');
      expect(model.name, 'catalog_2026.csv');
      expect(model.size, isNull);
    });

    test('fromDynamic parses Map file details', () {
      final map = {
        'name': 'products.json',
        'size': 2048,
        'modified_at': '2026-11-13T10:00:00.000Z',
      };
      final model = FileItemModel.fromDynamic(map);
      expect(model.name, 'products.json');
      expect(model.size, 2048);
      expect(model.modifiedAt, isNotNull);
    });

    test('fromResponse handles List of dynamic items', () {
      final list = ['fileA.png', {'name': 'fileB.csv', 'size': 500}];
      final items = FileItemModel.fromResponse(list);
      expect(items.length, 2);
      expect(items[0].name, 'fileA.png');
      expect(items[1].name, 'fileB.csv');
      expect(items[1].size, 500);
    });

    test('fromResponse handles Map with files key', () {
      final map = {
        'files': ['report1.csv', 'report2.csv'],
      };
      final items = FileItemModel.fromResponse(map);
      expect(items.length, 2);
      expect(items[0].name, 'report1.csv');
    });

    test('fromResponse returns empty list for null or invalid data', () {
      expect(FileItemModel.fromResponse(null), isEmpty);
      expect(FileItemModel.fromResponse(12345), isEmpty);
    });
  });
}
