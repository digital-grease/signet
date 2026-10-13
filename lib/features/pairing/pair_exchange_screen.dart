import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/secure_clipboard.dart';
import '../../shared/widgets/big_button.dart';
import '../../shared/widgets/fill_or_scroll.dart';
import '../../shared/widgets/qr_scanner.dart';
import '../../shared/widgets/secure_screen.dart';
import 'in_person_pairing_controller.dart';
import 'pairing_code_v2.dart';

/// In-person pairing, commit-then-reveal (plan Task 1.7f): one phone taps
/// Start, the other Join, and they trade three codes:
///
///   Start: shows code 1 -> scans the other phone -> shows code 3
///   Join:  scans code 1 -> shows code 2 -> scans code 3
///
/// then both compare 4 words on the confirm screen. "Step N" is the moment
/// code N crosses between the phones, so both phones are on the same step
/// number even though one shows while the other scans. The protocol and its
/// rules live in [InPersonPairingController]; this screen shows the step it
/// is on. A phone cannot tell when its QR code was scanned, so each "show"
/// step ends with a tap whose hint names what the user CAN see (the other
/// phone moving on), and each scan step can go back to showing.
class PairExchangeScreen extends ConsumerStatefulWidget {
  const PairExchangeScreen({super.key});

  @override
  ConsumerState<PairExchangeScreen> createState() => _PairExchangeScreenState();
}

class _PairExchangeScreenState extends ConsumerState<PairExchangeScreen> {
  /// Nothing scanned on a scan-first step for this long: show a hint.
  static const Duration idleHintAfter = Duration(seconds: 20);

  /// An attempt that runs this long ends ([InPersonFailure.timedOut]).
  static const Duration attemptLimit = Duration(minutes: 5);

