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

  @override
  DebugLoggingState build() => _snapshot();

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
      state = _snapshot();
    }
  }

  Future<void> stop() async {
    try {
      await _session?.stop();
    } finally {
      state = _snapshot();
    }
  }

  void refresh() => state = _snapshot();
}

final NotifierProvider<DebugLoggingController, DebugLoggingState>
    debugLoggingProvider =
    NotifierProvider<DebugLoggingController, DebugLoggingState>(
  DebugLoggingController.new,
);
