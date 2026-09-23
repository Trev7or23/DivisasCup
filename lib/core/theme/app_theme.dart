import 'package:flutter/material.dart';

/// Material 3 theme seeded from a single brand color.
/// Both light and dark schemes are derived with `ColorScheme.fromSeed` so
/// surfaces, primary/secondary and containers stay coherent automatically.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF0B7A6A);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}