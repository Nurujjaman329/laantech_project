import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/features/file_transfer/domain/entities/transfer_task.dart';
import 'package:laantech_task/features/file_transfer/presentation/widgets/transfer_status_badge.dart';

void main() {
  TransferTask task({
    required TransferType type,
    required TransferStatus status,
  }) {
    return TransferTask(
      id: 't1',
      fileName: 'catalog.csv',
      localPath: '/tmp/catalog.csv',
      type: type,
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  Future<void> pumpBadge(WidgetTester tester, TransferTask task) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransferStatusBadge(task: task),
        ),
      ),
    );
  }

  testWidgets('shows Uploading for running upload', (tester) async {
    await pumpBadge(
      tester,
      task(type: TransferType.upload, status: TransferStatus.running),
    );
    expect(find.text('Uploading'), findsOneWidget);
  });

  testWidgets('shows Downloading for running download', (tester) async {
    await pumpBadge(
      tester,
      task(type: TransferType.download, status: TransferStatus.running),
    );
    expect(find.text('Downloading'), findsOneWidget);
  });

  testWidgets('shows Paused / Failed / Done labels', (tester) async {
    await pumpBadge(
      tester,
      task(type: TransferType.upload, status: TransferStatus.paused),
    );
    expect(find.text('Paused'), findsOneWidget);

    await pumpBadge(
      tester,
      task(type: TransferType.upload, status: TransferStatus.failed),
    );
    expect(find.text('Failed'), findsOneWidget);

    await pumpBadge(
      tester,
      task(type: TransferType.download, status: TransferStatus.completed),
    );
    expect(find.text('Done'), findsOneWidget);
  });
}
