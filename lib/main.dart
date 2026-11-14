import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'core/network/connectivity_service.dart';
import 'core/network/dio_client.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/transfer_foreground_service.dart';
import 'core/notifications/transfer_notification_router.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';

import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/get_auth_status_usecase.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/logout_usecase.dart';
import 'features/auth/domain/usecases/register_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';

import 'features/file_transfer/data/datasources/file_remote_data_source.dart';
import 'features/file_transfer/data/repositories/file_transfer_repository_impl.dart';
import 'features/file_transfer/domain/usecases/transfer_usecases.dart';
import 'features/file_transfer/presentation/bloc/file_list_bloc.dart';
import 'features/file_transfer/presentation/bloc/transfer_bloc.dart';
import 'features/file_transfer/presentation/bloc/transfer_event.dart';
import 'features/file_transfer/presentation/screens/home_shell_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final TransferNotificationRouter transferNotificationRouter =
    TransferNotificationRouter();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Port for FGS ↔ UI communication (required by flutter_foreground_task).
  FlutterForegroundTask.initCommunicationPort();

  // Core Storage & Notifications
  final sharedPrefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();
  final tokenStorage = TokenStorageImpl(
    secureStorage: secureStorage,
    sharedPreferences: sharedPrefs,
  );

  final notificationService = NotificationServiceImpl();
  await notificationService.initialize(
    onSelectNotification: transferNotificationRouter.handlePayload,
  );

  final transferForegroundService = TransferForegroundServiceImpl();
  await transferForegroundService.init();

  // Cold start: app opened by tapping a transfer notification.
  final launchPayload = await notificationService.getLaunchPayload();
  if (launchPayload != null) {
    transferNotificationRouter.handlePayload(launchPayload);
  }

  // Core Networking
  final dioClient = DioClient(tokenStorage: tokenStorage);
  final connectivityService = ConnectivityServiceImpl();

  // Auth Feature
  final authRemoteDataSource = AuthRemoteDataSourceImpl(dioClient: dioClient);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    tokenStorage: tokenStorage,
  );
  final loginUseCase = LoginUseCase(authRepository);
  final registerUseCase = RegisterUseCase(authRepository);
  final logoutUseCase = LogoutUseCase(authRepository);
  final getAuthStatusUseCase = GetAuthStatusUseCase(authRepository);

  // File Transfer Feature
  final fileRemoteDataSource = FileRemoteDataSourceImpl(dioClient: dioClient);
  final fileTransferRepository = FileTransferRepositoryImpl(
    remoteDataSource: fileRemoteDataSource,
    notificationService: notificationService,
    sharedPreferences: sharedPrefs,
    foregroundService: transferForegroundService,
  );

  final getFilesUseCase = GetFilesUseCase(fileTransferRepository);
  final deleteFileUseCase = DeleteFileUseCase(fileTransferRepository);
  final startUploadUseCase = StartUploadUseCase(fileTransferRepository);
  final startDownloadUseCase = StartDownloadUseCase(fileTransferRepository);
  final pauseTransferUseCase = PauseTransferUseCase(fileTransferRepository);
  final resumeTransferUseCase = ResumeTransferUseCase(fileTransferRepository);
  final cancelTransferUseCase = CancelTransferUseCase(fileTransferRepository);
  final retryTransferUseCase = RetryTransferUseCase(fileTransferRepository);

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(
            loginUseCase: loginUseCase,
            registerUseCase: registerUseCase,
            logoutUseCase: logoutUseCase,
            getAuthStatusUseCase: getAuthStatusUseCase,
          )..add(const AuthCheckRequested()),
        ),
        BlocProvider<TransferBloc>(
          create: (_) => TransferBloc(
            repository: fileTransferRepository,
            startUploadUseCase: startUploadUseCase,
            startDownloadUseCase: startDownloadUseCase,
            pauseTransferUseCase: pauseTransferUseCase,
            resumeTransferUseCase: resumeTransferUseCase,
            cancelTransferUseCase: cancelTransferUseCase,
            retryTransferUseCase: retryTransferUseCase,
            connectivityService: connectivityService,
          )..add(const TransferInitializeRequested()),
        ),
        BlocProvider<FileListBloc>(
          create: (_) => FileListBloc(
            getFilesUseCase: getFilesUseCase,
            deleteFileUseCase: deleteFileUseCase,
          ),
        ),
      ],
      child: const PosTransferApp(),
    ),
  );
}

class PosTransferApp extends StatelessWidget {
  const PosTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'POS File Transfer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return HomeShellScreen(
              notificationRouter: transferNotificationRouter,
            );
          } else if (state is AuthUnauthenticated || state is AuthFailureState) {
            return LoginScreen(
              onLoginSuccess: () {},
            );
          }
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}
