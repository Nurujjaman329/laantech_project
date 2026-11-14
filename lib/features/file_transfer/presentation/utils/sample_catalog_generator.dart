import 'dart:io';

/// Helper utility to generate >50MB test catalog CSV files on device storage.
class SampleCatalogGenerator {
  SampleCatalogGenerator._();

  static const String defaultFileName = 'catalog_sample_50mb.csv';
  static const int targetBytes = 52428800; // 50MB

  /// Generates a valid POS catalog CSV file in the system temp directory.
  static Future<File> generate() async {
    final tempDir = Directory.systemTemp;
    final sampleFile = File('${tempDir.path}/$defaultFileName');
    final sink = sampleFile.openWrite();

    sink.writeln('id,sku,name,price,inventory_count,description,category');

    const row =
        '1001,SKU-PROD-001,Wireless Barcode Scanner,129.99,450,High speed 2D barcode scanner with Bluetooth for retail POS stations,Hardware\n';
    final iterations = targetBytes ~/ row.length;
    for (int i = 0; i < iterations; i++) {
      sink.write(row);
    }
    await sink.flush();
    await sink.close();

    return sampleFile;
  }
}
