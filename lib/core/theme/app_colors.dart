import 'package:flutter/material.dart';

/// Central brand + transfer-status tokens.
/// Wire into [ThemeData] via [AppTheme]; use status colors for transfer UI.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1E88E5);
  static const Color secondary = Color(0xFF546E7A);

  // Surfaces (light reference; Theme still owns light/dark adaptation)
  static const Color surfaceLight = Color(0xFFF7F9FC);
  static const Color surfaceContainerLight = Color(0xFFEEF2F7);
  static const Color outline = Color(0xFFC5CDD8);

  // Transfer status
  static const Color running = primary;
  static const Color paused = Color(0xFFFB8C00);
  static const Color success = Color(0xFF43A047);
  static const Color failed = Color(0xFFE53935);
  static const Color cancelled = Color(0xFF78909C);
  static const Color queued = Color(0xFF607D8B);
}
