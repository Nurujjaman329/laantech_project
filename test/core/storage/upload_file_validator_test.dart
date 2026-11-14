import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/constants/api_constants.dart';
import 'package:laantech_task/core/storage/upload_file_validator.dart';

void main() {
  group('UploadFileValidator', () {
    test('rejects missing files', () {
      expect(
        UploadFileValidator.validate(exists: false, sizeBytes: 10),
        UploadFileValidator.missingFileMessage,
      );
    });

    test('rejects empty files', () {
      expect(
        UploadFileValidator.validate(exists: true, sizeBytes: 0),
        UploadFileValidator.emptyFileMessage,
      );
    });

    test('rejects files over maxUploadBytes', () {
      final message = UploadFileValidator.validate(
        exists: true,
        sizeBytes: ApiConstants.maxUploadBytes + 1,
      );
      expect(message, isNotNull);
      expect(message, contains('too large'));
    });

    test('accepts normal files under the cap', () {
      expect(
        UploadFileValidator.validate(exists: true, sizeBytes: 1024),
        isNull,
      );
    });
  });
}
