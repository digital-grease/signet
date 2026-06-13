import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/big_button.dart';
import '../../core/models/label_policy.dart';
import 'pairing_controller.dart';

/// Step 1 of the pair flow: ask who this person is and persist the label
/// in the [pairingControllerProvider]. The text field is autofocused so
/// the keyboard opens immediately.
class PairStartScreen extends ConsumerStatefulWidget {
  const PairStartScreen({super.key});

  @override
  ConsumerState<PairStartScreen> createState() => _PairStartScreenState();
}

class _PairStartScreenState extends ConsumerState<PairStartScreen> {
  final TextEditingController _label = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    // Fresh flow: reset any half-finished previous attempt.
    Future<void>.microtask(
      () => ref.read(pairingControllerProvider.notifier).reset(),
    );
  }

  void _continue() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Please enter a name for this contact.');
      return;
    }
    final reason = LabelPolicy.rejectionReason(label);
    if (reason != null) {
      setState(() => _error = reason);
      return;
    }
    ref.read(pairingControllerProvider.notifier).setLabel(label);
    context.go('/pair/exchange');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair a contact'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                "What's this person's name?",
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Only stored on your phone. Use whatever you will recognise '
                'at a glance — "Mom", "Jake", "Finance Team".',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _label,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: textTheme.titleLarge,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: const OutlineInputBorder(),
                  errorText: _error.isEmpty ? null : _error,
                ),
                onSubmitted: (_) => _continue(),
                onChanged: (_) {
                  if (_error.isNotEmpty) setState(() => _error = '');
                },
              ),
              const Spacer(),
              BigButton(
                label: 'Continue',
                icon: Icons.arrow_forward,
                onPressed: _continue,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
