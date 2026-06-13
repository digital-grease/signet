import 'dart:async';

import '../models/relationship.dart';
import 'breadcrumb.dart';
import 'debug_session.dart';

/// The app's single entry point for emitting structural breadcrumbs.
///
/// Every call goes to the always-on in-memory [ring] (which is folded into a
/// crash report if one fires). When a user has an opt-in [session] active, the
/// same breadcrumb is also appended to the encrypted session log.
///
/// The API takes a [BreadcrumbEvent] enum + an optional [Relationship] (logged
/// by opaque id only) + a bounded int — there is deliberately no way to pass a
/// free-form string, a label, or a secret. This is the Phase-8 write-time
/// discipline (spike decision #4) realized as an API shape.
class DebugLog {
  DebugLog({
    BreadcrumbRing? ring,
    this.session,
    DateTime Function()? now,
  })  : ring = ring ?? BreadcrumbRing(),
        _now = now ?? _wallClock {
    _epoch = _now();
  }

  static DateTime _wallClock() => DateTime.now().toUtc();

  /// Always-on, RAM-only breadcrumb buffer. Never persisted on its own.
  final BreadcrumbRing ring;

  /// The active opt-in session, or null. Set once at boot; the session is
  /// started / stopped through its own API by the settings controller.
  DebugSession? session;

  final DateTime Function() _now;
  late final DateTime _epoch;

  /// Emit one structural breadcrumb. Cheap and non-throwing — safe to call
  /// from hot paths and from `build` methods.
  void log(BreadcrumbEvent event, {Relationship? relationship, int? n}) {
    final atMs = _now().difference(_epoch).inMilliseconds;
    final crumb = Breadcrumb.of(
      atMs: atMs,
      event: event,
      relationship: relationship,
      n: n,
    );
    ring.add(crumb);
    final s = session;
    if (s != null && s.isActive) {
      // Fire-and-forget: the session does async encrypt+write; a breadcrumb
      // must never block or throw into the caller.
      unawaited(s.record(crumb));
    }
  }

  /// The current breadcrumb dump, oldest-first. Wired into
  /// `CrashRecorder` so a crash report carries the lead-up.
  String breadcrumbDump() => ring.dump();
}
