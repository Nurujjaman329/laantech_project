import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/connectivity_service.dart';
import '../network/dio_client.dart';
import '../notifications/notification_service.dart';
import '../notifications/transfer_foreground_service.dart';
import '../notifications/transfer_notification_router.dart';
import '../storage/token_storage.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_auth_status_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';

import '../../features/file_transfer/data/datasources/file_remote_data_source.dart';
import '../../features/file_transfer/data/repositories/file_transfer_repository_impl.dart';
import '../../features/file_transfer/domain/repositories/file_transfer_repository.dart';
import '../../features/file_transfer/domain/usecases/transfer_usecases.dart';
import '../../features/file_transfer/presentation/bloc/file_list_bloc.dart';
import '../../features/file_transfer/presentation/bloc/transfer_bloc.dart';
import '../../features/file_transfer/presentation/bloc/transfer_event.dart';

/// Centralized Dependency Injection Container for the application.
/// Encapsulates initialization of Core Services, Repositories, UseCases,
/// and BLoC factories without cluttering [main.dart].
class AppDependencies {
  final TokenStorage tokenStorage;
  final NotificationService notificationService;
  final TransferForegroundService foregroundService;
  final TransferNotificationRouter notificationRouter;
  final DioClient dioClient;
  final ConnectivityService connectivityService;
  final AuthRepository authRepository;
  final FileTransferRepository fileTransferRepository;

  // Auth Use Cases
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final GetAuthStatusUseCase getAuthStatusUseCase;

  // Transfer Use Cases
  final GetFilesUseCase getFilesUseCase;
  final DeleteFileUseCase deleteFileUseCase;
  final StartUploadUseCase startUploadUseCase;
  final StartDownloadUseCase startDownloadUseCase;
  final PauseTransferUseCase pauseTransferUseCase;
  final ResumeTransferUseCase resumeTransferUseCase;
  final CancelTransferUseCase cancelTransferUseCase;
  final RetryTransferUseCase retryTransferUseCase;

  AppDependencies({
    required this.tokenStorage,
    required this.notificationService,
    required this.foregroundService,
    required this.notificationRouter,
    required this.dioClient,
    required this.connectivityService,
    required this.authRepository,
    required this.fileTransferRepository,
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.getAuthStatusUseCase,
    required this.getFilesUseCase,
    required this.deleteFileUseCase,
    required this.startUploadUseCase,
    required this.startDownloadUseCase,
    required this.pauseTransferUseCase,
    required this.resumeTransferUseCase,
    required this.cancelTransferUseCase,
    required this.retryTransferUseCase,
  });

  /// Asynchronously initializes all low-level services, databases, and dependencies.
  static Future<AppDependencies> init({
    TransferNotificationRouter? notificationRouter,
  }) async {
    final router = notificationRouter ?? TransferNotificationRouter();

    // Core Storage & Notifications
    final sharedPrefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    final tokenStorage = TokenStorageImpl(
      secureStorage: secureStorage,
      sharedPreferences: sharedPrefs,
    );

    final notificationService = NotificationServiceImpl();
    await notificationService.initialize(
      onSelectNotification: router.handlePayload,
    );

    final transferForegroundService = TransferForegroundServiceImpl();
    await transferForegroundService.init();

    // Cold start check: user tapped a system notification to launch the app
    final launchPayload = await notificationService.getLaunchPayload();
    if (launchPayload != null) {
      router.handlePayload(launchPayload);
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

    return AppDependencies(
      tokenStorage: tokenStorage,
      notificationService: notificationService,
      foregroundService: transferForegroundService,
      notificationRouter: router,
      dioClient: dioClient,
      connectivityService: connectivityService,
      authRepository: authRepository,
      fileTransferRepository: fileTransferRepository,
      loginUseCase: loginUseCase,
      registerUseCase: registerUseCase,
      logoutUseCase: logoutUseCase,
      getAuthStatusUseCase: getAuthStatusUseCase,
      getFilesUseCase: getFilesUseCase,
      deleteFileUseCase: deleteFileUseCase,
      startUploadUseCase: startUploadUseCase,
      startDownloadUseCase: startDownloadUseCase,
      pauseTransferUseCase: pauseTransferUseCase,
      resumeTransferUseCase: resumeTransferUseCase,
      cancelTransferUseCase: cancelTransferUseCase,
      retryTransferUseCase: retryTransferUseCase,
    );
  }

  /// Builds the top-level list of BLoC providers for the widget tree.
  List<BlocProvider> createBlocProviders() {
    return [
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
    ];
  }
}
