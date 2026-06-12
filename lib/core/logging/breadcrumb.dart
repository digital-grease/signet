import '../models/relationship.dart';

/// Structural app-behavior events for the in-memory breadcrumb ring and the
/// opt-in debug session.
///
/// Enumerated (not free-form) **by design**: a fixed wire constant per event
/// means a careless caller can't interpolate a secret or a contact label into
/// a log line. A relationship is referenced only by its opaque id (via
/// [Breadcrumb.of]'s `relationship` argument), never by label. Together these
/// are the Phase-8 "write-time discipline" (spike decision #4).
enum BreadcrumbEvent {
  appStart('app.start'),
  appResumed('app.resumed'),
  navTo('nav.to'),
  verifyOpen('verify.open'),
  verifyStart('verify.start'),
  verifyWindowWalk('verify.window_walk'),
  verifyResultPass('verify.result.pass'),
  verifyResultFail('verify.result.fail'),
  pairingStart('pairing.start'),
  pairingQrScanned('pairing.qr_scanned'),
  pairingDeriveStart('pairing.derive.start'),
  pairingCommit('pairing.commit'),
  backupExportStart('backup.export.start'),
  backupImportStart('backup.import.start'),
  storeRead('store.read'),
  storeWrite('store.write'),
  storeMigrate('store.migrate'),
  livenessWindow('liveness.window'),
  debugSessionStart('debug.session.start');

  const BreadcrumbEvent(this.wire);

  /// Short, stable token written to logs. Constant by construction — carries
  /// no user data.
  final String wire;
}

/// One structural breadcrumb. Holds no payloads: a relationship appears only as
/// its opaque id, and the only free value is a bounded int [n].
class Breadcrumb {
  const Breadcrumb({
    required this.atMs,
    required this.event,
    this.ref,
    this.n,
  });

  /// Build a breadcrumb that references [relationship] by its opaque id only.
  /// There is deliberately no path that accepts a label.
  factory Breadcrumb.of({
    required int atMs,
    required BreadcrumbEvent event,
    Relationship? relationship,
    int? n,
  }) =>
      Breadcrumb(atMs: atMs, event: event, ref: relationship?.id, n: n);

  /// Milliseconds since the ring's epoch (app or session start) — a relative
  /// offset, never a wall-clock timestamp.
  final int atMs;
  final BreadcrumbEvent event;

  /// Opaque relationship id, or null. NEVER a label.
  final String? ref;

  /// Bounded integer detail (e.g. window-walk count), or null.
  final int? n;

  String format() {
    final b = StringBuffer('+${atMs}ms ${event.wire}');
    if (ref != null) b.write(' ref=$ref');
    if (n != null) b.write(' n=$n');
    return b.toString();
  }

  @override
  String toString() => format();
}

/// Fixed-capacity, in-memory ring of [Breadcrumb]s.
///
/// Never persisted on its own; its [dump] is folded into the crash report
/// (beneath the scrubbed trace) and streamed into an active debug session.
/// Oldest-first eviction past [capacity]. Not thread-safe by design — Flutter
/// is single-isolate for UI work.
class BreadcrumbRing {
  BreadcrumbRing({this.capacity = 200}) : assert(capacity > 0);

  final int capacity;
  final List<Breadcrumb> _items = <Breadcrumb>[];

  void add(Breadcrumb crumb) {
    _items.add(crumb);
    if (_items.length > capacity) {
      _items.removeRange(0, _items.length - capacity);
    }
  }

  int get length => _items.length;

  List<Breadcrumb> snapshot() => List<Breadcrumb>.unmodifiable(_items);

  /// Newline-joined breadcrumb lines, oldest first. Empty string when empty.
  String dump() => _items.map((c) => c.format()).join('\n');

  void clear() => _items.clear();
}
