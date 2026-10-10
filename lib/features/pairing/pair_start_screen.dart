import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/label_input.dart';
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
    final label = LabelPolicy.clean(_label.text);
    final l10n = AppLocalizations.of(context);
    final rejection = LabelPolicy.check(label);
    if (rejection != null) {
      setState(() => _error = rejection == LabelRejection.empty
          ? l10n.pairStartEmptyNameError
          : labelRejectionText(rejection, l10n));
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pairStartTitle),
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
                l10n.pairStartHeading,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pairStartPrivacyNote,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _label,
                autofocus: true,
                inputFormatters: <TextInputFormatter>[
                  Utf8LengthLimitingTextInputFormatter(LabelPolicy.maxBytes),
                ],
                buildCounter: utf8ByteCounter(_label, LabelPolicy.maxBytes),
                textCapitalization: TextCapitalization.words,
                style: textTheme.titleLarge,
                decoration: InputDecoration(
                  labelText: l10n.pairStartNameLabel,
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
                label: l10n.pairStartContinueButton,
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
