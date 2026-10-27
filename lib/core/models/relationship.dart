import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../crypto/pair_role.dart';
import '../crypto/wordlists.dart';

/// A paired contact. Holds only non-secret metadata — the shared secret
/// never lives on this model and is stored separately in the secure enclave.
///
/// The [role] field binds the rotating verify code to a direction so a
/// reflection attack (caller parrots the verifier's own words back at
/// her) fails — see `TotpWords` docs for the full derivation story.
@immutable
class Relationship {
  const Relationship({
    required this.id,
    required this.label,
    required this.pairedAt,
    required this.role,
    this.silentHaptics = false,
    this.wordLanguage = defaultWordLanguage,
    this.wordLanguageChangedAt,
  });

  factory Relationship.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final roleWire = map['role'];
    if (roleWire is! String) {
      throw const FormatException(
        'Relationship JSON is missing "role" — likely from a pre-Phase-8 '
        'build. The app will wipe this pairing and ask the user to repair.',
      );
    }
    // silentHaptics was added in Phase 9.6; legacy blobs without it default
    // to false (= haptics on, which is the grandma-test default). This is
    // an additive migration — no blob is invalidated.
    final silent = map['silentHaptics'] as bool?;
    // wordLanguage was added in v0.5.0; every contact saved before it was
    // English. Any string is kept as it is, even one this version does
    // not know, so it survives a re-export (see [knownWordList]).
    final language = map['wordLanguage'];
    final changedAtMs = map['wordLanguageChangedAtMs'];
    return Relationship(
      id: map['id']! as String,
      label: map['label']! as String,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(
        map['pairedAtMs']! as int,
        isUtc: true,
      ),
      role: PairRole.fromWireName(roleWire),
      silentHaptics: silent ?? false,
      wordLanguage: language is String ? language : defaultWordLanguage,
      wordLanguageChangedAt: changedAtMs is int
          ? DateTime.fromMillisecondsSinceEpoch(changedAtMs, isUtc: true)
          : null,
    );
  }

  /// Mint a new Relationship at the current instant.
  factory Relationship.fresh({
    required String label,
    required PairRole role,
    bool silentHaptics = false,
    String wordLanguage = defaultWordLanguage,
    DateTime? now,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final when = now ?? DateTime.now().toUtc();
    return Relationship(
      id: id,
      label: label,
      pairedAt: when.toUtc(),
      role: role,
      silentHaptics: silentHaptics,
      wordLanguage: wordLanguage,
    );
  }

  /// The word language of contacts saved before v0.5.0, and of restored
  /// backups that do not say: English ([WordList.english]).
  static const String defaultWordLanguage = 'en';

  final String id;
  final String label;
  final DateTime pairedAt;
  final PairRole role;

  /// When `true`, the Verify screen suppresses HapticFeedback on both ✅
  /// and ❌ outcomes. A buzzing phone is an observable tell in coercive /
  /// surveillance scenarios; silent mode is meant for the journalist +
  /// activist audience. Default `false` (haptics on) — grandma test wins.
  final bool silentHaptics;

  /// The registered word-list id this pair agreed on ([WordList.id]):
  /// `en`, `fr`, or an id from a newer Signet, kept as it came so a backup
  /// made here carries it on. Backups carry it as transport-package
  /// extension `0x01`.
  final String wordLanguage;

  /// When [wordLanguage] was last changed for an existing contact, shown
  /// on the contact so a change a caller talked the user into leaves a
  /// trace. Null when it never changed since pairing.
  final DateTime? wordLanguageChangedAt;

  /// The [wordLanguage] of a contact restored from a backup whose language
  /// tag was damaged (`TransportPackage.damagedWordListId`, the same
  /// value): it breaks the id grammar, so no list can ever have it.
  static const String damagedWordLanguage = '!';

  /// Whether [wordLanguage] came from a damaged backup tag: no update will
  /// make its words showable.
  bool get wordLanguageDamaged => wordLanguage == damagedWordLanguage;

  /// The list [wordLanguage] names, or null when this version of Signet
  /// does not have it. Word surfaces then ask the user to update Signet
  /// instead of showing words: English words would fail against the real
  /// contact.
  WordList? get knownWordList => WordList.byId(wordLanguage);

  /// The list this contact's words are spelled in: the rotating words, the
  /// challenge grid, the binding phrase and the backup's PAKE words. Every
  /// word surface for a contact reads it here. English when
  /// [knownWordList] is null; surfaces that show words check that first.
  WordList get wordList => knownWordList ?? WordList.english;

  Relationship copyWith({
    String? id,
    String? label,
    DateTime? pairedAt,
    PairRole? role,
    bool? silentHaptics,
    String? wordLanguage,
    DateTime? wordLanguageChangedAt,
  }) {
    return Relationship(
      id: id ?? this.id,
      label: label ?? this.label,
      pairedAt: pairedAt ?? this.pairedAt,
      role: role ?? this.role,
      silentHaptics: silentHaptics ?? this.silentHaptics,
      wordLanguage: wordLanguage ?? this.wordLanguage,
      wordLanguageChangedAt:
          wordLanguageChangedAt ?? this.wordLanguageChangedAt,
    );
  }

  String toJson() => jsonEncode(<String, dynamic>{
        'id': id,
        'label': label,
        'pairedAtMs': pairedAt.toUtc().millisecondsSinceEpoch,
        'role': role.wireName,
        'silentHaptics': silentHaptics,
        'wordLanguage': wordLanguage,
        if (wordLanguageChangedAt != null)
          'wordLanguageChangedAtMs':
              wordLanguageChangedAt!.toUtc().millisecondsSinceEpoch,
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Relationship &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          pairedAt.isAtSameMomentAs(other.pairedAt) &&
          role == other.role &&
          silentHaptics == other.silentHaptics &&
          wordLanguage == other.wordLanguage &&
          _sameMoment(wordLanguageChangedAt, other.wordLanguageChangedAt);

  static bool _sameMoment(DateTime? a, DateTime? b) =>
      a == null ? b == null : b != null && a.isAtSameMomentAs(b);

  @override
  int get hashCode => Object.hash(id, label, pairedAt.toUtc(), role,
      silentHaptics, wordLanguage, wordLanguageChangedAt?.toUtc());

  // The label is the human-identifying field on this model ("Mom", "Source A").
  // Per the Phase 7 leak-prevention audit it stays out of toString so the
  // primary code-side defense holds even if a Relationship slips into a crash
  // report. `leak_prevention_test.dart` enforces this invariant.
  @override
  String toString() =>
      'Relationship(id: $id, label: [redacted], role: ${role.wireName}, '
      'pairedAt: ${pairedAt.toIso8601String()}, '
      'silentHaptics: $silentHaptics, wordLanguage: $wordLanguage)';
}
