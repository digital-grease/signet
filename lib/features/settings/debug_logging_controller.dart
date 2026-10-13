import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/debug_session.dart';
import '../../core/providers.dart';

/// Reactive view of the opt-in debug-logging session, for the Settings screen
/// and the persistent indicator.
///
/// The underlying [DebugSession] state isn't reactive on its own, so this
/// controller re-snapshots it on every mutation. Event counts stream in via
/// the fire-and-forget `DebugLog.log` path and are NOT pushed here — call
/// [refresh] before reading [DebugLoggingState.eventCount] when you need it
/// fresh (e.g. at export time).
class DebugLoggingState {
  const DebugLoggingState({
    required this.active,
    required this.eventCount,
    this.expiresAt,
  });

  final bool active;
  final int eventCount;
  final DateTime? expiresAt;
}

class DebugLoggingController extends Notifier<DebugLoggingState> {
  DebugSession? get _session => ref.read(debugLogProvider).session;

  /// Whether debug logging is wired at all (a session exists). False in the
  /// default provider (tests, early boot) — the Settings section hides itself.
  bool get available => _session != null;

  Timer? _expiryTimer;
  AppLifecycleListener? _lifecycle;

  @override
  DebugLoggingState build() {
    ref.onDispose(() {
      _expiryTimer?.cancel();
      _expiryTimer = null;
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    // The 24-hour erase used to happen only on the next write or launch,
    // so the Home banner and Settings kept saying "recording" after it was
    // due (plan Task 5.3). Check when it falls due and on every return to
    // the foreground.
    _lifecycle ??= AppLifecycleListener(
      onResume: () => unawaited(_expireIfDue()),
    );
    final snapshot = _snapshot();
    _scheduleExpiry(snapshot.expiresAt);
    return snapshot;
  }

  void _scheduleExpiry(DateTime? expiresAt) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (expiresAt == null) return;
    final wait = expiresAt.difference(DateTime.now().toUtc());
    _expiryTimer = Timer(
      wait.isNegative ? Duration.zero : wait + const Duration(seconds: 1),
      () => unawaited(_expireIfDue()),
    );
  }

  Future<void> _expireIfDue() async {
    final session = _session;
    if (session != null && session.isActive) await session.expireIfDue();
    // Re-read even if it was already inactive: a breadcrumb written after
    // the expiry wipes the session on its own, and the state must follow.
    _setState(_snapshot());
  }

  void _setState(DebugLoggingState next) {
    state = next;
    _scheduleExpiry(next.expiresAt);
  }

  DebugLoggingState _snapshot() {
    final s = _session;
    return DebugLoggingState(
      active: s?.isActive ?? false,
      eventCount: s?.eventCount ?? 0,
      expiresAt: s?.expiresAt,
    );
  }

  /// Start a session. Rethrows if it could not be started (the session
  /// rolls itself back), so the caller can tell the user; the state is
  /// re-snapshotted either way so the UI never shows a stale value.
  Future<void> enable() async {
    try {
      await _session?.start();
    } finally {
      _setState(_snapshot());
    }
  }

  Future<void> stop() async {
    try {
      await _session?.stop();
    } finally {
      _setState(_snapshot());
    }
  }

  void refresh() => _setState(_snapshot());
}

final NotifierProvider<DebugLoggingController, DebugLoggingState>
    debugLoggingProvider =
    NotifierProvider<DebugLoggingController, DebugLoggingState>(
  DebugLoggingController.new,
);
