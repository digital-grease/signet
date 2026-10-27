// A contact's word language on every surface (v0.5.0 plan Task 1.3, and
// the Task 1.2 review: until a contact could be French, deleting any
// `list: relationship.wordList` passed every test). One French contact:
// verify, show my words, grid, binding phrase and backup all speak French;
// a language this version lacks asks for an update instead of showing
// words; backups carry the language and restores keep it.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/challenge_response_grid.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/crypto/verification.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/inspect/backup_export_screen.dart';
import 'package:signet/features/inspect/backup_import_screen.dart';
import 'package:signet/features/inspect/binding_phrase_screen.dart';
import 'package:signet/features/inspect/bulk_backup_import_screen.dart';
import 'package:signet/features/inspect/cr_grid_screen.dart';
import 'package:signet/features/verify/verify_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';

const _t = 1735776000;
final _secret = List<int>.generate(32, (i) => i * 3 + 1);
final _mom = Relationship(
  id: 'abcdef0011223344',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 2, 14),
  role: PairRole.a,
  wordLanguage: 'fr',
);
final _french = WordList.french;

Widget _app(FakeSecureStore store, String path, Widget screen) {
  final router = GoRouter(
    initialLocation: path,
    routes: <RouteBase>[
      GoRoute(path: path, builder: (_, _) => screen),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [secureStoreProvider.overrideWithValue(store)],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: signetTheme(dark: false),
      routerConfig: router,
    ),
  );
}

Widget _verify(FakeSecureStore store) => _app(
      store,
      '/verify/x',
      VerifyScreen(
        relationshipId: _mom.id,
        unixTimeSecondsProvider: () => _t,
      ),
    );

Future<void> _type(WidgetTester tester, List<String> words) async {
  for (var i = 0; i < words.length; i++) {
    await tester.enterText(find.byType(TextField).at(i), words[i]);
    await tester.pumpAndSettle();
  }
}

/// Words that are French and not also spelled the same in English, so a
/// test cannot pass by reading them as English.
bool _onlyFrench(List<String> words) =>
    words.every((w) => !WordList.english.contains(w));

