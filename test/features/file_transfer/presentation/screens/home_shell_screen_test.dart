import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/features/auth/domain/entities/auth_token.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_event.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_state.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/file_list_bloc.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/file_list_event.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/file_list_state.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/transfer_bloc.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/transfer_event.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/transfer_state.dart';
import 'package:laantech_task/features/file_transfer/presentation/screens/home_shell_screen.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
class MockTransferBloc extends MockBloc<TransferEvent, TransferState> implements TransferBloc {}
class MockFileListBloc extends MockBloc<FileListEvent, FileListState> implements FileListBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockTransferBloc mockTransferBloc;
  late MockFileListBloc mockFileListBloc;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockTransferBloc = MockTransferBloc();
    mockFileListBloc = MockFileListBloc();
  });

  Widget buildTestableWidget() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: mockAuthBloc),
        BlocProvider<TransferBloc>.value(value: mockTransferBloc),
        BlocProvider<FileListBloc>.value(value: mockFileListBloc),
      ],
      child: const MaterialApp(
        home: HomeShellScreen(),
      ),
    );
  }

  testWidgets('renders HomeShellScreen with all 5 navigation destinations and default Dashboard', (tester) async {
    when(() => mockAuthBloc.state).thenReturn(
      const AuthAuthenticated(
        AuthToken(token: 'dummy_token', username: 'cashier_01'),
      ),
    );
    when(() => mockTransferBloc.state).thenReturn(const TransferState());
    when(() => mockFileListBloc.state).thenReturn(const FileListInitial());

    await tester.pumpWidget(buildTestableWidget());

    // Header & User info
    expect(find.text('cashier_01'), findsOneWidget);
    expect(find.text('Store #104 • Online'), findsOneWidget);

    // Navigation bar labels
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Transfers'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Dashboard items
    expect(find.text('POS Terminal #104'), findsOneWidget);
    expect(find.text('Quick Operations'), findsOneWidget);
    expect(find.text('Import Catalog'), findsOneWidget);
    expect(find.text('Export / Pull'), findsOneWidget);
  });

  testWidgets('tapping Transfers tab displays Transfers screen', (tester) async {
    when(() => mockAuthBloc.state).thenReturn(
      const AuthAuthenticated(
        AuthToken(token: 'dummy_token', username: 'cashier_01'),
      ),
    );
    when(() => mockTransferBloc.state).thenReturn(const TransferState());
    when(() => mockFileListBloc.state).thenReturn(const FileListInitial());

    await tester.pumpWidget(buildTestableWidget());

    // Tap on Transfers destination
    await tester.tap(find.text('Transfers'));
    await tester.pumpAndSettle();

    expect(find.text('Transfers'), findsWidgets);
    expect(find.text('Search transfers by filename...'), findsOneWidget);
    expect(find.text('All (0)'), findsOneWidget);
  });
}
