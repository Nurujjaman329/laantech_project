import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/features/file_transfer/domain/entities/transfer_task.dart';

void main() {
  group('TransferTask Entity Tests', () {
    final now = DateTime.now();
    final task = TransferTask(
      id: 'task_001',
      fileName: 'catalog.csv',
      localPath: '/downloads/catalog.csv',
      type: TransferType.download,
      status: TransferStatus.running,
      bytesTransferred: 500,
      totalBytes: 1000,
      progress: 0.5,
      createdAt: now,
    );

    test('should report correct boolean status flags', () {
      expect(task.isRunning, isTrue);
      expect(task.isPaused, isFalse);
      expect(task.isCompleted, isFalse);
      expect(task.isFailed, isFalse);
    });

    test('copyWith updates state immutably', () {
      final updated = task.copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
        bytesTransferred: 1000,
      );

      expect(updated.status, TransferStatus.completed);
      expect(updated.progress, 1.0);
      expect(updated.bytesTransferred, 1000);
      expect(updated.isCompleted, isTrue);
      expect(task.status, TransferStatus.running); // original untouched
    });
  });
}
