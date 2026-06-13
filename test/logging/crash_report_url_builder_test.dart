// Comprehensive test corpus for CrashReportUrlBuilder. Ports the fauxx
// `CrashReportUrlBuilderTest.kt` cases, adapted to Signet's Flutter form
// (no flavor field, os_version instead of android_version).

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/logging/crash_report_url_builder.dart';

void main() {
  group('CrashReportUrlBuilder.formatDevice', () {
    test('capitalizes lowercase manufacturer', () {
      expect(
        CrashReportUrlBuilder.formatDevice('samsung', 'Galaxy S24'),
        equals('Samsung Galaxy S24'),
      );
    });

    test('drops duplicate manufacturer prefix', () {
      expect(
        CrashReportUrlBuilder.formatDevice('Google', 'Google Pixel 7 Pro'),
        equals('Google Pixel 7 Pro'),
      );
    });

    test('drops duplicate manufacturer prefix case-insensitively', () {
      expect(
        CrashReportUrlBuilder.formatDevice('SAMSUNG', 'Samsung Galaxy S24'),
        equals('Samsung Galaxy S24'),
      );
    });

    test('handles empty manufacturer', () {
      expect(
        CrashReportUrlBuilder.formatDevice('', 'Galaxy S24'),
        equals('Galaxy S24'),
      );
    });

    test('handles empty model', () {
      expect(
        CrashReportUrlBuilder.formatDevice('samsung', ''),
        equals('Samsung'),
      );
    });

    test('trims whitespace around inputs', () {
      expect(
        CrashReportUrlBuilder.formatDevice('  samsung  ', '  Galaxy S24  '),
        equals('Samsung Galaxy S24'),
      );
    });
  });

  group('CrashReportUrlBuilder.build — embedded path', () {
    test('short trace returns Embedded', () {
      final result = CrashReportUrlBuilder.build(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.4 (30004)',
        trace: 'FormatException: Unexpected character',
      );
      expect(result, isA<CrashReportUrlEmbedded>());
      expect(
        result.url,
        startsWith('https://github.com/digital-grease/signet/issues/new'),
      );
      expect(result.url, contains('template=crash_report.yml'));
    });

    test('decoded form field values round-trip exactly', () {
      final result = CrashReportUrlBuilder.build(
        device: 'Galaxy S24+',
        osVersion: '14',
        appVersion: '0.3.4 (30004)',
        trace: 'FormatException: Unexpected character',
      );
      final params = Uri.parse(result.url).queryParameters;
      expect(params['device'], equals('Galaxy S24+'));
      expect(params['os_version'], equals('14'));
      expect(params['app_version'], equals('0.3.4 (30004)'));
      expect(params['stack_trace'],
          equals('FormatException: Unexpected character'));
      expect(params['template'], equals('crash_report.yml'));
    });

    test('special chars in device name URL-encoded', () {
      final result = CrashReportUrlBuilder.build(
        device: 'Pixel 7 Pro & co.',
        osVersion: '14',
        appVersion: '0.3.4',
        trace: 'short',
      );
      // Decoded form should match the input.
      final device = Uri.parse(result.url).queryParameters['device'];
      expect(device, equals('Pixel 7 Pro & co.'));
    });

    test('Unicode in device name survives round-trip', () {
      final result = CrashReportUrlBuilder.build(
        device: '小米 Mi 11',
        osVersion: '13',
        appVersion: '0.3.4',
        trace: 'short',
      );
      final device = Uri.parse(result.url).queryParameters['device'];
      expect(device, equals('小米 Mi 11'));
    });
  });

  group('CrashReportUrlBuilder.build — truncation path', () {
    test('oversized trace returns Truncated with full trace preserved', () {
      final hugeTrace = 'A' * 10000;
      final result = CrashReportUrlBuilder.build(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.4 (30004)',
        trace: hugeTrace,
      );
      expect(result, isA<CrashReportUrlTruncated>());
      final truncated = result as CrashReportUrlTruncated;
      expect(truncated.fullTrace, equals(hugeTrace));
    });

    test('truncated URL stays at or under default max length', () {
      final result = CrashReportUrlBuilder.build(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.4 (30004)',
        trace: 'A' * 10000,
      );
      expect(
        result.url.length,
        lessThanOrEqualTo(CrashReportUrlBuilder.defaultMaxUrlLength),
      );
    });

    test('truncation marker present and intact in truncated output', () {
      final result = CrashReportUrlBuilder.build(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.4',
        trace: 'X' * 10000,
      );
      final stackTrace =
          Uri.parse(result.url).queryParameters['stack_trace']!;
      expect(stackTrace, contains('[…truncated'));
      expect(stackTrace, contains('paste below'));
    });

    test('embedded head is exactly the first N raw chars + marker', () {
      // Build a trace where the truncation point is observable: first
      // 2000 chars are 'X', the rest are 'Y'. The embedded head should
      // contain only 'X' chars before the truncation marker.
      final trace = 'X' * 2000 + 'Y' * 5000;
      final result = CrashReportUrlBuilder.build(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.4',
        trace: trace,
      );
      expect(result, isA<CrashReportUrlTruncated>());
      final stackTrace =
          Uri.parse(result.url).queryParameters['stack_trace']!;
      // Marker is `\n\n[…truncated ...`; pre-marker is the raw 2000 'X' chars.
      final markerIdx = stackTrace.indexOf('\n\n[…truncated');
      final preMarker = stackTrace.substring(0, markerIdx);
      expect(preMarker.length, equals(2000));
      expect(preMarker, equals('X' * 2000));
    });

    test('defensive 75% shrink fires under a tight maxUrlLength budget', () {
      // Force the URL budget to be just below what a 2000-char head needs
      // post-encoding. This forces the "defensive shrink to 1500" path.
      // Short fields + the head would otherwise overflow.
      final trace = 'A' * 8000;
      const shortFieldsUrlLen =
          'https://github.com/digital-grease/signet/issues/new'
                  '?template=crash_report.yml'
                  '&device=X&os_version=1&app_version=1'
                  .length +
              '&stack_trace='.length;
      // Pick a budget just below `shortFieldsUrlLen + 2000_chars`. The
      // 2000-char head would push us over, so the builder should shrink.
      const budget = shortFieldsUrlLen + 1700; // < 2000 + overhead
      final result = CrashReportUrlBuilder.build(
        device: 'X',
        osVersion: '1',
        appVersion: '1',
        trace: trace,
        maxUrlLength: budget,
      );
      expect(result, isA<CrashReportUrlTruncated>());
      expect(result.url.length, lessThanOrEqualTo(budget));
    });

    test('boundary: trace exactly at budget returns Embedded', () {
      // Build a trace whose encoded length is exactly the remaining budget.
      // Use safe chars (no % encoding) so 1 char = 1 encoded char.
      final trace = 'A' *
          (CrashReportUrlBuilder.defaultMaxUrlLength -
              'https://github.com/digital-grease/signet/issues/new'
                  '?template=crash_report.yml'
                  '&device=Pixel+8&os_version=14&app_version=0.3.4'
                  .length -
              '&stack_trace='.length);
      final result = CrashReportUrlBuilder.build(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.4',
        trace: trace,
      );
      expect(result, isA<CrashReportUrlEmbedded>());
    });
  });

  group('CrashReportUrlBuilder.buildDebugLog — Phase 8 debug path', () {
    test('targets debug_report.yml with a debug_log body field', () {
      final result = CrashReportUrlBuilder.buildDebugLog(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.6 (30006)',
        log: '+0ms app.start\n+12ms verify.result.fail ref=<peer-1>',
      );
      final params = Uri.parse(result.url).queryParameters;
      expect(params['template'], equals('debug_report.yml'));
      expect(params['debug_log'], contains('verify.result.fail'));
      expect(params.containsKey('stack_trace'), isFalse);
      expect(params['device'], equals('Pixel 8'));
      expect(params['app_version'], equals('0.3.6 (30006)'));
    });

    test('long log truncates with full log preserved for clipboard', () {
      final result = CrashReportUrlBuilder.buildDebugLog(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.6',
        log: 'L' * 10000,
      );
      expect(result, isA<CrashReportUrlTruncated>());
      expect((result as CrashReportUrlTruncated).fullTrace.length, 10000);
      expect(result.url.length,
          lessThanOrEqualTo(CrashReportUrlBuilder.defaultMaxUrlLength));
    });

    test('crash path still defaults to crash_report.yml + stack_trace', () {
      final result = CrashReportUrlBuilder.build(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.6',
        trace: 'short',
      );
      final params = Uri.parse(result.url).queryParameters;
      expect(params['template'], equals('crash_report.yml'));
      expect(params['stack_trace'], equals('short'));
      expect(params.containsKey('debug_log'), isFalse);
    });
  });
}
