import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/notifications/transfer_notification_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/file_transfer/presentation/screens/home_shell_screen.dart';

/// Global navigator key allowing root context navigation from system notification taps.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Global transfer notification router instance.
final TransferNotificationRouter transferNotificationRouter =
    TransferNotificationRouter();

/// Root Application Widget configuring theme, routes, and authentication state listener.
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
