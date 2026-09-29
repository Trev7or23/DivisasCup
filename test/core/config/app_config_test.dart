import 'package:divisas_cup/core/config/app_config.dart';
import 'package:divisas_cup/core/errors/failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.validate', () {
    test('accepts a local stack URL and a publishable key', () {
      final config = AppConfig.validate(
        url: 'http://10.0.2.2:54321',
        publishableKey: 'sb_publishable_abcdef',
      );

      expect(config.supabaseUrl, 'http://10.0.2.2:54321');
      expect(config.supabasePublishableKey, 'sb_publishable_abcdef');
    });

    test('trims surrounding whitespace from both values', () {
      final config = AppConfig.validate(
        url: '  https://abc.supabase.co  ',
        publishableKey: '  sb_publishable_xyz  ',
      );

      expect(config.supabaseUrl, 'https://abc.supabase.co');
      expect(config.supabasePublishableKey, 'sb_publishable_xyz');
    });

    test('fails when the URL is missing', () {
      expect(
        () => AppConfig.validate(url: '', publishableKey: 'sb_publishable_a'),
        throwsA(isA<ConfigFailure>()),
      );
    });

    test('fails when the key is blank', () {
      expect(
        () => AppConfig.validate(
          url: 'http://127.0.0.1:54321',
          publishableKey: '   ',
        ),
        throwsA(isA<ConfigFailure>()),
      );
    });

    test('fails when the URL has no http scheme', () {
      expect(
        () => AppConfig.validate(
          url: '10.0.2.2:54321',
          publishableKey: 'sb_publishable_a',
        ),
        throwsA(isA<ConfigFailure>()),
      );
    });

    test('refuses an sb_secret_ key', () {
      expect(
        () => AppConfig.validate(
          url: 'http://127.0.0.1:54321',
          publishableKey: 'sb_secret_aaaaaaaaaaaa',
        ),
        throwsA(
          isA<ConfigFailure>().having(
            (f) => f.message,
            'message',
            contains('SECRET'),
          ),
        ),
      );
    });

    test('refuses a legacy service_role JWT', () {
      final legacyJwt = 'eyJ${List.filled(200, 'A').join()}';
      expect(
        () => AppConfig.validate(
          url: 'http://127.0.0.1:54321',
          publishableKey: legacyJwt,
        ),
        throwsA(isA<ConfigFailure>()),
      );
    });
  });
}
