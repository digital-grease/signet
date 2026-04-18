import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/totp_words.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../core/theme/signet_theme.dart';
import '../../shared/widgets/words_display.dart';
import 'word_input.dart';

/// Two-sided verify UI.
///
/// Primary action is type-and-verify: the caller reads their 4 words aloud,
/// the receiver types them into a 4-slot autocomplete input, and `TotpWords`
/// returns a binary ✅/❌ with ±1 window tolerance absorbing clock drift
/// silently.
///
/// Secondary (collapsed by default) is show-my-own-words for when the other
/// party wants to verify *this* device. The rotating 4 words tick once a
/// second, same cadence as the pair-time ticker pattern.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

enum _VerifyStatus { verified, notVerified }

class _VerifyResult {
  const _VerifyResult(this.status, this.at);
  final _VerifyStatus status;
  final DateTime at;
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  static const int _windowSeconds = TotpWords.defaultTimeStepSeconds;

  Relationship? _relationship;
  List<int>? _secret;
  Object? _loadError;
  Timer? _ticker;
  List<String> _ownWords = const <String>[];
  int _secondsRemaining = _windowSeconds;

  int _resetKey = 0;
  _VerifyResult? _lastResult;
  bool _showOwnWords = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final store = ref.read(secureStoreProvider);
      final relationship = await store.getRelationship();
      final secret = await store.getSharedSecret();
      if (!mounted) return;
      if (relationship == null || secret == null) {
        setState(() => _loadError = StateError('No paired contact.'));
        return;
      }
      setState(() {
        _relationship = relationship;
        _secret = secret;
      });
      await _tick();
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_tick()),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _tick() async {
    final secret = _secret;
    final relationship = _relationship;
    if (secret == null || relationship == null) return;
    final nowUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    // Our role emits "Show my 4 words" — this is what the other side will
    // read to verify us, and what we would read to them.
    final words = await TotpWords.generate(
      secret: secret,
      unixTimeSeconds: nowUnix,
      senderRole: relationship.role,
    );
    if (!mounted) return;
    setState(() {
      _ownWords = words;
      _secondsRemaining = _windowSeconds - (nowUnix % _windowSeconds);
    });
  }

  Future<void> _handleSubmit(List<String> candidate) async {
    final secret = _secret;
    final relationship = _relationship;
    if (secret == null || relationship == null) return;
    final nowUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    // Verify against the COUNTERPARTY's role — the words the other device
    // would emit. Using our own role here would accept our own displayed
    // words reflected back at us (the reflection attack).
    final ok = await TotpWords.verify(
      secret: secret,
      candidate: candidate,
      unixTimeSeconds: nowUnix,
      senderRole: relationship.role.other,
    );
    if (!mounted) return;
    setState(() {
      _lastResult = _VerifyResult(
        ok ? _VerifyStatus.verified : _VerifyStatus.notVerified,
        DateTime.now(),
      );
      // Bump on BOTH outcomes, not just ❌. If we only bump on ❌, a prior
      // ✅ leaves `WordInput._lastSubmittedOnResetKey` pinned to the current
      // resetKey, which silently blocks every subsequent submit attempt.
      // That was the bug that made reflection attacks appear to succeed
      // live: the stale ✅ banner persisted while new keystrokes fired no
      // new verify. Bumping on ✅ too clears the slots for the next
      // verification and guarantees every real attempt actually runs.
      _resetKey++;
    });
    if (ok) {
      unawaited(HapticFeedback.lightImpact());
    } else {
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadError != null) {
      return _VerifyError(
        message: 'Could not read your paired contact.',
        detail: _loadError.toString(),
        onBack: () => context.go('/'),
      );
    }
    final relationship = _relationship;
    if (relationship == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Ask ${relationship.label} for their 4 words.',
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Type what you hear. Tap a suggestion to fill a slot.',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_lastResult != null) _ResultBanner(result: _lastResult!),
          if (_lastResult != null) const SizedBox(height: 16),
          WordInput(
            onSubmit: _handleSubmit,
            resetKey: _resetKey,
          ),
          const SizedBox(height: 32),
          _OwnWordsSection(
            label: relationship.label,
            expanded: _showOwnWords,
            onToggle: () => setState(() => _showOwnWords = !_showOwnWords),
            words: _ownWords,
            secondsRemaining: _secondsRemaining,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final _VerifyResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOk = result.status == _VerifyStatus.verified;

    // Tokens are defined in core/theme/signet_theme.dart. Material 3's
    // primaryContainer derivation is not usable here — we need an
    // unambiguously "verified/OK" tone distinct from any neutral surface,
    // and an unambiguously "failed" tone distinct from generic error states
    // elsewhere in the app.
    final bg = isOk
        ? (isDark ? SignetTokens.okBg : SignetTokens.okBgL)
        : (isDark ? SignetTokens.failBg : SignetTokens.failBgL);
    final fg = isOk
        ? (isDark ? SignetTokens.okFg : SignetTokens.okFgL)
        : (isDark ? SignetTokens.failFg : SignetTokens.failFgL);
    final accent = isOk ? SignetTokens.ok : SignetTokens.fail;
    final icon = isOk ? Icons.verified : Icons.gpp_bad;
    final headline =
        isOk ? 'Verified' : 'Not verified — be suspicious.';
    final subline = isOk
        ? 'The words match. You can trust this call.'
        : 'The words did not match. Someone may be impersonating them.';

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$headline. $subline',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 32, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    headline,
                    style: textTheme.titleLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subline,
                    style: textTheme.bodyMedium?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnWordsSection extends StatelessWidget {
  const _OwnWordsSection({
    required this.label,
    required this.expanded,
    required this.onToggle,
    required this.words,
    required this.secondsRemaining,
  });

  final String label;
  final bool expanded;
  final VoidCallback onToggle;
  final List<String> words;
  final int secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Show my 4 words',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'If $label wants to verify you, read these.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: words.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : WordsDisplay(
                      words: words,
                      secondsRemaining: secondsRemaining,
                      windowSeconds: _VerifyScreenState._windowSeconds,
                    ),
            ),
        ],
      ),
    );
  }
}

class _VerifyError extends StatelessWidget {
  const _VerifyError({
    required this.message,
    required this.detail,
    required this.onBack,
  });

  final String message;
  final String detail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onBack, child: const Text('Back to home')),
        ],
      ),
    );
  }
}
