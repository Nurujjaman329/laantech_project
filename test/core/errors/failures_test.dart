import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/errors/failures.dart';

void main() {
  group('Failures Equatable & Equality Tests', () {
    test('ServerFailure props should match message and status code', () {
      const failure1 = ServerFailure(message: 'Error 500', statusCode: 500);
      const failure2 = ServerFailure(message: 'Error 500', statusCode: 500);
      const failure3 = ServerFailure(message: 'Error 404', statusCode: 404);

      expect(failure1, equals(failure2));
      expect(failure1 == failure3, isFalse);
    });

    test('NetworkFailure should have default message', () {
      const failure = NetworkFailure();
      expect(failure.message, contains('Network error'));
    });

    test('TransferFailure should support taskId', () {
      const failure = TransferFailure(
        message: 'Upload failed',
        taskId: 'task_123',
      );
      expect(failure.taskId, 'task_123');
      expect(failure.props, contains('task_123'));
    });
  });
}
