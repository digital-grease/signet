import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models/label_policy.dart';
import '../l10n/app_localizations.dart';

/// Localized text for a [LabelRejection].
String labelRejectionText(LabelRejection rejection, AppLocalizations l10n) =>
    switch (rejection) {
      LabelRejection.empty => l10n.labelRejectEmpty,
      LabelRejection.looksLikeData => l10n.labelRejectData,
      LabelRejection.looksLikeKey => l10n.labelRejectKey,
      LabelRejection.tooLong => l10n.labelRejectTooLong,
    };

/// Stops input at [maxBytes] UTF-8 bytes. Name limits are in bytes (what a
/// package or backup can carry), and a character-count `maxLength` lets a
/// Chinese name pass the field and then fail when encoded (plan Task 3.6,
/// P7).
///
/// An edit that does not make the text longer is always allowed, so a
/// name saved before this limit can still be shortened. Text that would go
/// over (a paste, a typed character) is cut at a whole character. Text
/// still being composed in an input method is left alone until it is
/// committed; callers check the length again before using the value.
class Utf8LengthLimitingTextInputFormatter extends TextInputFormatter {
  Utf8LengthLimitingTextInputFormatter(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newBytes = utf8.encode(newValue.text).length;
    if (newBytes <= maxBytes) return newValue;
    if (newBytes <= utf8.encode(oldValue.text).length) return newValue;
    if (newValue.composing.isValid) return newValue;
    // Already over the limit (a name saved before it): refuse the growth
    // rather than cutting the end off the existing name.
    if (utf8.encode(oldValue.text).length > maxBytes) return oldValue;
    final cut = LabelPolicy.truncateToBytes(newValue.text, maxBytes);
    return TextEditingValue(
      text: cut,
      selection: TextSelection.collapsed(offset: cut.length),
    );
  }
}

/// Field counter showing the bytes of [controller]'s text against
/// [maxBytes], for [TextField.buildCounter]. Shown only from three
/// quarters full: "6 / 64" next to a two-letter Chinese name would only
/// confuse.
InputCounterWidgetBuilder utf8ByteCounter(
  TextEditingController controller,
  int maxBytes,
) =>
    (
      BuildContext context, {
      required int currentLength,
      required bool isFocused,
      required int? maxLength,
    }) {
      final used = utf8.encode(controller.text).length;
      if (used * 4 < maxBytes * 3) return null;
      return Text(
        AppLocalizations.of(context).labelLengthCounter(used, maxBytes),
        style: Theme.of(context).textTheme.bodySmall,
      );
    };
