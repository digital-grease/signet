import 'package:flutter/material.dart';

/// Signet's visual language: "operator" — dark-mode-default, mono-forward,
/// sharp-cornered, HUD-influenced. Optimized for audiences who read a
/// secure-comms tool as a tool, not an app.
///
/// Tokens exposed here are the SOURCE OF TRUTH for Signet's colors. Screens
/// should prefer `Theme.of(context).colorScheme.*` wherever possible; direct
/// `SignetTokens.*` references are reserved for cases where Material 3's
/// scheme roles don't give us the right semantic (e.g. the verify success
/// banner wants a specific panel tone different from `primaryContainer`'s
/// derivation).
///
/// Fonts: we use system sans + platform `monospace` until IBM Plex Sans
/// and Plex Mono are bundled as asset fonts. The network-free constraint
/// (no `INTERNET` permission) rules out `google_fonts`' runtime fetch, so
/// bundling is a separate commit. Until then the layout/hierarchy reads
/// correct but feels slightly less distinctive than the final design will.
class SignetTokens {
  const SignetTokens._();

  // --- Neutrals (dark) -------------------------------------------------
  static const Color voidBg = Color(0xFF0A0C10);
  static const Color surface = Color(0xFF0F1114);
  static const Color panel = Color(0xFF1A1D22);
  static const Color border = Color(0xFF2A2D34);
  static const Color borderStrong = Color(0xFF3A3D44);
  static const Color muted = Color(0xFF8A8D93);
  static const Color ink = Color(0xFFE4E6EA);

  // --- Neutrals (light) -------------------------------------------------
  // Inversions are tuned — not pure white — to read correctly in daylight.
  static const Color voidBgL = Color(0xFFE8E9EC);
  static const Color surfaceL = Color(0xFFF2F3F6);
  static const Color panelL = Color(0xFFDEE0E5);
  static const Color borderL = Color(0xFFBFC2C9);
  static const Color borderStrongL = Color(0xFF9DA1A9);
  static const Color mutedL = Color(0xFF5A5D64);
  static const Color inkL = Color(0xFF0A0C10);

  // --- Semantic accents (same in both modes — meaning, not decoration) --
  /// Mint / GPS-fix / 200 OK.
  static const Color ok = Color(0xFF14B886);
  static const Color onOk = Color(0xFF0A0C10);

  /// Deep OK panel (dark mode).
  static const Color okBg = Color(0xFF0F2A21);
  /// Foreground copy on dark OK panel.
  static const Color okFg = Color(0xFF9BC3B6);

  /// Soft OK panel (light mode).
  static const Color okBgL = Color(0xFFD4EFE5);
  /// Foreground copy on light OK panel.
  static const Color okFgL = Color(0xFF0F5A44);

  /// Amber — attention / FLAG_SECURE / warn.
  static const Color warn = Color(0xFFD97706);

  /// Tactical red — fail / unverified / destructive.
  static const Color fail = Color(0xFFB91C1C);

  /// Deep FAIL panel (dark mode).
  static const Color failBg = Color(0xFF2A0F0F);
  /// Foreground copy on dark FAIL panel.
  static const Color failFg = Color(0xFFFCA5A5);

  /// Soft FAIL panel (light mode).
  static const Color failBgL = Color(0xFFF7D9D9);
  /// Foreground copy on light FAIL panel.
  static const Color failFgL = Color(0xFF7C0F0F);
}

/// Build the operator ThemeData for [dark] (true) or light (false) mode.
///
/// Non-default choices worth knowing about when reading consuming code:
/// - `FilledButton`s default to **sharp corners**, **64dp tall**, **15sp
///   uppercase label with 3.5 letter-spacing**. Every primary action in the
///   app inherits this without further styling.
/// - `OutlinedButton`s default to sharp corners, 48dp tall, 12sp uppercase
///   with 2.8 letter-spacing. Use for secondary actions (RELABEL, UNPAIR).
/// - `scaffoldBackgroundColor` is the `voidBg` token, one step darker than
///   `surface` — gives screens a subtle frame without heavy borders.
/// - `AppBar` title is 14sp 700-weight with 4.2 letter-spacing — meant to
///   render an uppercase wordmark like `SIGNET` cleanly.
/// - `TabBar` indicator uses `primary` (mint) with `tab` size so selected
///   tabs get a full mint underline; unselected tabs use `onSurfaceVariant`.
ThemeData signetTheme({required bool dark}) {
  final scheme = dark
      ? const ColorScheme.dark(
          primary: SignetTokens.ok,
          onPrimary: SignetTokens.onOk,
          secondary: SignetTokens.warn,
          onSecondary: SignetTokens.voidBg,
          surface: SignetTokens.surface,
          onSurface: SignetTokens.ink,
          surfaceContainerHighest: SignetTokens.panel,
          onSurfaceVariant: SignetTokens.muted,
          error: SignetTokens.fail,
          onError: SignetTokens.ink,
          errorContainer: SignetTokens.failBg,
          onErrorContainer: SignetTokens.failFg,
          outline: SignetTokens.borderStrong,
          outlineVariant: SignetTokens.border,
        )
      : const ColorScheme.light(
          primary: SignetTokens.ok,
          onPrimary: SignetTokens.onOk,
          secondary: SignetTokens.warn,
          onSecondary: SignetTokens.voidBgL,
          surface: SignetTokens.surfaceL,
          onSurface: SignetTokens.inkL,
          surfaceContainerHighest: SignetTokens.panelL,
          onSurfaceVariant: SignetTokens.mutedL,
          error: SignetTokens.fail,
          onError: SignetTokens.inkL,
          errorContainer: SignetTokens.failBgL,
          onErrorContainer: SignetTokens.failFgL,
          outline: SignetTokens.borderStrongL,
          outlineVariant: SignetTokens.borderL,
        );

  return ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: dark ? SignetTokens.voidBg : SignetTokens.voidBgL,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? SignetTokens.voidBg : SignetTokens.voidBgL,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 4.2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        minimumSize: const Size.fromHeight(64),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 3.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.8,
        ),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: scheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      side: BorderSide(color: scheme.outlineVariant, width: 1),
      backgroundColor: scheme.surface,
      labelStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: scheme.onSurface,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    ),
    visualDensity: VisualDensity.comfortable,
  );
}
