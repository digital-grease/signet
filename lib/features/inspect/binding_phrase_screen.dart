import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/verification.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../shared/widgets/secure_screen.dart';

/// Re-derives the pair-time 4-word phrase from the currently-stored shared
/// secret and renders it for the user to read aloud to the peer (who
/// opens the same screen on their device). If both phrases match, the
/// pairing is still intact; mismatch means either device has been tampered
/// with or the pairing was never correct to begin with.
///
/// No commit / verify button on this screen: it's a *re-check* affordance,
/// not a rekey operation. Rekey lands in Phase 10.6.
class BindingPhraseScreen extends ConsumerStatefulWidget {
  const BindingPhraseScreen({super.key});

  @override
  ConsumerState<BindingPhraseScreen> createState() =>
      _BindingPhraseScreenState();
}

class _BindingPhraseScreenState extends ConsumerState<BindingPhraseScreen> {
  Relationship? _relationship;
  List<String>? _phrase;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = ref.read(secureStoreProvider);
      final relationships = await store.listRelationships();
      final relationship =
          relationships.isEmpty ? null : relationships.first;
      final secret = relationship == null
          ? null
          : await store.getSharedSecretById(relationship.id);
      if (relationship == null || secret == null) {
        if (!mounted) return;
        setState(() => _loadError = StateError('No paired contact.'));
        return;
      }
      final phrase = await PairingVerification.derivePhrase(
        sharedSecret: secret,
      );
      if (!mounted) return;
      setState(() {
        _relationship = relationship;
        _phrase = phrase;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VERIFY BINDING'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loadError != null) {
      return const _ErrorBlock(message: 'Could not read your pairing.');
    }
    final relationship = _relationship;
    final phrase = _phrase;
    if (relationship == null || phrase == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'PAIR-TIME PHRASE //',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: scheme.onSurfaceVariant,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'These 4 words were derived the moment you and ${relationship.label} paired. '
          'Ask ${relationship.label} to open Signet and tap this same screen. '
          'If the 4 words on both devices match, the pairing is intact.',
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _PhraseCard(words: phrase),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          color: scheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'IF THEY DO NOT MATCH //',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: scheme.error,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unpair and re-pair in person. Do not verify any calls '
                'against this pairing until you have.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: 12),
        Text(
          'AIRPLANE // NO NETWORK · NO TELEMETRY · STRONGBOX',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
      ],
      ),
    );
  }
}

class _PhraseCard extends StatelessWidget {
  const _PhraseCard({required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < words.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}.',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      words[i],
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline, size: 48, color: scheme.error),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('BACK TO HOME'),
          ),
        ],
      ),
    );
  }
}
