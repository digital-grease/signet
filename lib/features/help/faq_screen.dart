import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/signet_theme.dart';

/// FAQ — in-app answers to the questions that tend to come up during or
/// right after a pairing. Deliberately written for the "grandma test"
/// audience: no jargon, no crypto terminology unless the answer is
/// incomplete without it, one-paragraph answers where possible.
///
/// ExpansionTiles keep the screen scannable — the user sees the question
/// list first, opens only the one they want. No search box (28 questions
/// would justify one; 10 does not).
///
/// "Contact us" lives in the Home AppBar help menu, not here, so a user
/// who didn't find their answer has one obvious next step (file an issue)
/// without needing to backtrack through the FAQ.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const String _issuesUrl =
      'https://github.com/digital-grease/signet/issues';

  static const List<_FaqEntry> _entries = <_FaqEntry>[
    _FaqEntry(
      question: 'What does Signet actually do?',
      answer:
          'Signet lets you confirm that a person calling, texting, or '
          'video-chatting you is who they say they are — even if they '
          'sound right, know biographical facts, and are asking for '
          'something urgent. You pair once, in person, with someone you '
          'trust. From then on, either of you can ask for a 4-word code '
          'that only the real paired device can produce.',
    ),
    _FaqEntry(
      question: 'What does "verified" actually prove?',
      answer:
          'It proves the person on the other end has physical access to '
          "the phone you paired with, and that that phone hasn't been "
          'compromised. It does not prove their voice is real — a '
          'deepfake that can also compel someone to read a code off '
          "the real phone would still verify. Signet's job is to raise "
          "the attacker's cost from 'clone a voice' to 'also physically "
          "steal an unlocked phone.'",
    ),
    _FaqEntry(
      question: 'Why does the 4-word code keep changing?',
      answer:
          'Each code is valid for 30 seconds. That way, even if an '
          'attacker records one code during a real call, they can\'t '
          'reuse it later. Signet accepts codes from the current window '
          'plus one before and one after, so a small clock mismatch or '
          "slow reader doesn't fail a legitimate verify.",
    ),
    _FaqEntry(
      question: 'What if the codes don\'t match?',
      answer:
          'Treat it as a red flag. A real paired contact\'s code will '
          'almost always match on the first try. If it doesn\'t: hang up, '
          'reach the person through a separate channel you independently '
          'know (their known phone number, in person, a mutual friend), '
          'and confirm before acting on anything they asked for.',
    ),
    _FaqEntry(
      question: 'Can Signet see my pairings or my codes?',
      answer:
          'No. Signet has no server, no account, no telemetry, no '
          "analytics. It doesn't ask for the internet permission on "
          'Android. Your shared secrets live in your phone\'s secure '
          "enclave (Keychain/Keystore) and don't leave the device. If "
          'Signet disappeared tomorrow, nothing of yours goes with it.',
    ),
    _FaqEntry(
      question: 'What if I lose my phone?',
      answer:
          'If you set up a paper backup before losing it, you can '
          'restore the paired contact onto a new phone using the '
          '"Restore from backup" flow — your counterparty doesn\'t need '
          "to do anything, and doesn't even know a restore happened. If "
          "you didn't back up, the pairing is gone and you'd need to "
          're-pair in person with that contact on the new device.',
    ),
    _FaqEntry(
      question: 'Can I pair with more than one person?',
      answer:
          'Yes. Add as many as you want — each pairing is independent. '
          'Every relationship gets its own secret; compromising one '
          "pairing doesn't reveal or affect any other.",
    ),
    _FaqEntry(
      question: 'What\'s the challenge-response grid?',
      answer:
          'An offline fallback for when the other person can\'t reach '
          'their phone. Both of you have the same 8x8 grid of code '
          'words derived from your shared secret. You say "what\'s the '
          'phrase for orange-anchor?" — they look it up (in the app or '
          'on a printed card) and read you the three-word answer. If '
          'it matches what your app says, the pairing is genuine.',
    ),
    _FaqEntry(
      question: 'Why does video-call verify ask for a physical action?',
      answer:
          'AI voice and video deepfakes keep getting better. A realtime '
          'deepfake that hears you ask for the 4 words can just say them '
          '— unless those words came from the paired device, which is '
          'why plain verify works. But a deepfake that hears you read a '
          'random prompt like "touch your ear" aloud can also mimic '
          'that action immediately. So Signet turns the action into '
          'something derived from the shared secret too: only the real '
          'paired device knows which action is expected in this window. '
          'When you turn on VIDEO CALL mode, passing requires BOTH the '
          'right 4 words AND the counterparty performing the expected '
          'action. A deepfake without the paired device can only guess, '
          'and the combined odds drop to roughly 1 in 100 trillion per '
          '30-second window.',
    ),
    _FaqEntry(
      question: 'Why no account? What if I need recovery?',
      answer:
          'An account means a server, a password, and a path an attacker '
          '(or a subpoena) can use to reach your pairings without '
          'touching your phone. Signet exists specifically because those '
          'paths exist for every other auth tool. Recovery is manual: '
          'export a paper backup now, while things are calm, and keep '
          'it somewhere you can reach if you lose the phone.',
    ),
    _FaqEntry(
      question: 'Someone is asking me to skip the verify step.',
      answer:
          'Do not skip it. A real paired contact understands why '
          "verification exists and won't pressure you to bypass it. "
          'Urgency plus a request to skip verification is the exact '
          'pattern a scammer uses to short-circuit the safety net. If '
          'you\'re being pressured, assume the call is hostile until '
          'proven otherwise.',
    ),
  ];

  Future<void> _openIssues() async {
    final uri = Uri.parse(_issuesUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = isDark ? SignetTokens.panel : SignetTokens.panelL;
    final borderColor = isDark ? SignetTokens.border : SignetTokens.borderL;

    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          itemCount: _entries.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            if (i == _entries.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'STILL STUCK //',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Didn't find your answer here? File an issue on "
                      'GitHub. Include your device, OS version, and '
                      'what you were trying to do.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: _openIssues,
                        child: const Text('CONTACT US'),
                      ),
                    ),
                  ],
                ),
              );
            }
            final entry = _entries[i];
            return Container(
              decoration: BoxDecoration(
                color: panelColor,
                border: Border.all(color: borderColor),
              ),
              child: Theme(
                data: theme.copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Text(
                    entry.question,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        entry.answer,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FaqEntry {
  const _FaqEntry({required this.question, required this.answer});

  final String question;
  final String answer;
}
