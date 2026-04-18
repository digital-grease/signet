// Theme-preview harness for Phase 9 Task 9.1.
//
// Run:
//   flutter run -t lib/dev/theme_preview_main.dart -d <device-id>
//
// This is a standalone preview app that hosts the proposed "operator"
// theme (dark + light variants) and renders mockup versions of the
// real screens so you can judge color, type, and spacing against a
// running Android build. Nothing here touches SecureStore or crypto;
// all labels and words are hard-coded for visual judgment only.
//
// Fonts: this preview uses the system default sans + the platform
// "monospace" family. When the theme is committed for real, we'll
// bundle IBM Plex Sans + Plex Mono as asset fonts (zero-network
// constraint forbids google_fonts runtime fetch) and swap them in
// via `fontFamily: 'PlexSans'` / `'PlexMono'`. The preview shows
// layout + color intent; final typography will feel slightly tighter
// and more distinctive once Plex is embedded.

import 'package:flutter/material.dart';

import '../core/theme/signet_theme.dart';

void main() {
  runApp(const _PreviewApp());
}

// Alias so existing inline references in this file stay readable.
typedef _Tokens = SignetTokens;

// ---------------- App shell ----------------

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();

  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signet / Operator Preview',
      debugShowCheckedModeBanner: false,
      theme: signetTheme(dark: false),
      darkTheme: signetTheme(dark: true),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('SIGNET'),
            actions: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    _dark ? 'DARK' : 'LIGHT',
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Switch(
                    value: _dark,
                    onChanged: (v) => setState(() => _dark = v),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Widget>[
                Tab(text: 'HOME / PAIRED'),
                Tab(text: 'HOME / EMPTY'),
                Tab(text: 'VERIFY / 200 OK'),
                Tab(text: 'VERIFY / 403 FAIL'),
                Tab(text: 'COMPONENTS'),
              ],
            ),
          ),
          body: const TabBarView(
            children: <Widget>[
              _HomePairedMock(),
              _HomeEmptyMock(),
              _VerifyOkMock(),
              _VerifyFailMock(),
              _ComponentsMock(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Shared primitives ----------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      _Tone.ok => scheme.primary,
      _Tone.warn => scheme.secondary,
      _Tone.fail => scheme.error,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: color,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

enum _Tone { ok, warn, fail }

class _MonoKV extends StatelessWidget {
  const _MonoKV({required this.k, required this.v});

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
          children: <TextSpan>[
            TextSpan(text: k.padRight(14)),
            TextSpan(
              text: v,
              style: TextStyle(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        '$label //',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: scheme.onSurfaceVariant,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------- Screens ----------------

class _HomePairedMock extends StatelessWidget {
  const _HomePairedMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Align(
              alignment: Alignment.centerRight,
              child: _StatusChip(label: 'OFFLINE-FREE', tone: _Tone.ok),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('PEER'),
            Text(
              'Mom',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 16),
            const _MonoKV(k: 'FINGERPRINT //', v: 'role:A · 4F:C2:91:A7'),
            const _MonoKV(k: 'BOUND //', v: '2026-02-14 15:03 UTC'),
            const _MonoKV(k: 'CIPHER //', v: 'HKDF-SHA256 · BIP39-4w'),
            const _MonoKV(k: 'LAST VERIFY //', v: '2026-04-17 · ✓'),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              child: const Text('VERIFY PEER'),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('RELABEL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error, width: 1),
                    ),
                    child: const Text('UNPAIR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEmptyMock extends StatelessWidget {
  const _HomeEmptyMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Spacer(),
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline, width: 2),
                ),
                child: Center(
                  child: Icon(
                    Icons.qr_code_2,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No peer bound.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pair in person with someone you trust. You\'ll both be able to verify each other later over any call or channel.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              child: const Text('PAIR PEER'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _VerifyOkMock extends StatelessWidget {
  const _VerifyOkMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Align(
              alignment: Alignment.centerRight,
              child: _StatusChip(label: 'OFFLINE-FREE', tone: _Tone.ok),
            ),
            const SizedBox(height: 20),
            const _SectionHeader('CHALLENGE'),
            Text(
              'Ask Mom for her 4 words.',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Type what you hear. Tap a suggestion to fill a slot.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _ResultBannerMock(
              ok: true,
              statusCode: '200 OK',
              headline: 'VERIFIED',
              subline: 'Words match. Trust this call.',
              bg: dark ? _Tokens.okBg : _Tokens.okBgL,
              fg: dark ? _Tokens.okFg : _Tokens.okFgL,
              accent: _Tokens.ok,
            ),
            const SizedBox(height: 24),
            const _SectionHeader('INPUT'),
            const _WordSlots(words: <String>['orbit', 'river', 'quick', 'brave']),
            const SizedBox(height: 16),
            const _SectionHeader('SUGGEST'),
            const Row(
              children: <Widget>[
                _ChipMock(label: 'orbit'),
                SizedBox(width: 8),
                _ChipMock(label: 'orbital'),
                SizedBox(width: 8),
                _ChipMock(label: 'orca'),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              color: scheme.surfaceContainerHighest,
              child: Row(
                children: <Widget>[
                  Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Show my 4 words',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    'FLAG_SECURE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: scheme.secondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'AIRPLANE // NO NETWORK · NO TELEMETRY · STRONGBOX',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyFailMock extends StatelessWidget {
  const _VerifyFailMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Align(
              alignment: Alignment.centerRight,
              child: _StatusChip(label: 'OFFLINE-FREE', tone: _Tone.ok),
            ),
            const SizedBox(height: 20),
            const _SectionHeader('CHALLENGE'),
            Text(
              'Ask Mom for her 4 words.',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            _ResultBannerMock(
              ok: false,
              statusCode: '403 MISMATCH',
              headline: 'NOT VERIFIED — BE SUSPICIOUS',
              subline: 'Words did not match. Someone may be impersonating them.',
              bg: dark ? _Tokens.failBg : _Tokens.failBgL,
              fg: dark ? _Tokens.failFg : _Tokens.failFgL,
              accent: _Tokens.fail,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
              ),
              child: const Text('WHAT SHOULD I DO?'),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('INPUT'),
            const _WordSlots(words: <String>['', '', '', '']),
            const SizedBox(height: 8),
            Text(
              'Slots cleared. Try again.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentsMock extends StatelessWidget {
  const _ComponentsMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _SectionHeader('TYPOGRAPHY'),
            Text('Display 36pt · Mom',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: scheme.onSurface)),
            Text('Title 22pt · Ask Mom for her 4 words.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: scheme.onSurface)),
            Text('Body 14pt · Type what you hear. Tap a suggestion.',
                style: TextStyle(fontSize: 14, color: scheme.onSurface)),
            Text('Caption 12pt · since 14 Feb 2026',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('MONO 11pt · role:A · 4F:C2:91:A7',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            const _SectionHeader('BUTTONS'),
            FilledButton(onPressed: () {}, child: const Text('VERIFY PEER')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () {}, child: const Text('RELABEL')),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
              ),
              child: const Text('UNPAIR'),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('STATUS CHIPS'),
            const Row(
              children: <Widget>[
                _StatusChip(label: 'OFFLINE-FREE', tone: _Tone.ok),
                SizedBox(width: 16),
                _StatusChip(label: 'FLAG_SECURE', tone: _Tone.warn),
                SizedBox(width: 16),
                _StatusChip(label: '403 MISMATCH', tone: _Tone.fail),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionHeader('INPUT SLOTS'),
            const _WordSlots(words: <String>['orbit', 'river', '', '']),
            const SizedBox(height: 24),
            const _SectionHeader('CHIPS'),
            const Row(
              children: <Widget>[
                _ChipMock(label: 'orbit'),
                SizedBox(width: 8),
                _ChipMock(label: 'orbital'),
                SizedBox(width: 8),
                _ChipMock(label: 'orca'),
                SizedBox(width: 8),
                _ChipMock(label: 'orchard'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Reusable widgets ----------------

class _ResultBannerMock extends StatelessWidget {
  const _ResultBannerMock({
    required this.ok,
    required this.statusCode,
    required this.headline,
    required this.subline,
    required this.bg,
    required this.fg,
    required this.accent,
  });

  final bool ok;
  final String statusCode;
  final String headline;
  final String subline;
  final Color bg;
  final Color fg;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(width: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'STATUS // $statusCode',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: accent,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    headline,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subline,
                    style: TextStyle(
                      fontSize: 13,
                      color: fg,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordSlots extends StatelessWidget {
  const _WordSlots({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        for (var i = 0; i < words.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                border: Border.all(color: scheme.outline, width: 1),
              ),
              child: Center(
                child: Text(
                  words[i],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChipMock extends StatelessWidget {
  const _ChipMock({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