void main() {
  late FakeSecureStore store;
  setUp(() => store = FakeSecureStore(seeded: _mom, secret: _secret));

  group('French contact', () {
    testWidgets('verify passes on the French words', (tester) async {
      final words = await TotpWords.generate(
        secret: _secret,
        unixTimeSeconds: _t,
        senderRole: _mom.role.other,
        list: _french,
      );
      await tester.pumpWidget(_verify(store));
      await tester.pumpAndSettle();
      await _type(tester, words);
      expect(find.text('VERIFIED'), findsOneWidget);
    });

    testWidgets('accent-free French words pass too', (tester) async {
      final words = await TotpWords.generate(
        secret: _secret,
        unixTimeSeconds: _t,
        senderRole: _mom.role.other,
        list: _french,
      );
      await tester.pumpWidget(_verify(store));
      await tester.pumpAndSettle();
      await _type(tester, [for (final w in words) _french.fold(w)!]);
      expect(find.text('VERIFIED'), findsOneWidget);
    });

    testWidgets('our own French words read back fail (reflection)',
        (tester) async {
      final own = await TotpWords.generate(
        secret: _secret,
        unixTimeSeconds: _t,
        senderRole: _mom.role,
        list: _french,
      );
      await tester.pumpWidget(_verify(store));
      await tester.pumpAndSettle();
      await _type(tester, own);
      expect(find.text('NOT VERIFIED — BE SUSPICIOUS'), findsOneWidget);
      expect(find.text('VERIFIED'), findsNothing);
    });

    testWidgets('show my words shows our words in French', (tester) async {
      final own = await TotpWords.generate(
        secret: _secret,
        unixTimeSeconds: _t,
        senderRole: _mom.role,
        list: _french,
      );
      await tester.pumpWidget(_verify(store));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Show my 4 words'));
      await tester.tap(find.text('Show my 4 words'));
      await tester.pumpAndSettle();
      for (final w in own) {
        expect(find.text(w), findsOneWidget, reason: w);
      }
    });

    testWidgets('the challenge grid is in French', (tester) async {
      final grid = await ChallengeResponseGrid.derive(_secret, list: _french);
      await tester.pumpWidget(
          _app(store, '/grid', CrGridScreen(relationshipId: _mom.id)));
      await tester.pumpAndSettle();
      expect(_onlyFrench(grid.colLabels.take(1).toList()), isTrue,
          reason: 'pick a secret whose first column label is French-only');
      expect(find.textContaining(grid.colLabels.first), findsWidgets);
    });

    testWidgets('the binding phrase is in French', (tester) async {
      final phrase = await PairingVerification.derivePhrase(
          sharedSecret: _secret, list: _french);
      await tester.pumpWidget(_app(
          store, '/binding', BindingPhraseScreen(relationshipId: _mom.id)));
      await tester.pumpAndSettle();
      final word = phrase.firstWhere((w) => _onlyFrench([w]));
      expect(find.textContaining(word, findRichText: true), findsWidgets);
    });

    testWidgets('a backup carries fr and French PAKE words', (tester) async {
      await tester.pumpWidget(_app(
          store, '/export', BackupExportScreen(relationshipId: _mom.id)));
      await tester.pumpAndSettle();
      final wire = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .firstWhere((s) => (s.data ?? '').startsWith('signet:tp1:'))
          .data!;
      await tester.ensureVisible(find.text('I saved it another way'));
      await tester.tap(find.text('I saved it another way'));
      await tester.pumpAndSettle();
      final words = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) =>
              t.style?.fontFamily == 'monospace' && t.style?.fontSize == 16)
          .take(8)
          .map((t) => t.data!)
          .toList();
      expect(words.every(_french.contains), isTrue, reason: '$words');
      final decoded =
          await TransportPackage.decodeLpr(wire, pakeWords: words);
      expect(TransportPackage.wordListIdOf(decoded.extensions), 'fr');
    });
  });

  group('a language this version does not have', () {
    final newer = _mom.copyWith(wordLanguage: 'zh-9');
    setUp(() => store = FakeSecureStore(seeded: newer, secret: _secret));
    const notice =
        "Mom's words use a language this version of Signet does not have. "
        'Update Signet to see them.';

    testWidgets('verify asks for an update, with no words or input',
        (tester) async {
      await tester.pumpWidget(_verify(store));
      await tester.pumpAndSettle();
      expect(find.text(notice), findsOneWidget);
      expect(find.textContaining('Do not act on an urgent request'),
          findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Show my 4 words'), findsNothing);
    });

    testWidgets('the grid asks for an update', (tester) async {
      await tester.pumpWidget(
          _app(store, '/grid', CrGridScreen(relationshipId: _mom.id)));
      await tester.pumpAndSettle();
      expect(find.text(notice), findsOneWidget);
    });

    testWidgets('the binding phrase asks for an update', (tester) async {
      await tester.pumpWidget(_app(
          store, '/binding', BindingPhraseScreen(relationshipId: _mom.id)));
      await tester.pumpAndSettle();
      expect(find.text(notice), findsOneWidget);
    });

    testWidgets('a backup still carries the id it does not know',
        (tester) async {
      await tester.pumpWidget(_app(
          store, '/export', BackupExportScreen(relationshipId: _mom.id)));
      await tester.pumpAndSettle();
      final wire = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .firstWhere((s) => (s.data ?? '').startsWith('signet:tp1:'))
          .data!;
      await tester.ensureVisible(find.text('I saved it another way'));
      await tester.tap(find.text('I saved it another way'));
      await tester.pumpAndSettle();
      final words = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) =>
              t.style?.fontFamily == 'monospace' && t.style?.fontSize == 16)
          .take(8)
          .map((t) => t.data!)
          .toList();
      final decoded =
          await TransportPackage.decodeLpr(wire, pakeWords: words);
      expect(TransportPackage.wordListIdOf(decoded.extensions), 'zh-9');
    });
  });

  testWidgets('a damaged tag says to pair again, not to update',
      (tester) async {
    store = FakeSecureStore(
      seeded: _mom.copyWith(wordLanguage: Relationship.damagedWordLanguage),
      secret: _secret,
    );
    await tester.pumpWidget(_verify(store));
    await tester.pumpAndSettle();
    expect(find.textContaining('came from a damaged backup'), findsOneWidget);
    expect(find.textContaining('Update Signet'), findsNothing);
    expect(find.textContaining('Do not act on an urgent request'),
        findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  group('restore keeps the language', () {
    final pake = TransportPackage.mintPakeWords();

    Future<Relationship> restoreSingle(
        WidgetTester tester, List<TransportExtension> ext) async {
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.b,
        pairedAt: DateTime.utc(2026, 2, 14),
        silentHaptics: false,
        sharedSecret: _secret,
        pakeWords: pake,
        extensions: ext,
      );
      final empty = FakeSecureStore();
      await tester.pumpWidget(
          _app(empty, '/inspect/import', const BackupImportScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, wire);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), pake.join(' '));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('UNLOCK BACKUP'));
      await tester.tap(find.text('UNLOCK BACKUP'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('COMMIT IMPORT'));
      await tester.tap(find.text('COMMIT IMPORT'));
      await tester.pumpAndSettle();
      return (await empty.listRelationships()).single;
    }

    testWidgets('a French single backup restores as French', (tester) async {
      final restored = await restoreSingle(
          tester, [TransportPackage.wordListExtension('fr')]);
      expect(restored.wordLanguage, 'fr');
    });

    testWidgets('a v0.4.0 backup (no tag) restores as English',
        (tester) async {
      final restored = await restoreSingle(tester, const []);
      expect(restored.wordLanguage, 'en');
    });

    BlkRelationshipRecord record(int seed, String label, String? id) =>
        BlkRelationshipRecord(
          sharedSecret: Uint8List.fromList(
              List<int>.generate(32, (i) => (i + seed) & 0xFF)),
          role: PairRole.a,
          label: label,
          pairedAt: DateTime.utc(2026, 1, 1),
          silentHaptics: false,
          extensions: {
            if (id != null)
              TransportPackage.wordListTag:
                  TransportPackage.wordListExtension(id).value,
          },
        );

    Widget bulk(FakeSecureStore s, List<BlkRelationshipRecord> records) =>
        _app(
          s,
          '/inspect/import-bulk',
          BulkBackupImportScreen(
            decoded: BlkPackage(
                records: records, timestamp: DateTime.utc(2026, 4, 22)),
          ),
        );

    testWidgets('bulk restore keeps each record\'s language', (tester) async {
      final empty = FakeSecureStore();
      await tester.pumpWidget(bulk(empty, [
        record(1, 'Grand-mère', 'fr'),
        record(2, 'Dad', 'en'),
        record(3, 'Old', null),
      ]));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('RESTORE 3'));
      await tester.tap(find.text('RESTORE 3'));
      await tester.pumpAndSettle();
      final byLabel = {
        for (final r in await empty.listRelationships()) r.label: r,
      };
      expect(byLabel['Grand-mère']!.wordLanguage, 'fr');
      expect(byLabel['Dad']!.wordLanguage, 'en');
      expect(byLabel['Old']!.wordLanguage, 'en');
    });

    testWidgets('a same-language bulk Overwrite leaves the change date alone',
        (tester) async {
      for (final id in <String?>['fr', null]) {
        final existing = _mom.copyWith(wordLanguage: id ?? 'en');
        final s = FakeSecureStore(seeded: existing, secret: _secret);
        await tester.pumpWidget(bulk(s, [record(1, 'Mom', id)]));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Overwrite existing pairing'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('RESTORE 1'));
        await tester.pumpAndSettle();
        final mom = (await s.listRelationships()).single;
        expect(mom.wordLanguage, id ?? 'en');
        expect(mom.wordLanguageChangedAt, isNull, reason: '$id');
      }
    });

    testWidgets('bulk Overwrite takes the backup\'s language and dates it',
        (tester) async {
      final existing = _mom.copyWith(wordLanguage: 'en');
      final s = FakeSecureStore(seeded: existing, secret: _secret);
      await tester.pumpWidget(bulk(s, [record(1, 'Mom', 'fr')]));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Overwrite existing pairing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RESTORE 1'));
      await tester.pumpAndSettle();
      final mom = (await s.listRelationships()).single;
      expect(mom.id, existing.id);
      expect(mom.wordLanguage, 'fr');
      expect(mom.wordLanguageChangedAt, isNotNull);
    });
  });
}
