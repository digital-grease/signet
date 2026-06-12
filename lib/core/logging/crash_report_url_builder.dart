/// Builds a pre-filled GitHub Issue Form URL for `.github/ISSUE_TEMPLATE/crash_report.yml`
/// so a user tapping "File a GitHub Issue" in the app lands on a form that's
/// already 80% complete.
///
/// The form's field IDs (`device`, `os_version`, `app_version`, `stack_trace`)
/// line up with the URL query parameters here — GitHub renders each pre-filled
/// value into the corresponding field on load. The `description` field is left
/// blank for the user to fill themselves.
///
/// Pure Dart: no Flutter dependencies. Tests can call directly.
///
/// Ported from fauxx's `CrashReportUrlBuilder.kt` (~110 LOC Kotlin) with two
/// Signet-specific adaptations:
///   - No `flavor` field (Signet is single-flavor; fauxx has Full/Play).
///   - Renamed `android_version` → `os_version` to keep the form cross-platform.
class CrashReportUrlBuilder {
  const CrashReportUrlBuilder._();

  static const String _issuesNewBase =
      'https://github.com/digital-grease/signet/issues/new';

  /// Default issue template + body field (the crash path). The Phase-8
  /// debug-log path overrides these via [build]'s named params, or uses the
  /// [buildDebugLog] convenience wrapper.
  static const String _defaultTemplate = 'crash_report.yml';
  static const String _defaultBodyField = 'stack_trace';

  /// Conservative max URL length before GitHub starts 500-ing on long body
  /// params. Verified empirically on fauxx in 2024-Q4; re-verify pre-ship via
  /// a 7500-char test URL per the spike sign-off table.
  static const int defaultMaxUrlLength = 7000;

  /// Raw character budget for the head of a truncated trace. URL encoding
  /// inflates ~2.5×, so 2000 raw chars × 2.5 = ~5000 encoded chars, comfortably
  /// inside the budget after the short fields take their share.
  static const int truncatedHeadChars = 2000;

  static const String _truncationMarker =
      '\n\n[…truncated — full trace copied to clipboard, paste below]';

  /// Format `Build.MANUFACTURER + " " + Build.MODEL` with prefix dedup so
  /// "Google Pixel 7 Pro" stays clean and "samsung Galaxy S24" doesn't become
  /// "samsung samsung Galaxy S24". Capitalizes the manufacturer for readability
  /// since some platforms report it lowercase.
  static String formatDevice(String manufacturer, String model) {
    final mfg = manufacturer.trim();
    final mdl = model.trim();
    if (mfg.isEmpty) return mdl;
    if (mdl.isEmpty) return _capitalize(mfg);
    if (mdl.toLowerCase().startsWith(mfg.toLowerCase())) return mdl;
    return '${_capitalize(mfg)} $mdl';
  }

  /// Build the issue-form URL. Returns [CrashReportUrlEmbedded] when the full
  /// trace fits within the URL budget, or [CrashReportUrlTruncated] when the
  /// head is embedded and the full content must be supplied via clipboard.
  static CrashReportUrl build({
    required String device,
    required String osVersion,
    required String appVersion,
    required String trace,
    String template = _defaultTemplate,
    String bodyField = _defaultBodyField,
    int maxUrlLength = defaultMaxUrlLength,
  }) {
    final shortFieldsUrl = '$_issuesNewBase?template=${_enc(template)}'
        '&device=${_enc(device)}'
        '&os_version=${_enc(osVersion)}'
        '&app_version=${_enc(appVersion)}';

    final traceParamOverhead = '&$bodyField='.length;
    final remaining = maxUrlLength - shortFieldsUrl.length - traceParamOverhead;

    final encodedFullTrace = _enc(trace);
    if (encodedFullTrace.length <= remaining) {
      return CrashReportUrlEmbedded(
        '$shortFieldsUrl&$bodyField=$encodedFullTrace',
      );
    }

    // Truncate the raw trace, append the marker, encode, and verify it fits.
    // Work in raw chars (truncatedHeadChars) rather than encoded chars so the
    // truncation point is predictable for users — the visible content is the
    // first N chars of their trace.
    final headRaw = _take(trace, truncatedHeadChars) + _truncationMarker;
    final encodedHead = _enc(headRaw);

    // Defensive: if even the head + marker overflows the budget (unlikely
    // with 2000 raw chars), shrink further by ~25% rather than producing an
    // oversize URL.
    final String finalHead;
    if (encodedHead.length <= remaining) {
      finalHead = encodedHead;
    } else {
      const safeRawLen = (truncatedHeadChars * 3) ~/ 4;
      finalHead = _enc(_take(trace, safeRawLen) + _truncationMarker);
    }
    return CrashReportUrlTruncated(
      url: '$shortFieldsUrl&$bodyField=$finalHead',
      fullTrace: trace,
    );
  }

  /// Convenience wrapper for the Phase-8 debug-log export path — pre-fills the
  /// `debug_report.yml` form's `debug_log` field. Identical budget / truncation
  /// / clipboard-fallback behavior as [build]; only the template and body-field
  /// id differ.
  static CrashReportUrl buildDebugLog({
    required String device,
    required String osVersion,
    required String appVersion,
    required String log,
    int maxUrlLength = defaultMaxUrlLength,
  }) =>
      build(
        device: device,
        osVersion: osVersion,
        appVersion: appVersion,
        trace: log,
        template: 'debug_report.yml',
        bodyField: 'debug_log',
        maxUrlLength: maxUrlLength,
      );

  static String _enc(String value) => Uri.encodeQueryComponent(value);

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.substring(0, 1).toUpperCase() + s.substring(1);
  }

  static String _take(String s, int n) =>
      s.length <= n ? s : s.substring(0, n);
}

/// Result of [CrashReportUrlBuilder.build] — either the full trace was
/// embedded in the URL, or the head was embedded and the caller must hand
/// the full trace off via clipboard so the user can paste it below the
/// truncated head.
sealed class CrashReportUrl {
  const CrashReportUrl();
  String get url;
}

/// Full trace fit in the URL — no clipboard step needed.
final class CrashReportUrlEmbedded extends CrashReportUrl {
  const CrashReportUrlEmbedded(this.url);
  @override
  final String url;
}

/// Head embedded; the dialog should copy [fullTrace] to clipboard and tell
/// the user to paste below the truncation marker.
final class CrashReportUrlTruncated extends CrashReportUrl {
  const CrashReportUrlTruncated({required this.url, required this.fullTrace});
  @override
  final String url;
  final String fullTrace;
}
