// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonAppTitle => 'SIGNET';

  @override
  String get commonOfflineFreeChip => 'OFFLINE-FREE';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonCancelCaps => 'CANCEL';

  @override
  String get commonDone => 'DONE';

  @override
  String get commonGotIt => 'GOT IT';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCopyPackage => 'Copy package';

  @override
  String get commonPackageCopiedSnackbar => 'Package copied to clipboard';

  @override
  String get commonSharePackage => 'Share package';

  @override
  String get commonIveSavedIt => 'I\'VE SAVED IT';

  @override
  String get commonStoreSeparatelyHeader => 'STORE THESE SEPARATELY //';

  @override
  String get commonRememberHeader => 'REMEMBER //';

  @override
  String get commonPakeSecretHeader => 'PAKE SECRET //';

  @override
  String get commonBackupPackageHeader => 'BACKUP PACKAGE //';

  @override
  String get commonPairTimePhraseHeader => 'PAIR-TIME PHRASE //';

  @override
  String get commonNameThisContactHeader => 'NAME THIS CONTACT //';

  @override
  String get commonNameHintExample => 'e.g. Alice';

  @override
  String get commonPasteFromClipboard => 'Paste from clipboard';

  @override
  String get commonUnlocking => 'UNLOCKING…';

  @override
  String get commonSaving => 'SAVING…';

  @override
  String get commonGenerating => 'GENERATING…';

  @override
  String get commonCommitPair => 'COMMIT PAIR';

  @override
  String get commonConfirmPairingTitle => 'CONFIRM PAIRING';

  @override
  String commonUnlockFailedError(String error) {
    return 'Could not unlock: $error';
  }

  @override
  String commonSaveFailedError(String error) {
    return 'Could not save: $error';
  }

  @override
  String get commonGiveContactName => 'Give this contact a name.';

  @override
  String get commonRelationshipNotFound => 'Relationship not found.';

  @override
  String get commonAirplaneFooter =>
      'AIRPLANE // NO NETWORK · NO TELEMETRY · STRONGBOX';

  @override
  String get homeHelpTooltip => 'Help';

  @override
  String get homeMoreTooltip => 'More';

  @override
  String get homeMenuFaq => 'FAQ';

  @override
  String get homeMenuContactUs => 'Contact us';

  @override
  String get homeMenuSettings => 'Settings';

  @override
  String get homeMenuShowIntro => 'Show intro again';

  @override
  String get homeMenuAbout => 'About';

  @override
  String homeErrorLoadFailed(String error) {
    return 'Could not read your paired contacts.\n$error';
  }

  @override
  String get homeTryAgainButton => 'TRY AGAIN';

  @override
  String get homeFabPair => 'PAIR';

  @override
  String get homeEmptyTitle => 'Nothing paired yet.';

  @override
  String get homeEmptyBody =>
      'Pair in person with someone you trust. You\'ll both be able to verify each other later over any call.';

  @override
  String get homeEmptyPairContactButton => 'PAIR CONTACT';

  @override
  String get homeEmptySendPackageButton => 'SEND A PACKAGE';

  @override
  String get homeEmptyHavePackageButton => 'I HAVE A PACKAGE';

  @override
  String get homeEmptyRestoreBackupButton => 'RESTORE FROM BACKUP';

  @override
  String get homeRenameDialogTitle => 'Rename peer';

  @override
  String get homeRenameFieldLabel => 'Peer name';

  @override
  String get homeRenameEmptyError => 'Name cannot be empty.';

  @override
  String get homeSaveButton => 'Save';

  @override
  String homeUnpairDialogTitle(String label) {
    return 'Unpair from $label?';
  }

  @override
  String get homeUnpairDialogBody =>
      'This deletes the shared secret on this device. To verify again you would need to pair from scratch.';

  @override
  String get homeUnpairConfirmButton => 'Unpair';

  @override
  String homeUnpairSnackbar(String label) {
    return 'Unpaired from $label.';
  }

  @override
  String get homeUndoAction => 'UNDO';

  @override
  String get homePairMenuInPerson => 'Pair in person';

  @override
  String get homePairMenuInPersonSubtitle =>
      'Both phones together, scan each other';

  @override
  String get homePairMenuSendPackage => 'Send a package';

  @override
  String get homePairMenuSendPackageSubtitle =>
      'Pair someone far away over a trusted channel';

  @override
  String get homePairMenuHavePackage => 'I have a package';

  @override
  String get homePairMenuHavePackageSubtitle =>
      'Import a package from someone else';

  @override
  String get homePairMenuRestoreBackup => 'Restore from backup';

  @override
  String get homePairMenuRestoreBackupSubtitle =>
      'Recover a paired contact from paper';

  @override
  String homeRowMenuRename(String label) {
    return 'Rename $label';
  }

  @override
  String get homeRowMenuHapticsOn => 'Turn haptics on';

  @override
  String get homeRowMenuHapticsOff => 'Turn haptics off';

  @override
  String get homeRowMenuShowBinding => 'Show binding phrase';

  @override
  String get homeRowMenuVerifyVideo => 'Verify (video call)';

  @override
  String get homeRowMenuVerifyVideoSubtitle =>
      'Adds a physical-action check — deepfake-resistant';

  @override
  String get homeRowMenuCrGrid => 'Challenge-response grid';

  @override
  String get homeRowMenuCrGridSubtitle =>
      'Fallback for when the other side has no phone';

  @override
  String homeRowMenuRekey(String label) {
    return 'Rekey $label';
  }

  @override
  String get homeRowMenuRekeySubtitle => 'Rotate the shared secret in person';

  @override
  String get homeRowMenuBackupPaper => 'Back up to paper';

  @override
  String get homeRowMenuBackupPaperSubtitle =>
      'Restore on a new phone if you lose this one';

  @override
  String homeRowMenuUnpair(String label) {
    return 'Unpair from $label';
  }

  @override
  String get homeDebugBannerSemantics =>
      'Debug logging is on. Double tap to manage in Settings.';

  @override
  String get homeDebugBannerText => 'DEBUG LOGGING ON — recording app activity';

  @override
  String get homeSectionRelationships => 'RELATIONSHIPS //';

  @override
  String homeRowMetadata(String role, String fingerprint, String date) {
    return 'role:$role · $fingerprint · $date';
  }

  @override
  String get homeHapticsOffChip => 'HAPTICS // OFF';

  @override
  String get aboutTitle => 'ABOUT';

  @override
  String get aboutSectionSignet => 'SIGNET';

  @override
  String get aboutIntroBody =>
      'Cryptographic multi-factor authentication for human relationships. Defends against voice and video deepfake vishing via device-to-device rotating codes. Zero server, offline-first.';

  @override
  String aboutVersionLabel(String version) {
    return 'Version: $version';
  }

  @override
  String get aboutSectionLicense => 'LICENSE';

  @override
  String get aboutLicenseBody =>
      'AGPL-3.0-only. Signet is free software; you are free to use, modify, and redistribute it under the terms of the GNU Affero General Public License version 3.';

  @override
  String get aboutSectionSource => 'SOURCE';

  @override
  String get aboutSourceBody =>
      'Source code, issue tracker, and release artifacts live on GitHub.';

  @override
  String get aboutOpenRepositoryButton => 'OPEN REPOSITORY';

  @override
  String get aboutSectionPrivacy => 'PRIVACY';

  @override
  String get aboutPrivacyBody =>
      'Signet collects nothing. It sends nothing. There is no server, no account, no telemetry.';

  @override
  String get aboutPrivacyPolicyButton => 'PRIVACY POLICY';

  @override
  String get aboutSectionReportBug => 'REPORT A BUG';

  @override
  String get aboutReportBugBody =>
      'Found a problem? File an issue on GitHub. Include the device, OS version, and the steps that triggered it.';

  @override
  String get aboutOpenIssuesButton => 'OPEN ISSUES';

  @override
  String get aboutSectionSupport => 'SUPPORT THE PROJECT';

  @override
  String get aboutSupportBody =>
      'If Signet is useful to you, consider buying me a coffee. Signet is solo-maintained, and there is no paid tier or upsell in the app. Support is optional and appreciated.';

  @override
  String get aboutBuyMeCoffeeButton => 'BUY ME A COFFEE';

  @override
  String get aboutCopyright => '© digital-grease';

  @override
  String get crashReportTitle => 'Signet had trouble';

  @override
  String get crashReportIntroBody =>
      'The app crashed during your last session. Sending the report helps us fix what happened.';

  @override
  String get crashReportContainsHeading => 'The report contains:';

  @override
  String get crashReportBulletDevice => 'Your device + OS + app version';

  @override
  String get crashReportBulletStack =>
      'A stack trace, with any cryptographic material (paired secrets, verify codes, backup payloads) replaced with [redacted:N] markers before it leaves your phone.';

  @override
  String get crashReportChooseHeading => 'Choose how to send it:';

  @override
  String get crashReportDismissButton => 'DISMISS';

  @override
  String get crashReportCopyLogButton => 'COPY LOG';

  @override
  String get crashReportFileIssueButton => 'FILE ISSUE';

  @override
  String get crashReportCopiedSnackbar => 'Crash log copied to clipboard.';

  @override
  String get crashReportOpenFailedSnackbar =>
      'Could not open the browser. The crash log has been copied to your clipboard so you can paste it manually.';

  @override
  String get crashReportTruncatedSnackbar =>
      'Trace was long — the full log is on your clipboard. Paste it below the truncation marker on GitHub.';

  @override
  String get faqTitle => 'FAQ';

  @override
  String get faqQ1 => 'What does Signet actually do?';

  @override
  String get faqA1 =>
      'Signet lets you confirm that a person calling, texting, or video-chatting you is who they say they are — even if they sound right, know biographical facts, and are asking for something urgent. You pair once, in person, with someone you trust. From then on, either of you can ask for a 4-word code that only the real paired device can produce.';

  @override
  String get faqQ2 => 'What does \"verified\" actually prove?';

  @override
  String get faqA2 =>
      'It proves the person on the other end has physical access to the phone you paired with, and that that phone hasn\'t been compromised. It does not prove their voice is real — a deepfake that can also compel someone to read a code off the real phone would still verify. Signet\'s job is to raise the attacker\'s cost from \'clone a voice\' to \'also physically steal an unlocked phone.\'';

  @override
  String get faqQ3 => 'Why does the 4-word code keep changing?';

  @override
  String get faqA3 =>
      'Each code is valid for 30 seconds. That way, even if an attacker records one code during a real call, they can\'t reuse it later. Signet accepts codes from the current window plus one before and one after, so a small clock mismatch or slow reader doesn\'t fail a legitimate verify.';

  @override
  String get faqQ4 => 'What if the codes don\'t match?';

  @override
  String get faqA4 =>
      'Treat it as a red flag. A real paired contact\'s code will almost always match on the first try. If it doesn\'t: hang up, reach the person through a separate channel you independently know (their known phone number, in person, a mutual friend), and confirm before acting on anything they asked for.';

  @override
  String get faqQ5 => 'Can Signet see my pairings or my codes?';

  @override
  String get faqA5 =>
      'No. Signet has no server, no account, no telemetry, no analytics. It doesn\'t ask for the internet permission on Android. Your shared secrets live in your phone\'s secure enclave (Keychain/Keystore) and don\'t leave the device. If Signet disappeared tomorrow, nothing of yours goes with it.';

  @override
  String get faqQ6 => 'What if I lose my phone?';

  @override
  String get faqA6 =>
      'If you set up a paper backup before losing it, you can restore the paired contact onto a new phone using the \"Restore from backup\" flow — your counterparty doesn\'t need to do anything, and doesn\'t even know a restore happened. If you didn\'t back up, the pairing is gone and you\'d need to re-pair in person with that contact on the new device.';

  @override
  String get faqQ7 => 'Can I pair with more than one person?';

  @override
  String get faqA7 =>
      'Yes. Add as many as you want — each pairing is independent. Every relationship gets its own secret; compromising one pairing doesn\'t reveal or affect any other.';

  @override
  String get faqQ8 => 'What\'s the challenge-response grid?';

  @override
  String get faqA8 =>
      'An offline fallback for when the other person can\'t reach their phone. Both of you have the same 8x8 grid of code words derived from your shared secret. You say \"what\'s the phrase for orange-anchor?\" — they look it up (in the app or on a printed card) and read you the three-word answer. If it matches what your app says, the pairing is genuine.';

  @override
  String get faqQ9 => 'Why does video-call verify ask for a physical action?';

  @override
  String get faqA9 =>
      'AI voice and video deepfakes keep getting better. A realtime deepfake that hears you ask for the 4 words can just say them — unless those words came from the paired device, which is why plain verify works. But a deepfake that hears you read a random prompt like \"touch your ear\" aloud can also mimic that action immediately. So Signet turns the action into something derived from the shared secret too: only the real paired device knows which action is expected in this window. When you turn on VIDEO CALL mode, passing requires BOTH the right 4 words AND the counterparty performing the expected action. A deepfake without the paired device can only guess, and the combined odds drop to roughly 1 in 100 trillion per 30-second window.';

  @override
  String get faqQ10 => 'Why no account? What if I need recovery?';

  @override
  String get faqA10 =>
      'An account means a server, a password, and a path an attacker (or a subpoena) can use to reach your pairings without touching your phone. Signet exists specifically because those paths exist for every other auth tool. Recovery is manual: export a paper backup now, while things are calm, and keep it somewhere you can reach if you lose the phone.';

  @override
  String get faqQ11 => 'Someone is asking me to skip the verify step.';

  @override
  String get faqA11 =>
      'Do not skip it. A real paired contact understands why verification exists and won\'t pressure you to bypass it. Urgency plus a request to skip verification is the exact pattern a scammer uses to short-circuit the safety net. If you\'re being pressured, assume the call is hostile until proven otherwise.';

  @override
  String get faqStillStuckHeader => 'STILL STUCK //';

  @override
  String get faqStillStuckBody =>
      'Didn\'t find your answer here? File an issue on GitHub. Include your device, OS version, and what you were trying to do.';

  @override
  String get faqContactUsButton => 'CONTACT US';

  @override
  String get onboardingSkipButton => 'SKIP';

  @override
  String get onboardingBriefingTag1 => 'BRIEFING // 01';

  @override
  String get onboardingBriefingTag2 => 'BRIEFING // 02';

  @override
  String get onboardingBriefingTag3 => 'BRIEFING // 03';

  @override
  String get onboardingSlide1Title => 'Verify who is on the line.';

  @override
  String get onboardingSlide1Body =>
      'Deepfake voice and video can sound like anyone — a family member, a colleague, a source. When someone calls with urgency, asking for money, for help, for access, Signet lets you ask for a rotating 4-word phrase only their real phone can produce. If the words match, you know.';

  @override
  String get onboardingSlide2Title => 'Pair once, in person.';

  @override
  String get onboardingSlide2Body =>
      'You pair two phones by scanning each other\'s QR codes while you\'re together. The shared secret stays on both devices — hardware-backed, offline, no cloud. Nothing to subpoena. Nothing to phish. Nothing to sync to a server that doesn\'t exist.';

  @override
  String get onboardingSlide3Title => 'Ask for the phrase.';

  @override
  String get onboardingSlide3Body =>
      'During the call, open Signet, tap the peer, ask them to read their 4 words. Type what you hear. Green banner = verified, trust the call. Red banner = do not trust it. Hang up and call back on a number you already know.';

  @override
  String get onboardingContinueButton => 'CONTINUE';

  @override
  String get pairStartTitle => 'Pair a contact';

  @override
  String get pairStartHeading => 'What\'s this person\'s name?';

  @override
  String get pairStartPrivacyNote =>
      'Only stored on your phone. Use whatever you will recognise at a glance — \"Mom\", \"Jake\", \"Finance Team\".';

  @override
  String get pairStartNameLabel => 'Name';

  @override
  String get pairStartEmptyNameError => 'Please enter a name for this contact.';

  @override
  String get pairStartContinueButton => 'Continue';

  @override
  String pairExchangeTitlePair(String contact) {
    return 'Pair with $contact';
  }

  @override
  String pairExchangeTitleRekey(String contact) {
    return 'Rekey with $contact';
  }

  @override
  String get pairExchangeFallbackContact => 'contact';

  @override
  String get pairExchangeIntro =>
      'Hold your phones together. Each of you needs to do both of these.';

  @override
  String get pairExchangeStep1Title => 'Show my QR';

  @override
  String get pairExchangeStep1Subtitle =>
      'Let the other person scan your code.';

  @override
  String get pairExchangeStep2Title => 'Scan their QR';

  @override
  String get pairExchangeStep2Subtitle => 'Point your camera at their code.';

  @override
  String get pairExchangeStep3Title => 'Paste string (dev)';

  @override
  String get pairExchangeStep3Subtitle =>
      'Two-emulator testing only. Bypasses the camera.';

  @override
  String get pairExchangeDerivingStatus => 'Deriving shared secret…';

  @override
  String get pairExchangeWaitingStatus => 'Waiting for both steps…';

  @override
  String get pairExchangeShowHeading => 'Let them scan this.';

  @override
  String get pairExchangeShowDoneButton => 'They scanned — I\'m done';

  @override
  String get pairExchangeCameraPermissionTitle =>
      'Camera permission is turned off.';

  @override
  String pairExchangeCameraPermissionBody(String path) {
    return 'Signet needs the camera only to scan pairing QR codes. Turn it on in your phone settings: $path.';
  }

  @override
  String get pairCameraSettingsPathIos => 'Settings → Signet → Camera';

  @override
  String get pairCameraSettingsPathAndroid =>
      'Apps → Signet → Permissions → Camera';

  @override
  String get pairExchangeDevHeading => 'Dev: paste-exchange';

  @override
  String get pairExchangeDevInstructions =>
      'Copy the \"Your string\" value into the other emulator\'s paste box, then paste theirs below.';

  @override
  String get pairExchangeDevYourString => 'Your string';

  @override
  String get pairExchangeDevCopyButton => 'Copy';

  @override
  String get pairExchangeDevCopiedSnackbar => 'Copied to clipboard';

  @override
  String get pairExchangeDevTheirString => 'Their string';

  @override
  String get pairExchangeDevSubmitButton => 'Submit';

  @override
  String get pairExchangeDevSubmittingButton => 'Submitting…';

  @override
  String get pairExchangePasteEmptyError =>
      'Paste the other device’s pairing string.';

  @override
  String get pairingErrorNotPairingQr =>
      'Not a Signet pairing QR (wrong scheme / version).';

  @override
  String pairingErrorBadPayloadLength(int actual) {
    return 'Decoded payload is $actual bytes, expected 32.';
  }

  @override
  String pairingErrorDecodeFailed(String error) {
    return 'Could not decode pairing QR: $error';
  }

  @override
  String pairingErrorBadKeyLength(int actual, int expected) {
    return 'Scanned key is $actual bytes; expected $expected.';
  }

  @override
  String pairingErrorDeriveFailed(String error) {
    return 'Failed to derive shared secret: $error';
  }

  @override
  String get pairConfirmTitle => 'Confirm';

  @override
  String get pairConfirmRekeyTitle => 'Confirm rekey';

  @override
  String get pairConfirmHeading => 'Does this match their screen?';

  @override
  String get pairConfirmInstructions =>
      'Read it out loud. All four words should be identical on both devices.';

  @override
  String get pairConfirmMatchButton => 'It matches';

  @override
  String get pairConfirmMismatchButton => 'No match — start over';

  @override
  String get pairConfirmMismatchDialogTitle => 'Phrases don’t match?';

  @override
  String get pairConfirmMismatchDialogBody =>
      'If your phrase and theirs don’t match, something went wrong — this could be a bad scan or someone trying to get in the middle. Safer to throw this pairing away and start over.';

  @override
  String get pairConfirmStartOverButton => 'Start over';

  @override
  String pairConfirmRekeySnackbar(String label) {
    return 'Rekeyed pairing with $label.';
  }

  @override
  String pairConfirmPairedSnackbar(String label) {
    return 'Paired with $label.';
  }

  @override
  String get pairConfirmStateIncompleteError => 'Pairing state is incomplete.';

  @override
  String get pairConfirmRekeyTargetMissingError =>
      'Relationship to rekey is no longer paired.';

  @override
  String get pairCompleteTitle => 'PAIRED';

  @override
  String get pairCompleteCommittedHeader => 'PAIR COMMITTED //';

  @override
  String get pairCompleteHeading =>
      'You\'re both still here.\nTry a verify now.';

  @override
  String pairCompletePracticeBody(String label) {
    return 'This is the easiest moment to practice. Ask $label to open Signet, tap your name, and read the 4 words on their Show-my-words screen. Type what you hear into your verify input. Once the green banner lands, you\'ll know it works for real.';
  }

  @override
  String get pairCompleteFallbackPeer => 'your peer';

  @override
  String get pairCompleteTipBody =>
      'Skip this and you can still verify any time from Home. But the cheapest practice run you will ever get is right now.';

  @override
  String pairCompleteVerifyNowButton(String label) {
    return 'VERIFY $label NOW';
  }

  @override
  String get pairCompleteSkipButton => 'SKIP — DO IT LATER';

  @override
  String get pairTransportInImportTitle => 'IMPORT PACKAGE';

  @override
  String get pairTransportInIncomingHeader => 'INCOMING PACKAGE //';

  @override
  String get pairTransportInPasteInstruction =>
      'Paste the text the sender gave you. Starts with \"signet:tp1:\".';

  @override
  String get pairTransportInPakeDescription =>
      'The 8 words the sender shared with you over a trusted channel (paper, encrypted email, a prior meeting note). Do not accept these words over an unverified voice call.';

  @override
  String get pairTransportInUnlockButton => 'UNLOCK PACKAGE';

  @override
  String get pairTransportInPasteEmptyError =>
      'Paste the package from the sender.';

  @override
  String get pairTransportInWordsIncompleteError =>
      'Enter all 8 words from the sender.';

  @override
  String pairTransportInProcessFailedError(String error) {
    return 'Failed to process package: $error';
  }

  @override
  String get pairTransportInPhraseInstruction =>
      'Ask the sender to confirm these 4 words appear on their screen, via the same trusted channel you used to share the PAKE secret. If they match, the package is authentic.';

  @override
  String get pairTransportInResponseHeader => 'YOUR RESPONSE //';

  @override
  String get pairTransportInResponseInstruction =>
      'Send this back to the sender, using the same channel you used to receive theirs. They will paste it to finish pairing.';

  @override
  String get pairTransportInCopyResponseButton => 'Copy response';

  @override
  String get pairTransportInResponseCopiedSnackbar =>
      'Response copied to clipboard';

  @override
  String get pairTransportOutNewPackageTitle => 'NEW PACKAGE';

  @override
  String get pairTransportOutShareWaitTitle => 'SHARE + WAIT';

  @override
  String get pairTransportOutNameDescription =>
      'The label that will appear on your home screen after pairing. The peer will see this as a hint when they import the package but can rename it on their side.';

  @override
  String get pairTransportOutGenerateButton => 'GENERATE PACKAGE';

  @override
  String pairTransportOutGenerateError(String error) {
    return 'Could not generate package: $error';
  }

  @override
  String get pairTransportOutOutgoingHeader => 'OUTGOING PACKAGE //';

  @override
  String pairTransportOutOutgoingInstruction(String label) {
    return 'Send this text to $label. Encrypted email, Signal, paper courier, printed QR — any channel is fine. Only useful to someone who also has the 8 PAKE words below.';
  }

  @override
  String get pairTransportOutCopyWordsButton => 'Copy words';

  @override
  String get pairTransportOutWordsCopiedSnackbar => 'PAKE words copied';

  @override
  String get pairTransportOutChannelWarning =>
      'Send the 8 words on a DIFFERENT channel than the package. Never over a fresh voice call. Paper, a prior-meeting fact, or another already-paired Signet relationship are all safer than speaking them aloud.';

  @override
  String get pairTransportOutReceiveHeader => 'RECEIVE RESPONSE //';

  @override
  String pairTransportOutReceiveInstruction(String label) {
    return '$label will send you a response package. Paste it here.';
  }

  @override
  String get pairTransportOutPasteEmptyError =>
      'Paste the response package from the receiver.';

  @override
  String get pairTransportOutUnlockResponseButton => 'UNLOCK RESPONSE';

  @override
  String pairTransportOutUnlockFailedError(String error) {
    return 'Could not unlock response: $error';
  }

  @override
  String pairTransportOutPhraseInstruction(String label) {
    return 'Ask $label to confirm these 4 words match their screen, via the same trusted channel you used for the PAKE secret. If they match, pairing is real.';
  }

  @override
  String get backupExportTitle => 'BACK UP TO PAPER';

  @override
  String backupExportGenerateError(String error) {
    return 'Could not generate backup: $error';
  }

  @override
  String backupExportHeading(String label) {
    return 'Back up $label';
  }

  @override
  String backupExportIntro(String label) {
    return 'Writing this down lets you restore this pairing on a new phone if you lose this one. $label\'s phone won\'t know anything changed.';
  }

  @override
  String get backupExportStoreSeparatelyBody =>
      'The PAKE secret and the backup package must live on different physical artifacts. If someone finds both, they can restore this pairing on their own phone. Paper in two places (home + safety deposit box) is a reasonable start. A password manager that syncs to a cloud is NOT.';

  @override
  String get backupExportWordsInstruction =>
      'Write these 8 words somewhere safe. You will type them into the new phone to unlock the package.';

  @override
  String get backupExportPackageInstruction =>
      'Scan this QR on the new phone, or copy-paste the text below. This is a different artifact from the PAKE secret above — do not store them together.';

  @override
  String backupExportShareSubject(String label) {
    return 'Signet backup - $label';
  }

  @override
  String backupExportRememberBody(String label) {
    return 'If this paper is ever found by someone else, UNPAIR $label immediately and re-pair in person. The backup contains the same shared secret your current pairing uses.';
  }

  @override
  String get backupImportRestoreTitle => 'RESTORE BACKUP';

  @override
  String get backupImportConfirmTitle => 'CONFIRM IMPORT';

  @override
  String get backupImportFileReadError => 'Could not read the selected file.';

  @override
  String backupImportFileReadFailedError(String error) {
    return 'Could not read the file: $error';
  }

  @override
  String backupImportInvalidFileError(String message) {
    return 'File is not a valid Signet backup: $message';
  }

  @override
  String get backupImportPasteEmptyError => 'Paste your backup package.';

  @override
  String get backupImportWordsIncompleteError =>
      'Enter the 8 PAKE words you stored separately.';

  @override
  String get backupImportNotBackupError => 'Not a valid Signet backup.';

  @override
  String get backupImportInvitationError =>
      'That\'s a pairing invitation, not a backup. Use the pair flow from Home.';

  @override
  String get backupImportClipboardEmptyError =>
      'Clipboard is empty. Copy your backup package first.';

  @override
  String get backupImportPasteInstruction =>
      'Paste the backup package from your paper. Starts with \"signet:tp1:\". If you scanned a QR, paste the text that came out.';

  @override
  String get backupImportLoadFromFileButton => 'Load from file';

  @override
  String get backupImportWordsInstruction =>
      'The 8 words from your paper or password manager — stored separately from the package above.';

  @override
  String get backupImportUnlockButton => 'UNLOCK BACKUP';

  @override
  String get backupImportRestoredPeerHeader => 'RESTORED PEER //';

  @override
  String get backupImportRoleLabel => 'ROLE //';

  @override
  String get backupImportOriginallyLabel => 'ORIGINALLY //';

  @override
  String get backupImportHapticsLabel => 'HAPTICS //';

  @override
  String get backupImportHapticsOff => 'OFF';

  @override
  String get backupImportHapticsOn => 'ON';

  @override
  String get backupImportWhatItDoesHeader => 'WHAT THIS DOES //';

  @override
  String backupImportWhatItDoesBody(String label) {
    return 'This phone will start sharing a secret with $label using the same key material as the old phone. $label\'s phone won\'t know anything changed. If they\'ve already rekeyed with someone else since your backup, verifies will fail until you re-pair in person.';
  }

  @override
  String get backupImportCommitButton => 'COMMIT IMPORT';

  @override
  String get bulkBackupExportSetupTitle => 'BACK UP EVERYTHING';

  @override
  String get bulkBackupExportReadyTitle => 'BULK BACKUP READY';

  @override
  String bulkBackupExportPrepareError(String error) {
    return 'Could not prepare backup: $error';
  }

  @override
  String get bulkBackupExportNoSecretsError =>
      'No relationships had retrievable secrets.';

  @override
  String get bulkBackupExportEmptyTitle => 'Nothing to back up yet.';

  @override
  String get bulkBackupExportEmptyBody =>
      'Pair with someone first, then come back here to create a bulk backup.';

  @override
  String bulkBackupExportReadyHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relationships',
      one: '1 relationship',
    );
    return 'Back up $_temp0';
  }

  @override
  String get bulkBackupExportReadyBody =>
      'Every paired contact below goes into one encrypted file with one 8-word PAKE. You store the file and the words separately, then use them to bring every pairing across to a new phone.';

  @override
  String get bulkBackupExportGenerateButton => 'GENERATE BULK BACKUP';

  @override
  String bulkBackupExportDoneHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relationships backed up',
      one: '1 relationship backed up',
    );
    return '$_temp0';
  }

  @override
  String get bulkBackupExportStoreSeparatelyBody =>
      'The PAKE secret and the backup package must live on different physical artifacts. If someone finds both, they can restore every pairing on their own phone. Paper in two places (home + safety deposit box) is a reasonable start. A password manager that syncs to a cloud is NOT.';

  @override
  String get bulkBackupExportWordsInstruction =>
      'Write these 8 words somewhere safe. You will type them into the new phone to unlock everything at once.';

  @override
  String get bulkBackupExportCopyPakeButton => 'Copy PAKE';

  @override
  String get bulkBackupExportPakeCopiedSnackbar =>
      'PAKE words copied to clipboard';

  @override
  String get bulkBackupExportPackageInstruction =>
      'The whole set of pairings, encrypted with the 8 words above. Share this via any channel — the words keep it sealed.';

  @override
  String bulkBackupExportShareLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relationships (bulk)',
      one: '1 relationship (bulk)',
    );
    return '$_temp0';
  }

  @override
  String bulkBackupExportShareSubject(int count) {
    return 'Signet bulk backup - $count peers';
  }

  @override
  String get bulkBackupExportRememberBody =>
      'If this file AND the 8 words are ever found by someone else, UNPAIR every relationship in it and re-pair in person. The backup contains the same shared secrets your current pairings use.';

  @override
  String get bulkBackupImportTitle => 'BULK RESTORE';

  @override
  String get bulkBackupImportDoneTitle => 'RESTORED';

  @override
  String bulkBackupImportGenericError(String error) {
    return 'Error: $error';
  }

  @override
  String bulkBackupImportPreviewHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relationships',
      one: '1 relationship',
    );
    return 'Restore $_temp0';
  }

  @override
  String get bulkBackupImportNoConflictBody =>
      'Tick the rows you want to restore. Every pairing below will come back with its original label and pair date.';

  @override
  String get bulkBackupImportConflictBody =>
      'Some of these labels are already paired on this phone. Choose what to do for each — default is skip.';

  @override
  String bulkBackupImportProgressText(int committed, int total) {
    return 'Restoring $committed of $total…';
  }

  @override
  String get bulkBackupImportRestoringButton => 'RESTORING…';

  @override
  String get bulkBackupImportNothingSelectedButton => 'NOTHING SELECTED';

  @override
  String bulkBackupImportRestoreButton(int count) {
    return 'RESTORE $count';
  }

  @override
  String get bulkBackupImportAlreadyPairedChip => 'ALREADY PAIRED';

  @override
  String get bulkBackupImportNoLabel => '(no label)';

  @override
  String bulkBackupImportRecordMeta(String role, String date) {
    return 'ROLE $role · PAIRED $date';
  }

  @override
  String get bulkBackupImportSkipOption =>
      'Skip — leave existing pairing alone';

  @override
  String bulkBackupImportRenameOption(String label) {
    return 'Rename restored copy to \"$label (restored)\"';
  }

  @override
  String get bulkBackupImportOverwriteOption => 'Overwrite existing pairing';

  @override
  String get bulkBackupImportCompleteHeading => 'Restore complete.';

  @override
  String get bulkBackupImportSummaryRestored => 'RESTORED //';

  @override
  String get bulkBackupImportSummaryRenamed => 'RENAMED //';

  @override
  String get bulkBackupImportSummaryOverwrote => 'OVERWROTE //';

  @override
  String get bulkBackupImportSummarySkipped => 'SKIPPED //';

  @override
  String get bulkBackupImportNothingChangedBody =>
      'Nothing was changed on this phone.';

  @override
  String get bulkBackupImportDoneBody =>
      'Each restored pairing uses the same shared secret as the old phone; their other side won\'t notice the restore unless they rekey.';

  @override
  String get bindingPhraseTitle => 'VERIFY BINDING';

  @override
  String get bindingPhraseLoadError => 'Could not read your pairing.';

  @override
  String bindingPhraseExplanation(String label) {
    return 'These 4 words were derived the moment you and $label paired. Ask $label to open Signet and tap this same screen. If the 4 words on both devices match, the pairing is intact.';
  }

  @override
  String get bindingPhraseMismatchHeader => 'IF THEY DO NOT MATCH //';

  @override
  String get bindingPhraseMismatchBody =>
      'Unpair and re-pair in person. Do not verify any calls against this pairing until you have.';

  @override
  String get bindingPhraseBackHomeButton => 'BACK TO HOME';

  @override
  String get crGridTitle => 'CHALLENGE-RESPONSE';

  @override
  String get crGridPrintTooltip => 'Print grid';

  @override
  String crGridLoadError(String error) {
    return 'Could not load grid: $error';
  }

  @override
  String crGridHeading(String label) {
    return 'Grid for $label';
  }

  @override
  String crGridFallbackExplanation(String label, String row, String col) {
    return 'When $label can\'t use their phone but can speak, use this grid as a fallback. You ask for a cell (e.g. \"$row × $col\"); they read the answer from the paper copy you both shared. Compare silently on your side.';
  }

  @override
  String get crGridFallbackNotice =>
      'This is a FALLBACK. If you can run a rotating-word verify, do that first — its defenses are stronger. Use this only when the responder has no phone.';

  @override
  String get crGridSectionHeader => 'GRID // 8×8 //';

  @override
  String crGridCellDialogTitle(String row, String col) {
    return '$row × $col';
  }

  @override
  String get crGridCloseButton => 'CLOSE';

  @override
  String crPdfDocTitle(String label) {
    return 'Signet challenge-response · $label';
  }

  @override
  String get crPdfCardTitle => 'SIGNET CHALLENGE-RESPONSE CARD';

  @override
  String get crPdfWarningTitle => 'TREAT THIS CARD LIKE A SAFE COMBINATION';

  @override
  String get crPdfWarningBody =>
      'Anyone who finds this card can answer challenges for this pairing. Challenge-response is a fallback - the rotating word verify in the app is still the stronger check for day-to-day calls. If you lose this card, unpair this relationship in the app and re-pair in person.';

  @override
  String get crPdfRowsHeader => 'ROWS //';

  @override
  String get crPdfColumnsHeader => 'COLUMNS //';

  @override
  String get crPdfFooter => 'Signet - challenge-response v1';

  @override
  String get settingsTitle => 'SETTINGS';

  @override
  String get settingsAppearanceSection => 'APPEARANCE';

  @override
  String get settingsAppearanceBody =>
      'Override the system theme. \"System\" follows your device; \"Dark\" and \"Light\" pin Signet regardless.';

  @override
  String get settingsThemeSystemLabel => 'SYSTEM';

  @override
  String get settingsThemeSystemSubtitle => 'Follow device theme';

  @override
  String get settingsThemeDarkLabel => 'DARK';

  @override
  String get settingsThemeDarkSubtitle => 'Operator default';

  @override
  String get settingsThemeLightLabel => 'LIGHT';

  @override
  String get settingsThemeLightSubtitle => 'High-contrast daylight';

  @override
  String get settingsBulkBackupSection => 'BULK BACKUP';

  @override
  String get settingsBulkBackupEmptyBody =>
      'No relationships paired yet. Pair with someone first, then you can back up every pairing at once.';

  @override
  String settingsBulkBackupBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relationships',
      one: '1 relationship',
    );
    return 'Back up all $_temp0 into one encrypted file with one 8-word PAKE. Use this when switching phones — the new phone unlocks every pairing in one step.';
  }

  @override
  String settingsBulkBackupAction(int count) {
    return 'BACK UP ALL $count';
  }

  @override
  String get settingsDebugSection => 'DEBUG LOGGING';

  @override
  String settingsDebugActiveBody(String expiry) {
    return 'Recording app activity to an encrypted file on this device. It auto-erases $expiry (or tap Stop). Export it to send a bug report — secrets are removed and contacts become tags like <peer-1> before it leaves your phone.';
  }

  @override
  String get settingsDebugInactiveBody =>
      'Off — nothing is recorded. If you hit a bug, turn this on, reproduce it, then export the log to send us. It never includes your secrets or your contacts\' names.';

  @override
  String get settingsDebugEnableAction => 'ENABLE DEBUG LOGGING';

  @override
  String get settingsDebugExportButton => 'EXPORT DEBUG LOGS';

  @override
  String get settingsDebugStopWipeButton => 'STOP & WIPE';

  @override
  String get settingsDebugNoLogSnackbar => 'No debug log captured yet.';

  @override
  String get settingsDebugExpiryIn24h => 'in 24h';

  @override
  String settingsDebugExpiryAt(String time, String date) {
    return 'at $time on $date';
  }

  @override
  String get settingsTourSection => 'GUIDED TOUR';

  @override
  String get settingsTourBody =>
      'Watch the first-run walkthrough again. Useful after a backup restore or if you want to re-read the pairing instructions.';

  @override
  String get settingsTourReplayAction => 'REPLAY INTRO';

  @override
  String get settingsAboutSection => 'ABOUT';

  @override
  String get settingsAboutBody =>
      'App version, license, source code, privacy policy, and support links.';

  @override
  String get settingsAboutOpenAction => 'OPEN ABOUT';

  @override
  String get settingsBulkConfirmTitle => 'BACK UP EVERYTHING?';

  @override
  String settingsBulkConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relationships',
      one: '1 relationship',
    );
    return 'This exports the shared secret for all $_temp0 into one file. Losing the 8-word PAKE means losing all $count backups. The PAKE will be shown once — write it down before closing the screen.';
  }

  @override
  String get settingsBulkConfirmContinue => 'CONTINUE';

  @override
  String get logExportTitle => 'EXPORT DEBUG LOG';

  @override
  String get logExportScrubNotice =>
      'Secrets are removed and your contacts are shown as tags like <peer-1>. The log still describes app behavior, so review it before sharing. If you file a GitHub issue, don\'t type a contact\'s name in the description box — that box is not scrubbed.';

  @override
  String get logExportFileIssueButton => 'FILE A GITHUB ISSUE';

  @override
  String get logExportShareButton => 'SHARE…';

  @override
  String get logExportCopyButton => 'COPY TO CLIPBOARD';

  @override
  String get logExportOpenFailedSnackbar =>
      'Couldn\'t open the browser — log copied instead.';

  @override
  String get logExportShareSubject => 'Signet debug log';

  @override
  String get logExportCopiedSnackbar => 'Debug log copied to clipboard.';

  @override
  String get verifyTitle => 'VERIFY';

  @override
  String get verifySectionChallenge => 'CHALLENGE //';

  @override
  String verifyAskForWordsHeading(String label) {
    return 'Ask $label for their 4 words.';
  }

  @override
  String get verifyTypeInstruction =>
      'Type what you hear. Tap a suggestion to fill a slot.';

  @override
  String get verifySectionInput => 'INPUT //';

  @override
  String get verifyFailHeader => 'IF VERIFY FAILS //';

  @override
  String get verifyFailHeading => 'Something is wrong with this call.';

  @override
  String get verifyFailStep1 =>
      'Hang up. Do not explain why. Do not argue. Do not agree to anything they\'re asking for.';

  @override
  String verifyFailStep2(String label) {
    return 'Call $label back on a number you have used before — saved in your contacts, written down, something you know. Do not use a number the caller gave you.';
  }

  @override
  String verifyFailStep3(String label) {
    return 'If $label does not answer, call a family member or someone close who can physically check on them. A real $label will never be upset that you checked.';
  }

  @override
  String verifyFailStep4(String label) {
    return 'If you are unsure whether Signet itself is broken: go to the home screen, tap \"SHOW BINDING PHRASE\", and compare with $label on a channel you trust. If the phrases match, Signet is working correctly and the red banner means the call was fake.';
  }

  @override
  String get verifyStatusOk => 'STATUS // 200 OK';

  @override
  String get verifyStatusFail => 'STATUS // 403 MISMATCH';

  @override
  String get verifyBannerVerified => 'VERIFIED';

  @override
  String get verifyBannerNotVerified => 'NOT VERIFIED — BE SUSPICIOUS';

  @override
  String get verifySublineVerifiedWithAction =>
      'Words matched AND you saw the expected physical action. You can trust this call.';

  @override
  String get verifySublineVerified =>
      'The words match. You can trust this call.';

  @override
  String get verifySublineWordsMismatch =>
      'The words did not match. Someone may be impersonating them.';

  @override
  String get verifySublineActionMismatch =>
      'Words matched but the physical action did not. Be suspicious and treat this as a failed verify.';

  @override
  String get verifyWhatShouldIDoButton => 'WHAT SHOULD I DO?';

  @override
  String get verifyVideoModeSemanticsLabel => 'Video call mode';

  @override
  String get verifyVideoModeSemanticsHint =>
      'Turn on to also check a physical action on video.';

  @override
  String get verifyVideoModeHeader => 'VIDEO CALL //';

  @override
  String get verifyVideoModeOnText =>
      'Request a physical action too. Defeats deepfakes.';

  @override
  String get verifyVideoModeOffText =>
      'Turn on to also check a physical action.';

  @override
  String get verifyWatchForHeader => 'WATCH FOR //';

  @override
  String verifyExpectedActionText(String label, String action) {
    return '$label should: $action.';
  }

  @override
  String verifyExpectedActionSemantics(String label, String action) {
    return 'Watch for: $label should $action.';
  }

  @override
  String get verifyActionHeader => 'ACTION //';

  @override
  String verifyActionJudgmentPrompt(String label, String action) {
    return 'Words ✅. Did you see $label: $action?';
  }

  @override
  String get verifyActionNotSeenButton => 'DID NOT SEE';

  @override
  String get verifyActionSeenButton => 'SAW IT';

  @override
  String get verifyShowMyWords => 'Show my 4 words';

  @override
  String verifyShowMyWordsSubtitle(String label) {
    return 'If $label wants to verify you, read these.';
  }

  @override
  String get verifyFlagSecureBadge => 'FLAG_SECURE';

  @override
  String verifyOwnActionWhile(String action) {
    return '...while $action.';
  }

  @override
  String get verifyGerundLookUp => 'looking up at the ceiling';

  @override
  String get verifyGerundLookDown => 'looking down at the floor';

  @override
  String get verifyGerundLookLeft => 'looking over your left shoulder';

  @override
  String get verifyGerundLookRight => 'looking over your right shoulder';

  @override
  String get verifyGerundTouchNose => 'touching the tip of your nose';

  @override
  String get verifyGerundTouchForehead => 'touching your forehead';

  @override
  String get verifyGerundTouchLeftEar => 'touching your left ear';

  @override
  String get verifyGerundTouchRightEar => 'touching your right ear';

  @override
  String get verifyActionLookUp => 'Look up at the ceiling';

  @override
  String get verifyActionLookDown => 'Look down at the floor';

  @override
  String get verifyActionLookLeft => 'Look over your left shoulder';

  @override
  String get verifyActionLookRight => 'Look over your right shoulder';

  @override
  String get verifyActionTouchNose => 'Touch the tip of your nose';

  @override
  String get verifyActionTouchForehead => 'Touch your forehead';

  @override
  String get verifyActionTouchLeftEar => 'Touch your left ear';

  @override
  String get verifyActionTouchRightEar => 'Touch your right ear';

  @override
  String get verifyLoadError => 'Could not read your paired contact.';

  @override
  String get verifyBackHomeButton => 'Back to home';

  @override
  String get wordInputClearAllButton => 'Clear all';

  @override
  String get wordInputChecking => 'Checking…';

  @override
  String wordInputSlotSemantics(int index, int total) {
    return 'Word $index of $total';
  }

  @override
  String get wordInputHint => 'word';

  @override
  String get wordInputInvalidWordError => 'Not a valid word';

  @override
  String get wordInputClearTooltip => 'Clear';

  @override
  String wordsDisplaySemantics(String words, int seconds) {
    return 'Verification phrase: $words, $seconds seconds remaining';
  }

  @override
  String wordsDisplayCountdown(int seconds) {
    return '$seconds s';
  }
}
