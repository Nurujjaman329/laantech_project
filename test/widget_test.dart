import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_event.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_state.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/file_list_bloc.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/file_list_event.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/file_list_state.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/transfer_bloc.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/transfer_event.dart';
import 'package:laantech_task/features/file_transfer/presentation/bloc/transfer_state.dart';
import 'package:laantech_task/app.dart';

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

  testWidgets('renders LoginScreen when AuthState is AuthUnauthenticated', (WidgetTester tester) async {
    when(() => mockAuthBloc.state).thenReturn(const AuthUnauthenticated());
    when(() => mockTransferBloc.state).thenReturn(const TransferState());
    when(() => mockFileListBloc.state).thenReturn(const FileListInitial());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          BlocProvider<TransferBloc>.value(value: mockTransferBloc),
          BlocProvider<FileListBloc>.value(value: mockFileListBloc),
        ],
        child: const PosTransferApp(),
      ),
    );

    expect(find.text('LAANTECH'), findsOneWidget);
    expect(find.text('Sign in'), findsAtLeastNWidgets(1));
    expect(find.text('Register'), findsAtLeastNWidgets(1));
  });
}