  late final InPersonPairingController _ctrl;
  bool _navigated = false;
  bool _pasting = false;
  bool _showText = false;
  bool _idleHint = false;
  Timer? _idleTimer;
  Timer? _attemptTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = ref.read(inPersonPairingControllerProvider.notifier);
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _attemptTimer?.cancel();
    // Leaving mid-attempt drops its keys. Not when moving on to confirm:
    // that screen reads the result. After the frame, so no provider is
    // modified while the tree is being torn down.
    if (!_navigated) {
      final ctrl = _ctrl;
      Future<void>.microtask(ctrl.abort);
    }
    super.dispose();
  }

  static bool _running(InPersonStep step) => switch (step) {
    InPersonStep.chooseRole ||
    InPersonStep.confirm ||
    InPersonStep.failed => false,
    _ => true,
  };

  void _onStepChanged(
    InPersonPairingState? previous,
    InPersonPairingState next,
  ) {
    if (next.step == InPersonStep.confirm && !_navigated) {
      _navigated = true;
      _attemptTimer?.cancel();
      context.go('/pair/confirm');
      return;
    }
    if (previous?.step == next.step) return;
    _idleTimer?.cancel();
    setState(() {
      _pasting = false;
      _showText = false;
      _idleHint = false;
    });
    if (!_running(next.step)) {
      _attemptTimer?.cancel();
      _attemptTimer = null;
    } else {
      _attemptTimer ??= Timer(attemptLimit, _ctrl.timeOut);
    }
    if (next.step == InPersonStep.joinScanCommit ||
        next.step == InPersonStep.startScanKey) {
      _idleTimer = Timer(idleHintAfter, () {
        if (mounted) setState(() => _idleHint = true);
      });
    }
    _announce(next);
  }

  /// Speaks each new step once: an announcement where the platform takes
  /// one (iOS), otherwise the step heading is a live region keyed per step
  /// (Android), never both (VoiceOver would read it twice).
  void _announce(InPersonPairingState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !MediaQuery.supportsAnnounceOf(context)) return;
      final text = _spokenFor(state, AppLocalizations.of(context));
      if (text == null) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          text,
          Directionality.of(context),
        ),
      );
    });
  }

  String? _spokenFor(InPersonPairingState s, AppLocalizations l10n) {
    if (s.step == InPersonStep.failed) {
      return _failureLines(s.failure, l10n).join(' ');
    }
    final heading = _headingFor(s.step, l10n);
    if (heading == null) return null;
    final step = _stepNumber(s.step);
    return step == null
        ? heading
        : '${l10n.pairInPersonStepLabel(step)}. $heading';
  }

  static int? _stepNumber(InPersonStep step) => switch (step) {
    InPersonStep.startShowCommit || InPersonStep.joinScanCommit => 1,
    InPersonStep.startScanKey || InPersonStep.joinShowKey => 2,
    InPersonStep.startShowReveal || InPersonStep.joinScanReveal => 3,
    _ => null,
  };

  static String? _headingFor(InPersonStep step, AppLocalizations l10n) =>
      switch (step) {
        InPersonStep.startShowCommit ||
        InPersonStep.joinShowKey => l10n.pairInPersonShowHeading,
        InPersonStep.startShowReveal => l10n.pairInPersonShowRevealHeading,
        InPersonStep.joinScanCommit ||
        InPersonStep.startScanKey => l10n.pairInPersonScanHeading,
        InPersonStep.joinScanReveal => l10n.pairInPersonScanRevealHeading,
        InPersonStep.deriving => l10n.pairInPersonDeriving,
        _ => null,
      };

  /// What a failure says. The weak-key warning already tells both people
  /// to cancel and start again, so it is not followed by the generic
  /// start-over line.
  static List<String> _failureLines(InPersonFailure? f, AppLocalizations l10n) {
    final message = switch (f) {
      InPersonFailure.startStart => l10n.pairFailStartStart,
      InPersonFailure.joinJoin => l10n.pairFailJoinJoin,
      InPersonFailure.secondCode => l10n.pairFailSecondCode,
      InPersonFailure.wrongCodeForStep => l10n.pairFailWrongCode,
      InPersonFailure.revealMismatch => l10n.pairFailRevealMismatch,
      InPersonFailure.weakKey => l10n.pairingWeakKeyInPersonError,
      InPersonFailure.timedOut => l10n.pairFailTimedOut,
      InPersonFailure.internal || null => l10n.pairFailInternal,
    };
    return <String>[
      message,
      if (f != InPersonFailure.weakKey) l10n.pairInPersonStartOverBoth,
    ];
  }

  static String noticeText(PairingCodeError notice, AppLocalizations l10n) =>
      switch (notice) {
        PairingCodeError.malformed => l10n.pairCodeMalformedNotice,
        PairingCodeError.notAPairingCode => l10n.pairCodeNotPairingNotice,
        PairingCodeError.multipleCodes => l10n.pairCodeMultipleNotice,
        PairingCodeError.peerNeedsUpdate => l10n.pairCodePeerNeedsUpdateNotice,
        PairingCodeError.thisNeedsUpdate => l10n.pairCodeThisNeedsUpdateNotice,
      };

  /// A scanned or pasted code. Returns a message to show while scanning
  /// goes on, or null when the code moved the attempt on (the scanner then
  /// stops; the next pane replaces it).
  Future<String?> _submit(String text) async {
    final before = ref.read(inPersonPairingControllerProvider).step;
    await _ctrl.onScan(text);
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    final after = ref.read(inPersonPairingControllerProvider);
    final notice = after.notice;
    if (notice != null) return noticeText(notice, l10n);
    if (after.step == before && after.failure == null) {
      // A code this phone already used: the other phone has not moved on.
      return l10n.pairCodeAlreadyScannedNotice;
    }
    if (after.failure == null) unawaited(HapticFeedback.selectionClick());
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pair = ref.watch(inPersonPairingControllerProvider);
    ref.listen(inPersonPairingControllerProvider, _onStepChanged);
    final l10n = AppLocalizations.of(context);
    final contact = pair.label ?? l10n.pairExchangeFallbackContact;
    final running = _running(pair.step);

    // Codes are public, but blocking screenshots and recording keeps a
    // recorded pairing from being replayed or studied off-device.
    return SecureScreen(
      child: PopScope(
        canPop: !running,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _ctrl.abort();
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(
              pair.isRekey
                  ? l10n.pairExchangeTitleRekey(contact)
                  : l10n.pairExchangeTitlePair(contact),
            ),
            // Outside an attempt the X leaves pairing; during one, START
            // OVER (the button the copy names) drops it.
            leading: running
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => context.go('/'),
                  ),
            actions: <Widget>[
              if (running)
                TextButton(
                  onPressed: _ctrl.abort,
                  child: Text(l10n.pairInPersonStartOverButton),
                ),
            ],
          ),
          body: SafeArea(child: _body(pair, l10n)),
        ),
      ),
    );
  }

  Widget _body(InPersonPairingState pair, AppLocalizations l10n) {
    switch (pair.step) {
      case InPersonStep.chooseRole:
        return _RoleChoice(
          onStart: () => _ctrl.begin(InPersonRole.start),
          onJoin: () => _ctrl.begin(InPersonRole.join),
        );
      case InPersonStep.startShowCommit:
      case InPersonStep.joinShowKey:
      case InPersonStep.startShowReveal:
        final finish = pair.step == InPersonStep.startShowReveal;
        return _ShowPane(
          step: _stepNumber(pair.step)!,
          heading: _headingFor(pair.step, l10n)!,
          payload: pair.qrPayload,
          showText: _showText,
          onToggleText: () => setState(() => _showText = !_showText),
          doneLabel: finish
              ? l10n.pairInPersonShowWordsButton
              : l10n.pairInPersonNextButton,
          doneHint: finish
              ? l10n.pairInPersonFinishHint
              : l10n.pairInPersonNextHint,
          onDone: switch (pair.step) {
            InPersonStep.startShowCommit => _ctrl.startNext,
            InPersonStep.joinShowKey => _ctrl.joinNext,
            _ => () => unawaited(_ctrl.startFinish()),
          },
        );
      case InPersonStep.startScanKey:
      case InPersonStep.joinScanCommit:
      case InPersonStep.joinScanReveal:
        final step = _stepNumber(pair.step)!;
        // Back to showing, for a NEXT tapped before the other phone had
        // scanned. Join's first step has nothing to show yet.
        final VoidCallback? showAgain = switch (pair.step) {
          InPersonStep.startScanKey => _ctrl.startBack,
          InPersonStep.joinScanReveal => _ctrl.joinBack,
          _ => null,
        };
        if (_pasting) {
          return _PastePane(
            step: step,
            submit: _ctrl.onScan,
            noticeOf: () => ref.read(inPersonPairingControllerProvider).notice,
            onBack: () => setState(() => _pasting = false),
          );
        }
        return _ScanPane(
          step: step,
          heading: _headingFor(pair.step, l10n)!,
          hint: !_idleHint
              ? null
              : switch (pair.step) {
                  InPersonStep.joinScanCommit => l10n.pairInPersonJoinIdleHint,
                  InPersonStep.startScanKey => l10n.pairInPersonStartIdleHint,
                  _ => null,
                },
          onCode: _submit,
          onPaste: () => setState(() => _pasting = true),
          onShowAgain: showAgain,
          onCancel: _ctrl.abort,
        );
      case InPersonStep.deriving:
      case InPersonStep.confirm:
        return _Progress(text: l10n.pairInPersonDeriving);
      case InPersonStep.failed:
        return _FailedPane(
          lines: _failureLines(pair.failure, l10n),
          onStartOver: _ctrl.abort,
        );
    }
  }
}

