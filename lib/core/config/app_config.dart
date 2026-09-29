import 'package:flutter/foundation.dart' show visibleForTesting;

import '../errors/failure.dart';

/// Build-time configuration, read from `--dart-define-from-file=.env`.
///
/// The values are compiled into the binary as [String.fromEnvironment]
/// constants: resolved once at compile time, never read from a file at
/// runtime and never fetched over the network.
class AppConfig {
  const AppConfig._({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  /// Base URL of the Supabase project (`http://…:54321` for the local stack,
  /// `https://<ref>.supabase.co` for a cloud project).
  final String supabaseUrl;

  /// `sb_publishable_…` key. Designed to ship: RLS decides what it can reach.
  final String supabasePublishableKey;

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Reads the compiled-in values and validates them.
  factory AppConfig.fromEnvironment() =>
      AppConfig.validate(url: _envUrl, publishableKey: _envKey);

  /// Kept separate from [String.fromEnvironment] so it stays testable: a
  /// compile-time constant cannot be mocked.
  @visibleForTesting
  factory AppConfig.validate({
    required String url,
    required String publishableKey,
  }) {
    final trimmedUrl = url.trim();
    final trimmedKey = publishableKey.trim();

    if (trimmedUrl.isEmpty || trimmedKey.isEmpty) {
      throw const ConfigFailure(
        'Missing Supabase build config: copy .env.example to .env, fill in '
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, and pass it with '
        '--dart-define-from-file=.env',
      );
    }
    if (!trimmedUrl.startsWith('http://') &&
        !trimmedUrl.startsWith('https://')) {
      throw ConfigFailure(
        'SUPABASE_URL must start with http:// or https:// (got "$trimmedUrl")',
      );
    }
    if (_looksLikeSecretKey(trimmedKey)) {
      throw const ConfigFailure(
        'Refusing to start: SUPABASE_PUBLISHABLE_KEY holds a SECRET '
        '(service_role) key. It bypasses Row Level Security and is readable '
        'by anyone who unzips the app. Use the publishable key instead.',
      );
    }

    return AppConfig._(
      supabaseUrl: trimmedUrl,
      supabasePublishableKey: trimmedKey,
    );
  }

  /// `sb_secret_…` is the current secret-key prefix; a long `eyJ…` string is a
  /// legacy `service_role` JWT. Neither may ever reach a client build, and
  /// pasting the wrong one into `.env` is an easy mistake to make.
  static bool _looksLikeSecretKey(String key) =>
      key.startsWith('sb_secret_') ||
      (key.startsWith('eyJ') && key.length > 100);
}
