import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_event.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_state.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_state.dart';
import '../widgets/persistent_transfer_banner.dart';
import '../widgets/persistent_transfer_sheet.dart';
import 'download_screen.dart';
import 'upload_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    UploadScreen(),
    DownloadScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                const Icon(Icons.storefront_rounded, size: 22),
                const SizedBox(width: 8),
                Text(
                  username,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            );
          },
        ),
        actions: [
          // Transfer Dashboard Shortcut
          BlocBuilder<TransferBloc, TransferState>(
            builder: (context, state) {
              final count = state.activeTasks.length;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.sync_rounded),
                ),
                tooltip: 'Transfer Dashboard',
                onPressed: () => PersistentTransferSheet.show(context),
              );
            },
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout_rounded),
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
            children: _screens,
          ),
          // Global Persistent Transfer Banner
          const PersistentTransferBanner(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_upload_outlined),
            selectedIcon: Icon(Icons.cloud_upload),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_download_outlined),
            selectedIcon: Icon(Icons.cloud_download),
            label: 'Downloads',
          ),
        ],
      ),
    );
  }
}