/// A heading that TalkBack reads when it appears, where the screen does not
/// announce steps itself (see [_PairExchangeScreenState._announce]).
class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.step,
    required this.text,
    this.compact = false,
  });

  final int? step;
  final String text;

  /// One smaller line, for scan steps, where every pixel the heading uses
  /// is taken from the camera (large text at 2x on a small phone).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      key: ValueKey<String>('heading-$step-$text'),
      liveRegion: !MediaQuery.supportsAnnounceOf(context),
      header: true,
      child: compact
          ? Text(
              step == null
                  ? text
                  : '${l10n.pairInPersonStepLabel(step!)}. $text',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (step != null)
                  Text(
                    l10n.pairInPersonStepLabel(step!),
                    textAlign: TextAlign.center,
                    style: textTheme.labelLarge,
                  ),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall,
                ),
              ],
            ),
    );
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({required this.onStart, required this.onJoin});

  final VoidCallback onStart;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return FillOrScroll(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.pairInPersonIntro,
            style: textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.pairInPersonRoleHint, style: textTheme.titleMedium),
          const Spacer(),
          const SizedBox(height: 24),
          BigButton(
            label: l10n.pairInPersonStartButton,
            icon: Icons.qr_code_2,
            onPressed: onStart,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.pairInPersonStartSubtitle,
            textAlign: TextAlign.center,
            style: secondary,
          ),
          const SizedBox(height: 20),
          BigButton(
            label: l10n.pairInPersonJoinButton,
            icon: Icons.qr_code_scanner,
            tone: BigButtonTone.neutral,
            onPressed: onJoin,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.pairInPersonJoinSubtitle,
            textAlign: TextAlign.center,
            style: secondary,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ShowPane extends StatelessWidget {
  const _ShowPane({
    required this.step,
    required this.heading,
    required this.payload,
    required this.showText,
    required this.onToggleText,
    required this.doneLabel,
    required this.doneHint,
    required this.onDone,
  });

  final int step;
  final String heading;
  final String? payload; // null while the code is being made
  final bool showText;
  final VoidCallback onToggleText;
  final String doneLabel;
  final String doneHint;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = payload;
    if (code == null) return _Progress(text: l10n.pairInPersonPreparing);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return FillOrScroll(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _StepHeading(step: step, text: heading),
          const SizedBox(height: 16),
          if (showText) _CodeText(code: code) else _QrCode(code: code),
          TextButton(
            onPressed: onToggleText,
            child: Text(
              showText
                  ? l10n.pairInPersonShowAsQr
                  : l10n.pairInPersonShowAsText,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 8),
          Text(
            doneHint,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          BigButton(label: doneLabel, icon: Icons.check, onPressed: onDone),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _QrCode extends StatelessWidget {
  const _QrCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    // Sized from the screen, not a LayoutBuilder: this sits inside
    // FillOrScroll's IntrinsicHeight, which cannot measure a LayoutBuilder.
    final side = (MediaQuery.sizeOf(context).width - 48).clamp(160.0, 340.0);
    return Center(
      child: Container(
        width: side,
        height: side,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: QrImageView(
          data: code,
          version: QrVersions.auto,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(8),
          gapless: true,
          // Not the heading text: VoiceOver would read it twice.
          semanticsLabel: AppLocalizations.of(context).pairInPersonQrLabel,
        ),
      ),
    );
  }
}

class _CodeText extends StatelessWidget {
  const _CodeText({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            code,
            style: textTheme.bodyLarge?.copyWith(fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 8),
        BigButton(
          label: l10n.pairInPersonCopyCode,
          icon: Icons.copy,
          tone: BigButtonTone.neutral,
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            // Codes are public, but a code left on the clipboard could be
            // pasted into a later attempt and raise a false tamper alarm;
            // the self-clearing copy also matches every other copy path.
            final result = await SecureClipboard.copy(code);
            messenger.showSnackBar(
              SnackBar(
                content: Text(switch (result) {
                  SecureCopyResult.protected => l10n.pairInPersonCopiedSnackbar(
                    l10n.commonCopiedProtected,
                  ),
                  SecureCopyResult.plain => l10n.pairInPersonCopiedSnackbar(
                    l10n.commonCopiedPlain,
                  ),
                  SecureCopyResult.failed => l10n.commonCopyFailed,
                }),
                duration: const Duration(seconds: 6),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ScanPane extends StatelessWidget {
  const _ScanPane({
    required this.step,
    required this.heading,
    required this.hint,
    required this.onCode,
    required this.onPaste,
    required this.onShowAgain,
    required this.onCancel,
  });

  final int step;
  final String heading;
  final String? hint;
  final Future<String?> Function(String text) onCode;
  final VoidCallback onPaste;
  final VoidCallback? onShowAgain;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: _StepHeading(step: step, text: heading, compact: true),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: <Widget>[
                QrScannerView(
                  onCode: onCode,
                  onCancel: onCancel,
                  onUsePaste: onPaste,
                ),
                // Over the camera, never above it: at large text a hint in
                // the column pushed the camera off the screen. Capped and
                // scrollable so most of the viewfinder stays visible.
                if (hint != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.4,
                      ),
                      child: Material(
                        color: colors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              hint!,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: <Widget>[
            if (onShowAgain != null)
              TextButton(
                onPressed: onShowAgain,
                child: Text(l10n.pairInPersonShowAgainButton),
              ),
            TextButton(
              onPressed: onPaste,
              child: Text(l10n.pairInPersonPasteInstead),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _PastePane extends StatefulWidget {
  const _PastePane({
    required this.step,
    required this.submit,
    required this.noticeOf,
    required this.onBack,
  });

  final int step;
  final Future<void> Function(String text) submit;
  final PairingCodeError? Function() noticeOf;
  final VoidCallback onBack;

  @override
  State<_PastePane> createState() => _PastePaneState();
}

class _PastePaneState extends State<_PastePane> {
  final TextEditingController _controller = TextEditingController();
  // Only what this pane's own submit produced: a notice left by the camera
  // must not show as an error before anything was typed.
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    _controller.text = text;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() => _error = l10n.pairInPersonPasteEmptyError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await widget.submit(text);
    if (!mounted) return;
    final notice = widget.noticeOf();
    setState(() {
      _busy = false;
      _error = notice == null
          ? null
          : _PairExchangeScreenState.noticeText(notice, l10n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FillOrScroll(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _StepHeading(step: widget.step, text: l10n.pairInPersonPasteHeading),
          const SizedBox(height: 16),
          BigButton(
            label: l10n.pairInPersonPasteFromClipboard,
            icon: Icons.content_paste,
            tone: BigButtonTone.neutral,
            onPressed: _busy ? null : _pasteFromClipboard,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            autocorrect: false,
            enableSuggestions: false,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l10n.pairInPersonPasteLabel,
              errorText: _error,
              errorMaxLines: 6,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 16),
          BigButton(
            label: l10n.pairInPersonPasteSubmit,
            icon: Icons.check,
            onPressed: _busy ? null : _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : widget.onBack,
            child: Text(l10n.pairInPersonBackToCamera),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: !MediaQuery.supportsAnnounceOf(context),
              child: Text(text, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedPane extends StatelessWidget {
  const _FailedPane({required this.lines, required this.onStartOver});

  final List<String> lines;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return FillOrScroll(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            liveRegion: !MediaQuery.supportsAnnounceOf(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final (i, line) in lines.indexed) ...<Widget>[
                    if (i > 0) const SizedBox(height: 12),
                    Text(
                      line,
                      style:
                          (i == 0 ? textTheme.titleMedium : textTheme.bodyLarge)
                              ?.copyWith(color: colors.onErrorContainer),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(height: 24),
          BigButton(
            label: l10n.pairInPersonStartOverButton,
            icon: Icons.refresh,
            onPressed: onStartOver,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
