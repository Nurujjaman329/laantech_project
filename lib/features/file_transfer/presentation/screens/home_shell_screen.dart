import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:laantech_task/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_event.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_state.dart';

import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_state.dart';
import '../widgets/persistent_transfer_banner.dart';
import '../widgets/persistent_transfer_sheet.dart';
import 'dashboard_screen.dart';
import 'download_screen.dart';
import 'settings_screen.dart';
import 'transfer_manager_screen.dart';
import 'upload_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    if (index >= 0 && index < 5) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final screens = [
      DashboardScreen(onNavigateToTab: _navigateToTab),
      const UploadScreen(),
      const DownloadScreen(),
      const TransferManagerScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            String username = 'POS Operator';
            if (state is AuthAuthenticated) {
              username = state.authToken.username;
            }
            return Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Store #104 • Online',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          // Transfer Quick Sheet Shortcut
          BlocBuilder<TransferBloc, TransferState>(
            builder: (context, state) {
              final activeCount = state.activeTasks.length;
              return IconButton(
                icon: Badge(
                  isLabelVisible: activeCount > 0,
                  backgroundColor: colorScheme.error,
                  label: Text('$activeCount'),
                  child: Icon(
                    activeCount > 0 ? Icons.sync_rounded : Icons.swap_vert_circle_outlined,
                    color: activeCount > 0 ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
                tooltip: 'Quick Transfers Sheet',
                onPressed: () => PersistentTransferSheet.show(context),
              );
            },
          ),
          // Logout Button
          IconButton(
            icon: Icon(Icons.logout_rounded, color: colorScheme.onSurfaceVariant),
            tooltip: 'Logout',
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          // Global Persistent Transfer Banner visible across all screens
          const PersistentTransferBanner(),
        ],
      ),
      bottomNavigationBar: BlocBuilder<TransferBloc, TransferState>(
        builder: (context, state) {
          final activeCount = state.activeTasks.length;

          return NavigationBar(
            selectedIndex: _currentIndex,
            elevation: 2,
            backgroundColor: colorScheme.surface,
            indicatorColor: colorScheme.primaryContainer,
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
                  label: Text('$activeCount'),
                  child: const Icon(Icons.swap_vert_circle_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: activeCount > 0,
                  label: Text('$activeCount'),
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
    );
  }
}
