import 'package:flutter/material.dart';

/// Reusable snack-bar helper for user feedback.
///
/// Single method that renders a floating, color-coded snack bar with an icon.
/// Call from any widget that has access to a [ScaffoldMessenger] via context.
///
/// Usage inside a feature page:
/// ```dart
/// AppSnackBar.showSuccess(context, l10n.refreshSuccess);
/// ```
enum AppSnackBarType { success, error, info }

class AppSnackBar {
  const AppSnackBar._();

  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, AppSnackBarType.success);

  static void showError(BuildContext context, String message) =>
      _show(context, message, AppSnackBarType.error);

  static void showInfo(BuildContext context, String message) =>
      _show(context, message, AppSnackBarType.info);

  static void _show(
    BuildContext context,
    String message,
    AppSnackBarType type,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(_build(message, type));
  }

  static SnackBar _build(String message, AppSnackBarType type) {
    late final IconData icon;
    late final Color color;

    if (type == AppSnackBarType.success) {
      icon = Icons.check_circle_outlined;
      color = const Color(0xFF2E7D32);
    }

    if (type == AppSnackBarType.error) {
      icon = Icons.error_outline;
      color = const Color(0xFFC62828);
    } else {
      icon = Icons.info_outline;
      color = const Color(0xFF1565C0);
    }

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        spacing: 12,
        children: [
          Icon(icon, color: Colors.white),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
