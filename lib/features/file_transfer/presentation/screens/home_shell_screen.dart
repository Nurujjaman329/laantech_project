import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:laantech_task/core/notifications/transfer_notification_router.dart';
import 'package:laantech_task/core/theme/app_colors.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_event.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_state.dart';

import '../../domain/entities/transfer_task.dart';
import '../bloc/file_list_bloc.dart';
import '../bloc/file_list_event.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
import '../widgets/persistent_transfer_banner.dart';
import '../widgets/persistent_transfer_sheet.dart';
import 'dashboard_screen.dart';
import 'download_screen.dart';
import 'settings_screen.dart';
import 'transfer_manager_screen.dart';
import 'upload_screen.dart';

/// Download tab index in the bottom [NavigationBar].
const int kDownloadTabIndex = 2;

/// True when any upload task newly reaches [TransferStatus.completed].
@visibleForTesting
bool hasNewlyCompletedUpload(TransferState previous, TransferState current) {
  for (final entry in current.tasks.entries) {
    final task = entry.value;
    if (task.type != TransferType.upload ||
        task.status != TransferStatus.completed) {
      continue;
    }
    final prior = previous.tasks[entry.key];
    if (prior == null || prior.status != TransferStatus.completed) {
      return true;
    }
  }
  return false;
}

class HomeShellScreen extends StatefulWidget {
  final TransferNotificationRouter? notificationRouter;

  const HomeShellScreen({
    super.key,
    this.notificationRouter,
  });

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.notificationRouter?.pending.addListener(_onNotificationDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onNotificationDeepLink();
    });
  }

  @override
  void dispose() {
    widget.notificationRouter?.pending.removeListener(_onNotificationDeepLink);
    super.dispose();
  }

  void _onNotificationDeepLink() {
    final router = widget.notificationRouter;
    final link = router?.pending.value;
    if (router == null || link == null || !mounted) return;

    _navigateToTab(link.tabIndex);

    if (link.showSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        PersistentTransferSheet.show(context);
      });
    }

    router.consume();
  }

  void _navigateToTab(int index) {
    if (index < 0 || index >= 5) return;
    final switchedToDownload =
        index == kDownloadTabIndex && _currentIndex != kDownloadTabIndex;
    setState(() {
      _currentIndex = index;
    });
    if (switchedToDownload) {
      context.read<FileListBloc>().add(const FileListFetchRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final screens = [
      DashboardScreen(onNavigateToTab: _navigateToTab),
      const UploadScreen(),
      const DownloadScreen(),
      const TransferManagerScreen(),
      const SettingsScreen(),
    ];

    return MultiBlocListener(
      listeners: [
        BlocListener<TransferBloc, TransferState>(
          listenWhen: hasNewlyCompletedUpload,
          listener: (context, state) {
            context.read<FileListBloc>().add(const FileListFetchRequested());
          },
        ),
        BlocListener<TransferBloc, TransferState>(
          listenWhen: (previous, current) =>
              previous.isOffline != current.isOffline ||
              previous.showNetworkRestoredPrompt !=
                  current.showNetworkRestoredPrompt ||
              previous.errorMessage != current.errorMessage ||
              previous.sessionExpired != current.sessionExpired,
          listener: (context, state) {
            final messenger = ScaffoldMessenger.of(context);
            final colorScheme = Theme.of(context).colorScheme;

            if (state.sessionExpired) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      state.errorMessage ??
                          'Session expired. Please sign in again.',
                    ),
                    backgroundColor: colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              context
                  .read<TransferBloc>()
                  .add(const TransferSessionExpiredHandled());
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              return;
            }

            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              context.read<TransferBloc>().add(const TransferErrorCleared());
              return;
            }

            if (state.isOffline) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Network offline — active transfers were paused.',
                    ),
                    duration: Duration(seconds: 4),
                  ),
                );
              return;
            }

            if (state.showNetworkRestoredPrompt) {
              final count = state.networkPausedTaskIds.length;
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      'Network restored. Resume $count paused '
                      '${count == 1 ? 'transfer' : 'transfers'}?',
                    ),
                    duration: const Duration(seconds: 10),
                    action: SnackBarAction(
                      label: 'Resume',
                      onPressed: () {
                        context.read<TransferBloc>().add(
                              const TransferResumeNetworkPausedRequested(),
                            );
                      },
                    ),
                  ),
                );
              context.read<TransferBloc>().add(
                    const TransferDismissNetworkPromptRequested(),
                  );
            }
          },
        ),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.posNavy,
        foregroundColor: Colors.white,
        title: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            String username = 'POS Operator';
            if (state is AuthAuthenticated) {
              username = state.authToken.username;
            }
            return Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Store #104 • Online',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.posAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          BlocBuilder<TransferBloc, TransferState>(
            builder: (context, state) {
              final activeCount = state.activeTasks.length;
              return IconButton(
                icon: Badge(
                  isLabelVisible: activeCount > 0,
                  backgroundColor: AppColors.posWarm,
                  label: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: AppColors.posNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Icon(
                    activeCount > 0
                        ? Icons.sync_rounded
                        : Icons.swap_vert_circle_outlined,
                    color: activeCount > 0
                        ? AppColors.posWarm
                        : Colors.white70,
                  ),
                ),
                tooltip: 'Quick Transfers Sheet',
                onPressed: () => PersistentTransferSheet.show(context),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          BlocBuilder<TransferBloc, TransferState>(
            buildWhen: (previous, current) =>
                previous.isOffline != current.isOffline,
            builder: (context, state) {
              if (!state.isOffline) return const SizedBox.shrink();
              final offlineScheme = Theme.of(context).colorScheme;
              return Material(
                color: offlineScheme.errorContainer,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 18,
                        color: offlineScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are offline. Transfers stay paused until network returns.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: offlineScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: _currentIndex,
                  children: screens,
                ),
                const PersistentTransferBanner(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BlocBuilder<TransferBloc, TransferState>(
        builder: (context, state) {
          final activeCount = state.activeTasks.length;

          return NavigationBar(
            selectedIndex: _currentIndex,
            elevation: 2,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.posInk.withValues(alpha: 0.12),
            onDestinationSelected: _navigateToTab,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.cloud_upload_outlined),
                selectedIcon: Icon(Icons.cloud_upload_rounded),
                label: 'Upload',
              ),
              const NavigationDestination(
                icon: Icon(Icons.cloud_download_outlined),
                selectedIcon: Icon(Icons.cloud_download_rounded),
                label: 'Download',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: activeCount > 0,
                  backgroundColor: AppColors.posWarm,
                  label: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: AppColors.posNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Icon(Icons.swap_vert_circle_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: activeCount > 0,
                  backgroundColor: AppColors.posWarm,
                  label: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: AppColors.posNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Icon(Icons.swap_vert_circle_rounded),
                ),
                label: 'Transfers',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          );
        },
      ),
    ),
      ),
    );
  }
}
