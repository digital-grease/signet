import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/backup_bundle.dart';
import '../../core/crypto/transport_package.dart';
import '../../core/models/label_policy.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/secure_screen.dart';
import 'two_step_backup.dart';

/// Paper-mnemonic export for lost-phone recovery. Mints a fresh 8-word
/// PAKE secret, encodes the existing relationship as an LPR package, and
/// presents both to the user with instructions to **store them separately
/// and offline**. The package-text is rendered both as a QR (for cameras)
/// and as selectable text (for paste / OCR / backup). The PAKE secret is
/// rendered as a numbered mono list the user writes down somewhere
/// different — a password manager, a safety deposit box, whatever.
///
/// Critically: the user must store the PAKE secret on a different
/// physical artifact than the package itself. If an attacker finds both,
/// they have the full shared secret. This is called out explicitly in
/// the WARNING block.
///
/// Wrapped in [SecureScreen] — the package contains the shared secret
/// (encrypted) and the PAKE secret is plaintext; screenshots would
/// capture both.
class BackupExportScreen extends ConsumerStatefulWidget {
  const BackupExportScreen({super.key, required this.relationshipId});

  final String relationshipId;

  @override
  ConsumerState<BackupExportScreen> createState() =>
      _BackupExportScreenState();
}

class _BackupExportScreenState extends ConsumerState<BackupExportScreen> {
  _Generated? _generated;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final store = ref.read(secureStoreProvider);
      final relationship =
          await store.getRelationshipById(widget.relationshipId);
      final secret =
          await store.getSharedSecretById(widget.relationshipId);
      if (!mounted) return;
      if (relationship == null || secret == null) {
        setState(
          () => _error = StateError(
              AppLocalizations.of(context).commonRelationshipNotFound),
        );
        return;
      }
      final pakeWords = TransportPackage.mintPakeWords();
      final wire = await TransportPackage.encodeLpr(
        // A name saved before the 64-byte limit is cut to fit rather than
        // failing the backup.
        label: LabelPolicy.truncateToBytes(
            relationship.label, LabelPolicy.maxBytes),
        role: relationship.role,
        pairedAt: relationship.pairedAt,
        silentHaptics: relationship.silentHaptics,
        sharedSecret: secret,
        pakeWords: pakeWords,
      );
      final fingerprint = await BackupFiles.fingerprint(wire);
      if (!mounted) return;
      setState(() {
        _generated = _Generated(
          relationship: relationship,
          pakeWords: pakeWords,
          wire: wire,
          fingerprint: fingerprint!,
          generatedAt: DateTime.now(),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).backupExportTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/'),
          ),
        ),
        body: SafeArea(
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.backupExportGenerateError(_error.toString())),
        ),
      );
    }
    final gen = _generated;
    if (gen == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: _BackupContent(generated: gen),
    );
  }
}

class _BackupContent extends StatelessWidget {
  const _BackupContent({required this.generated});
  final _Generated generated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.backupExportHeading(generated.relationship.label),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.backupExportIntro(generated.relationship.label),
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        _WarningBlock(
          color: scheme.error,
          bg: scheme.errorContainer,
          fg: scheme.onErrorContainer,
          headline: l10n.commonStoreSeparatelyHeader,
          body: l10n.backupExportStoreSeparatelyBody,
        ),
        const SizedBox(height: 16),
        _WarningBlock(
          color: scheme.secondary,
          bg: scheme.surfaceContainerHighest,
          fg: scheme.onSurface,
          headline: l10n.commonRememberHeader,
          body: l10n.backupExportRememberBody(generated.relationship.label),
        ),
        const SizedBox(height: 24),
        // Package and words are saved in two separate steps and never
        // travel together (plan Phase 2, bug S1).
        TwoStepBackupSaver(
          wire: generated.wire,
          pakeWords: generated.pakeWords,
          fingerprint: generated.fingerprint,
          generatedAt: generated.generatedAt,
          onDone: () => context.go('/'),
        ),
      ],
    );
  }
}

class _WarningBlock extends StatelessWidget {
  const _WarningBlock({
    required this.color,
    required this.bg,
    required this.fg,
    required this.headline,
    required this.body,
  });

  final Color color;
  final Color bg;
  final Color fg;
  final String headline;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            headline,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: color,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(fontSize: 13, color: fg, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Generated {
  _Generated({
    required this.relationship,
    required this.pakeWords,
    required this.wire,
    required this.fingerprint,
    required this.generatedAt,
  });

  final Relationship relationship;
  final List<String> pakeWords;
  final String wire;
  final String fingerprint;
  final DateTime generatedAt;
}
