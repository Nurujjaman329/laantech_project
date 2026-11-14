import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/di/injection_container.dart';
import 'package:laantech_task/core/notifications/transfer_notification_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppDependencies.init resolves all core dependencies and use cases', () async {
    final router = TransferNotificationRouter();
    final deps = await AppDependencies.init(notificationRouter: router);

    // Verify Core Singletons
    expect(deps.tokenStorage, isNotNull);
    expect(deps.notificationService, isNotNull);
    expect(deps.foregroundService, isNotNull);
    expect(deps.notificationRouter, equals(router));
    expect(deps.dioClient, isNotNull);
    expect(deps.connectivityService, isNotNull);

    // Verify Repositories
    expect(deps.authRepository, isNotNull);
    expect(deps.fileTransferRepository, isNotNull);

    // Verify Auth Use Cases
    expect(deps.loginUseCase, isNotNull);
    expect(deps.registerUseCase, isNotNull);
    expect(deps.logoutUseCase, isNotNull);
    expect(deps.getAuthStatusUseCase, isNotNull);

    // Verify Transfer Use Cases
    expect(deps.getFilesUseCase, isNotNull);
    expect(deps.deleteFileUseCase, isNotNull);
    expect(deps.startUploadUseCase, isNotNull);
    expect(deps.startDownloadUseCase, isNotNull);
    expect(deps.pauseTransferUseCase, isNotNull);
    expect(deps.resumeTransferUseCase, isNotNull);
    expect(deps.cancelTransferUseCase, isNotNull);
    expect(deps.retryTransferUseCase, isNotNull);

    // Verify BLoC provider generation
    final providers = deps.createBlocProviders();
    expect(providers.length, equals(3));
  });
}
