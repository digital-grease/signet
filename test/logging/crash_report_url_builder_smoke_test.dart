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

    test('handles empty manufacturer', () {
      expect(
        CrashReportUrlBuilder.formatDevice('', 'Galaxy S24'),
        equals('Galaxy S24'),
      );
    });
  });

  group('CrashReportUrlBuilder.build', () {
    test('short trace returns Embedded', () {
      final result = CrashReportUrlBuilder.build(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.4 (30004)',
        trace: 'FormatException: Unexpected character',
      );
      expect(result, isA<CrashReportUrlEmbedded>());
      expect(result.url, startsWith('https://github.com/digital-grease/signet/issues/new'));
      expect(result.url, contains('template=crash_report.yml'));
      // Uri.encodeQueryComponent uses `+` for spaces (form encoding).
      expect(result.url, contains('device=Pixel+8'));
      expect(result.url, contains('os_version=14'));
      expect(result.url, contains('app_version=0.3.4+%2830004%29'));
    });

    test('oversized trace returns Truncated with full trace', () {
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
      expect(truncated.url.length, lessThanOrEqualTo(CrashReportUrlBuilder.defaultMaxUrlLength));
      expect(
        Uri.decodeQueryComponent(truncated.url.split('&stack_trace=')[1]),
        contains('[…truncated'),
      );
    });

    test('URL stays under budget', () {
      final result = CrashReportUrlBuilder.build(
        device: 'Pixel 8',
        osVersion: '14',
        appVersion: '0.3.4 (30004)',
        trace: 'X' * 8000,
      );
      expect(result.url.length, lessThanOrEqualTo(CrashReportUrlBuilder.defaultMaxUrlLength));
    });

    test('special chars in device name encoded', () {
      final result = CrashReportUrlBuilder.build(
        device: 'Galaxy S24+',
        osVersion: '14',
        appVersion: '0.3.4 (30004)',
        trace: 'short',
      );
      expect(result.url, contains('Galaxy+S24%2B'));
    });
  });
}
