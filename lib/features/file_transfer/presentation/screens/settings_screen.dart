import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pos_terminal_banner.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const PosTerminalBanner(
            title: 'System console',
            subtitle: 'Operator session, server link & engine specs',
            icon: Icons.settings_suggest_rounded,
          ),
          const SizedBox(height: 16),
          // Section: Operator Account
          _buildSectionHeader(context, 'POS Operator'),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              String username = 'Operator';
              if (state is AuthAuthenticated) {
                username = state.authToken.username;
              }
              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.person_rounded, color: colorScheme.onPrimaryContainer),
                  ),
                  title: Text(
                    username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Authenticated Operator Session'),
                  trailing: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                    ),
                    onPressed: () {
                      context.read<AuthBloc>().add(const AuthLogoutRequested());
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Sign Out'),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Section: Server Configuration
          _buildSectionHeader(context, 'Server & Network'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.cloud_queue_rounded, color: colorScheme.primary),
                  title: const Text('Backend API URL'),
                  subtitle: const Text(ApiConstants.baseUrl),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Connected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, indent: 56, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ListTile(
                  leading: Icon(Icons.timer_outlined, color: colorScheme.primary),
                  title: const Text('Network Timeouts'),
                  subtitle: const Text('Connect: 30s • Receive: 60s'),
                ),
                Divider(height: 1, indent: 56, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ListTile(
                  leading: Icon(Icons.speed_rounded, color: colorScheme.primary),
                  title: const Text('Notification Throttling'),
                  subtitle: const Text('600ms rate limit to prevent system UI stutter'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Transfer Engine Specs
          _buildSectionHeader(context, 'Engine Resilience'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.refresh_rounded, color: colorScheme.secondary),
                  title: const Text('Interrupted Task Recovery'),
                  subtitle: const Text('Auto-restores running/paused tasks on application relaunch'),
                ),
                Divider(height: 1, indent: 56, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ListTile(
                  leading: Icon(Icons.downloading_rounded, color: colorScheme.secondary),
                  title: const Text('Download Resumption'),
                  subtitle: const Text('HTTP Range 206 Partial Content enabled'),
                ),
                Divider(height: 1, indent: 56, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ListTile(
                  leading: Icon(Icons.upload_rounded, color: colorScheme.secondary),
                  title: const Text('Multipart Upload Engine'),
                  subtitle: const Text('Streamed multipart/form-data with chunked validation'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Application Version
          Center(
            child: Text(
              'POS Background Transfer SaaS v1.0.0+1\nClean Architecture • Production Ready',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.posInk,
        ),
      ),
    );
  }
}
