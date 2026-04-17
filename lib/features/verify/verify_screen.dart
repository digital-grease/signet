import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/totp.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../shared/widgets/code_display.dart';

/// Loads the paired relationship + secret once, then refreshes the TOTP
/// every second via [Timer.periodic]. Recomputing a single HMAC-SHA-256
/// per tick is negligible on any modern phone.
///
/// The screen handles three failure modes explicitly:
///   - No relationship paired: friendly redirect back home.
///   - Secret-store read error: retriable error card.
///   - Timer outlives the widget: cancelled in [dispose] to avoid setState
///     after unmount.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  static const int _windowSeconds = Totp.defaultTimeStepSeconds;

  Timer? _ticker;
  Relationship? _relationship;
  List<int>? _secret;
  Object? _loadError;
  String _code = '--------';
  int _secondsRemaining = _windowSeconds;

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
    if (secret == null) return;
    final nowUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final code = await Totp.generate(
      secret: secret,
      unixTimeSeconds: nowUnix,
    );
    if (!mounted) return;
    setState(() {
      _code = code;
      _secondsRemaining = _windowSeconds - (nowUnix % _windowSeconds);
    });
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied.'),
        duration: Duration(seconds: 2),
      ),
    );
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _buildBody(context),
        ),
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

    return Column(
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          'Ask ${relationship.label} for their current code,',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        Text(
          'then compare to yours below.',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        const Spacer(),
        CodeDisplay(
          code: _code,
          secondsRemaining: _secondsRemaining,
          windowSeconds: _windowSeconds,
          onTap: _copyCode,
        ),
        const SizedBox(height: 12),
        Text(
          'Tap the code to copy.',
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const Spacer(),
        Text(
          relationship.label,
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
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
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onBack, child: const Text('Back to home')),
        ],
      ),
    );
  }
}
