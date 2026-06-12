/// Policy for user-chosen relationship labels (Phase-8 decision #17).
///
/// Rejects labels that would defeat the debug-log export scrubber's correlation
/// guarantee: a label that is itself secret-shaped — a `signet:tp1:` wire
/// fragment, or a pure ≥16-char hex string — would be caught by the export
/// scrubber's secret-scrub pass and redacted to `[redacted:N]` instead of
/// mapped to a stable `<peer-N>` token. That never *leaks* the name, but it
/// loses correlation. Rejecting such labels at input keeps every label on the
/// pseudonymization path.
///
/// This is a thin, UI-facing validator. It is deliberately NOT enforced inside
/// `Relationship.fresh`, because that factory is also used to mint throwaway
/// ids (see `bulk_backup_import_screen`) and to rehydrate restored
/// relationships, neither of which should be policed here.
class LabelPolicy {
  const LabelPolicy._();

  static final RegExp _pureHex16Plus = RegExp(r'^[0-9a-fA-F]{16,}$');

  /// Returns a short, user-facing rejection reason, or null if [label] is
  /// allowed. Trims surrounding whitespace before checking.
  static String? rejectionReason(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return 'Enter a name for this contact.';
    }
    if (trimmed.toLowerCase().contains('signet:tp1:')) {
      return 'That looks like Signet data, not a name. Try something like "Mom".';
    }
    if (_pureHex16Plus.hasMatch(trimmed)) {
      return 'That looks like a key, not a name. Try something like "Mom".';
    }
    return null;
  }

  /// Whether [label] is allowed as a relationship label.
  static bool isValid(String label) => rejectionReason(label) == null;
}
