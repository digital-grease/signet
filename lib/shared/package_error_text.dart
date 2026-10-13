import '../core/crypto/transport_package.dart';
import '../l10n/app_localizations.dart';

/// User-facing text for a malformed or unreadable transport package.
///
/// Never shows [InvalidPackageException.message], which is English
/// developer text. A "needs a newer Signet" verdict that came from the
/// unauthenticated version or type byte (anyone can produce it without the
/// PAKE words) gets cautious copy that warns against update links and
/// files, because a scammer could send such a package and follow up with a
/// fake update. Only a verdict from inside the authenticated payload gets
/// the plain wording.
String packageErrorText(InvalidPackageException e, AppLocalizations l10n) {
  if (e is OutdatedPeerPackageException) {
    return l10n.packageFromOlderSignetError;
  }
  if (e is UnsupportedPackageVersionException) {
    return e.authenticated
        ? l10n.packageNeedsNewerSignetVerifiedError
        : l10n.packageNeedsNewerSignetError;
  }
  return l10n.packageDamagedError;
}

/// The "update Signet" text when [text] is a package from a newer Signet,
/// else null. Reads only the unencrypted header, so screens can say so as
/// soon as a package is pasted or loaded, before the user types 8 words
/// for nothing (plan Task 1.7j).
String? newerSignetPackageNotice(String text, AppLocalizations l10n) {
  try {
    TransportPackage.peekPayloadType(text.trim());
  } on UnsupportedPackageVersionException catch (e) {
    return packageErrorText(e, l10n);
  }
  return null;
}
