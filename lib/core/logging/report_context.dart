import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device / OS / app-version strings for pre-filling a GitHub issue form.
/// Mirrors the fields the crash flow gathers, minus the Dart version.
class ReportContext {
  const ReportContext({
    required this.device,
    required this.osVersion,
    required this.appVersion,
  });

  final String device;
  final String osVersion;
  final String appVersion;
}

/// Best-effort platform probe — any failing plugin leaves its field as
/// `"unknown"` rather than throwing into the caller.
Future<ReportContext> gatherReportContext() async {
  var appVersion = 'unknown';
  try {
    final info = await PackageInfo.fromPlatform();
    appVersion = '${info.version} (${info.buildNumber})';
  } on Object {
    // leave default
  }

  var osVersion = 'unknown';
  var device = 'unknown';
  try {
    final di = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await di.androidInfo;
      osVersion = a.version.release;
      device = '${a.manufacturer} ${a.model}';
    } else if (Platform.isIOS) {
      final i = await di.iosInfo;
      osVersion = i.systemVersion;
      device = '${i.utsname.machine} (${i.model})';
    }
  } on Object {
    // leave defaults
  }

  return ReportContext(
    device: device,
    osVersion: osVersion,
    appVersion: appVersion,
  );
}
