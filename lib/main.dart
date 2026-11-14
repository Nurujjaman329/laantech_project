import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';
import 'core/di/injection_container.dart';

export 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Communication port for FGS <-> UI isolate message exchange.
  FlutterForegroundTask.initCommunicationPort();

  // Initialize centralized dependency injection container.
  final dependencies = await AppDependencies.init(
    notificationRouter: transferNotificationRouter,
  );

  runApp(
    MultiBlocProvider(
      providers: dependencies.createBlocProviders(),
      child: const PosTransferApp(),
    ),
  );
}
