import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// App name shown as the AppBar title on Home and Onboarding. Keep as-is in all locales.
  ///
  /// In en, this message translates to:
  /// **'SIGNET'**
  String get commonAppTitle;

  /// Status chip (dot + label) shown top-right on Home and Verify screens. Means the app works fully offline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE-FREE'**
  String get commonOfflineFreeChip;

  /// Title-case Cancel button in Material dialogs (Home rename/unpair dialogs, pair-confirm mismatch dialog) and the QR scanning pane.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// All-caps Cancel button used on operator-styled screens (backup import commit pane, bulk import, transport in/out confirm panes, Settings bulk-export confirm dialog).
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get commonCancelCaps;

  /// All-caps DONE button: Onboarding top-right on last page, bulk-import success pane.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get commonDone;

  /// All-caps GOT IT button: Onboarding last page and the verify-failure education bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'GOT IT'**
  String get commonGotIt;

  /// Title-case Back button inside the pair-exchange screen panes (show QR, camera permission, dev paste).
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Text button with copy icon: copies the backup/transport package wire text. Used on backup export, bulk export, transport out.
  ///
  /// In en, this message translates to:
  /// **'Copy package'**
  String get commonCopyPackage;

  /// Two-step backup export: first step header. Keep the ' //' operator styling.
  ///
  /// In en, this message translates to:
  /// **'STEP 1 // SAVE THE PACKAGE'**
  String get backupStep1Header;

  /// Two-step backup export: what the package is and where to keep it.
  ///
  /// In en, this message translates to:
  /// **'Save this package somewhere off this phone, such as your computer or a USB stick, or print the code. If the phone is lost, a copy kept on it is lost too. The package does not contain the 8 words, so on its own it cannot restore anything.'**
  String get backupStep1Body;

  /// Step 1 text for a bulk backup, which has no QR code.
  ///
  /// In en, this message translates to:
  /// **'Save this package somewhere off this phone, such as your computer or a USB stick. If the phone is lost, a copy kept on it is lost too. The package does not contain the 8 words, so on its own it cannot restore anything.'**
  String get backupStep1BodyNoQr;

  /// Opens the share sheet with the PACKAGE file (no words in it).
  ///
  /// In en, this message translates to:
  /// **'Save package file'**
  String get backupSavePackageFile;

  /// Marks step 1 done when the user saved the package without the buttons (for example printed or photographed the QR).
  ///
  /// In en, this message translates to:
  /// **'I saved it another way'**
  String get backupSavedAnotherWay;

  /// Two-step backup export: second step header. Keep the ' //' operator styling.
  ///
  /// In en, this message translates to:
  /// **'STEP 2 // KEEP THE 8 WORDS SOMEWHERE ELSE'**
  String get backupStep2Header;

  /// Shown in step 2 until step 1 is done; the words stay hidden until then.
  ///
  /// In en, this message translates to:
  /// **'Finish step 1 first. The 8 words appear here after the package is saved.'**
  String get backupStep2Locked;

  /// Two-step backup export: paper is the main way to keep the words.
  ///
  /// In en, this message translates to:
  /// **'Write these 8 words on paper, and the fingerprint below so you can tell which package they go with. Keep the paper away from the package, for example in your wallet. Anyone who has both can restore your pairings.'**
  String get backupStep2Body;

  /// Primary button in step 2: marks the words as saved on paper.
  ///
  /// In en, this message translates to:
  /// **'I wrote them on paper'**
  String get backupWroteOnPaper;

  /// Secondary button in step 2: opens the share sheet with the WORDS file (no package in it).
  ///
  /// In en, this message translates to:
  /// **'Save words file instead'**
  String get backupSaveWordsFile;

  /// Shown under the words-file button.
  ///
  /// In en, this message translates to:
  /// **'If you save the words as a file, put it somewhere different from the package: not the same folder, phone, or cloud account.'**
  String get backupWordsFileWarning;

  /// Six-digit fingerprint shared by the PACKAGE and WORDS files so they can be matched later.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint: {fingerprint} (the package and the words show the same one)'**
  String backupFingerprintLine(String fingerprint);

  /// Marker next to a finished step header.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get backupStepDone;

  /// Final button, enabled once both steps are done.
  ///
  /// In en, this message translates to:
  /// **'I\'VE SAVED BOTH'**
  String get backupSavedBoth;

  /// Snackbar when writing or sharing a backup file fails.
  ///
  /// In en, this message translates to:
  /// **'Could not open the share sheet. Try again.'**
  String get backupShareFailed;

  /// Snackbar after copying a package to the clipboard with timed clearing. On Android the clear runs only while Signet is open, hence the second clause.
  ///
  /// In en, this message translates to:
  /// **'Copied. Signet removes it from the clipboard after a minute, or when you next come back to Signet.'**
  String get commonCopiedProtected;

  /// Snackbar after a copy that Signet cannot clear later.
  ///
  /// In en, this message translates to:
  /// **'Copied to the clipboard.'**
  String get commonCopiedPlain;

  /// Snackbar when copying to the clipboard failed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy. Try again.'**
  String get commonCopyFailed;

  /// Snackbar after copying the backup package; copying alone does not finish step 1. {copied} is commonCopiedProtected or commonCopiedPlain.
  ///
  /// In en, this message translates to:
  /// **'{copied} Paste it somewhere off this phone now, then tap \"I saved it another way\".'**
  String backupPackageCopiedSnackbar(String copied);

  /// Red warning block headline on backup export and bulk export. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'STORE THESE SEPARATELY //'**
  String get commonStoreSeparatelyHeader;

  /// Secondary warning block headline on backup export and bulk export. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'REMEMBER //'**
  String get commonRememberHeader;

  /// Section header above the 8-word PAKE secret on export, import and transport screens. Keep the ' //' structure; PAKE stays untranslated.
  ///
  /// In en, this message translates to:
  /// **'PAKE SECRET //'**
  String get commonPakeSecretHeader;

  /// Section header above the 4-word phrase on binding phrase screen and transport in/out confirm panes. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'PAIR-TIME PHRASE //'**
  String get commonPairTimePhraseHeader;

  /// Section header above the contact-name field on transport in/out screens. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'NAME THIS CONTACT //'**
  String get commonNameThisContactHeader;

  /// TextField hintText for the contact name on transport in/out screens.
  ///
  /// In en, this message translates to:
  /// **'e.g. Alice'**
  String get commonNameHintExample;

  /// Text button with paste icon that reads the clipboard into the package input. Used on backup import and both transport screens.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get commonPasteFromClipboard;

  /// Disabled state of the unlock button while decryption runs (backup import, transport in/out).
  ///
  /// In en, this message translates to:
  /// **'UNLOCKING…'**
  String get commonUnlocking;

  /// Disabled state of the commit button while saving (backup import, transport in/out).
  ///
  /// In en, this message translates to:
  /// **'SAVING…'**
  String get commonSaving;

  /// Disabled state of the generate button (transport out setup, bulk backup export).
  ///
  /// In en, this message translates to:
  /// **'GENERATING…'**
  String get commonGenerating;

  /// Filled button that commits the long-distance pairing (transport in/out confirm pane).
  ///
  /// In en, this message translates to:
  /// **'COMMIT PAIR'**
  String get commonCommitPair;

  /// AppBar title of the confirm pane on both transport in and transport out screens.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PAIRING'**
  String get commonConfirmPairingTitle;

  /// Inline error when PAKE words are wrong / package undecryptable during unlock (backup import, transport in). Shows the underlying exception message.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock: {error}'**
  String commonUnlockFailedError(String error);

  /// Inline error / SnackBar when persisting a relationship fails (transport in/out, backup import). Shows the underlying exception message.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String commonSaveFailedError(String error);

  /// Shown when committing a pair or rekey hits a storage error. The save is journaled and may complete on next launch, so the user is told how to check rather than to re-pair immediately.
  ///
  /// In en, this message translates to:
  /// **'Signet couldn\'t finish saving this pairing. Close Signet and open it again. If the contact is on your list, it saved. If not, pair again together.'**
  String get pairConfirmSaveIncompleteError;

  /// Shown when committing a rekey hits a storage error. The contact stays listed either way, so the user is told to repeat the rekey (safe to repeat).
  ///
  /// In en, this message translates to:
  /// **'The rekey didn\'t finish. Do the rekey again on both phones before you rely on Signet to verify this contact.'**
  String get pairConfirmRekeySaveIncompleteError;

  /// Validation error shown when the contact-name field is empty on transport in/out.
  ///
  /// In en, this message translates to:
  /// **'Give this contact a name.'**
  String get commonGiveContactName;

  /// Error text shown (via an error wrapper) when the relationship id no longer resolves (backup export, challenge-response grid).
  ///
  /// In en, this message translates to:
  /// **'Relationship not found.'**
  String get commonRelationshipNotFound;

  /// Monospace reassurance footer at the bottom of binding phrase, verify and cr-grid screens. Keep the ' //' structure and the · separators.
  ///
  /// In en, this message translates to:
  /// **'AIRPLANE // NO NETWORK · NO TELEMETRY · STRONGBOX'**
  String get commonAirplaneFooter;

  /// Tooltip of the help icon (question mark) in the Home AppBar.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get homeHelpTooltip;

  /// Tooltip of the three-dot overflow menu in the Home AppBar.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get homeMoreTooltip;

  /// Help popup-menu item opening the FAQ screen.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get homeMenuFaq;

  /// Help popup-menu item opening the GitHub issues page in the browser.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get homeMenuContactUs;

  /// Overflow popup-menu item opening Settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeMenuSettings;

  /// Overflow popup-menu item reopening the onboarding walkthrough.
  ///
  /// In en, this message translates to:
  /// **'Show intro again'**
  String get homeMenuShowIntro;

  /// Overflow popup-menu item opening the About screen.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get homeMenuAbout;

  /// Body of the Home error state when the relationship list fails to load. Shows the underlying error.
  ///
  /// In en, this message translates to:
  /// **'Could not read your paired contacts.\n{error}'**
  String homeErrorLoadFailed(String error);

  /// Button on the Home error state that retries loading.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get homeTryAgainButton;

  /// Extended FloatingActionButton label on Home (visible when contacts exist). Opens the pairing options sheet.
  ///
  /// In en, this message translates to:
  /// **'PAIR'**
  String get homeFabPair;

  /// Large headline of the Home empty state.
  ///
  /// In en, this message translates to:
  /// **'Nothing paired yet.'**
  String get homeEmptyTitle;

  /// Explanatory body under the Home empty-state headline.
  ///
  /// In en, this message translates to:
  /// **'Pair in person with someone you trust. You\'ll both be able to verify each other later over any call.'**
  String get homeEmptyBody;

  /// Filled button on the empty state; starts the in-person pair flow.
  ///
  /// In en, this message translates to:
  /// **'PAIR CONTACT'**
  String get homeEmptyPairContactButton;

  /// Outlined button on the empty state; starts the long-distance sender flow.
  ///
  /// In en, this message translates to:
  /// **'SEND A PACKAGE'**
  String get homeEmptySendPackageButton;

  /// Outlined button on the empty state; starts the long-distance receiver flow.
  ///
  /// In en, this message translates to:
  /// **'I HAVE A PACKAGE'**
  String get homeEmptyHavePackageButton;

  /// Outlined button on the empty state; starts the backup restore flow.
  ///
  /// In en, this message translates to:
  /// **'RESTORE FROM BACKUP'**
  String get homeEmptyRestoreBackupButton;

  /// Title of the rename dialog opened from the long-press row menu.
  ///
  /// In en, this message translates to:
  /// **'Rename peer'**
  String get homeRenameDialogTitle;

  /// labelText of the TextField in the rename dialog.
  ///
  /// In en, this message translates to:
  /// **'Peer name'**
  String get homeRenameFieldLabel;

  /// errorText in the rename dialog when the trimmed name is empty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty.'**
  String get homeRenameEmptyError;

  /// Confirm button of the rename dialog.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get homeSaveButton;

  /// Title of the unpair confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Unpair from {label}?'**
  String homeUnpairDialogTitle(String label);

  /// Body of the unpair confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'This deletes the shared secret on this device. To verify again you would need to pair from scratch.'**
  String get homeUnpairDialogBody;

  /// Destructive confirm button of the unpair dialog.
  ///
  /// In en, this message translates to:
  /// **'Unpair'**
  String get homeUnpairConfirmButton;

  /// SnackBar after unpairing; carries an UNDO action.
  ///
  /// In en, this message translates to:
  /// **'Unpaired from {label}.'**
  String homeUnpairSnackbar(String label);

  /// SnackBar action label restoring the just-unpaired relationship.
  ///
  /// In en, this message translates to:
  /// **'UNDO'**
  String get homeUndoAction;

  /// Pairing bottom-sheet option; both phones together.
  ///
  /// In en, this message translates to:
  /// **'Pair in person'**
  String get homePairMenuInPerson;

  /// Subtitle of the in-person pairing sheet option.
  ///
  /// In en, this message translates to:
  /// **'Both phones together, scan each other'**
  String get homePairMenuInPersonSubtitle;

  /// Pairing bottom-sheet option; long-distance sender side.
  ///
  /// In en, this message translates to:
  /// **'Send a package'**
  String get homePairMenuSendPackage;

  /// Subtitle of the send-package sheet option.
  ///
  /// In en, this message translates to:
  /// **'Pair someone far away over a trusted channel'**
  String get homePairMenuSendPackageSubtitle;

  /// Pairing bottom-sheet option; long-distance receiver side.
  ///
  /// In en, this message translates to:
  /// **'I have a package'**
  String get homePairMenuHavePackage;

  /// Subtitle of the have-package sheet option.
  ///
  /// In en, this message translates to:
  /// **'Import a package from someone else'**
  String get homePairMenuHavePackageSubtitle;

  /// Pairing bottom-sheet option; opens backup restore.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get homePairMenuRestoreBackup;

  /// Subtitle of the restore-from-backup sheet option.
  ///
  /// In en, this message translates to:
  /// **'Recover a paired contact from paper'**
  String get homePairMenuRestoreBackupSubtitle;

  /// Long-press row menu item; opens the rename dialog.
  ///
  /// In en, this message translates to:
  /// **'Rename {label}'**
  String homeRowMenuRename(String label);

  /// Row menu item shown when silent haptics is currently off.
  ///
  /// In en, this message translates to:
  /// **'Turn haptics on'**
  String get homeRowMenuHapticsOn;

  /// Row menu item shown when silent haptics is currently on.
  ///
  /// In en, this message translates to:
  /// **'Turn haptics off'**
  String get homeRowMenuHapticsOff;

  /// Row menu item opening the binding-phrase screen.
  ///
  /// In en, this message translates to:
  /// **'Show binding phrase'**
  String get homeRowMenuShowBinding;

  /// Row menu item jumping into verify with video mode pre-enabled.
  ///
  /// In en, this message translates to:
  /// **'Verify (video call)'**
  String get homeRowMenuVerifyVideo;

  /// Subtitle of the verify (video call) row menu item.
  ///
  /// In en, this message translates to:
  /// **'Adds a physical-action check — deepfake-resistant'**
  String get homeRowMenuVerifyVideoSubtitle;

  /// Row menu item opening the challenge-response grid viewer.
  ///
  /// In en, this message translates to:
  /// **'Challenge-response grid'**
  String get homeRowMenuCrGrid;

  /// Subtitle of the challenge-response grid row menu item.
  ///
  /// In en, this message translates to:
  /// **'Fallback for when the other side has no phone'**
  String get homeRowMenuCrGridSubtitle;

  /// Row menu item starting the rekey (secret rotation) pair flow.
  ///
  /// In en, this message translates to:
  /// **'Rekey {label}'**
  String homeRowMenuRekey(String label);

  /// Subtitle of the rekey row menu item.
  ///
  /// In en, this message translates to:
  /// **'Rotate the shared secret in person'**
  String get homeRowMenuRekeySubtitle;

  /// Row menu item opening the paper backup export screen.
  ///
  /// In en, this message translates to:
  /// **'Back up to paper'**
  String get homeRowMenuBackupPaper;

  /// Subtitle of the back-up-to-paper row menu item.
  ///
  /// In en, this message translates to:
  /// **'Restore on a new phone if you lose this one'**
  String get homeRowMenuBackupPaperSubtitle;

  /// Destructive (red) row menu item opening the unpair confirmation.
  ///
  /// In en, this message translates to:
  /// **'Unpair from {label}'**
  String homeRowMenuUnpair(String label);

  /// Semantics live-region label of the persistent debug-recording banner on Home.
  ///
  /// In en, this message translates to:
  /// **'Debug logging is on. Double tap to manage in Settings.'**
  String get homeDebugBannerSemantics;

  /// Visible monospace text of the persistent debug-recording banner on Home.
  ///
  /// In en, this message translates to:
  /// **'DEBUG LOGGING ON — recording app activity'**
  String get homeDebugBannerText;

  /// Monospace section header above the paired-contact list on Home. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'RELATIONSHIPS //'**
  String get homeSectionRelationships;

  /// Small monospace metadata line under each contact row: wire role letter, fingerprint prefix, pairing date (yyyy-MM-dd).
  ///
  /// In en, this message translates to:
  /// **'role:{role} · {fingerprint} · {date}'**
  String homeRowMetadata(String role, String fingerprint, String date);

  /// Small chip under a contact row when silent haptics is enabled for it. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'HAPTICS // OFF'**
  String get homeHapticsOffChip;

  /// AppBar title of the About screen.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get aboutTitle;

  /// First section card title on About (app description).
  ///
  /// In en, this message translates to:
  /// **'SIGNET'**
  String get aboutSectionSignet;

  /// Body of the SIGNET section on About (app pitch, no version line).
  ///
  /// In en, this message translates to:
  /// **'Cryptographic multi-factor authentication for human relationships. Defends against voice and video deepfake vishing via device-to-device rotating codes. Zero server, offline-first.'**
  String get aboutIntroBody;

  /// Version line appended to the SIGNET section body on About.
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String aboutVersionLabel(String version);

  /// Section card title on About.
  ///
  /// In en, this message translates to:
  /// **'LICENSE'**
  String get aboutSectionLicense;

  /// Body of the LICENSE section on About.
  ///
  /// In en, this message translates to:
  /// **'AGPL-3.0-only. Signet is free software; you are free to use, modify, and redistribute it under the terms of the GNU Affero General Public License version 3.'**
  String get aboutLicenseBody;

  /// Section card title on About (source code).
  ///
  /// In en, this message translates to:
  /// **'SOURCE'**
  String get aboutSectionSource;

  /// Body of the SOURCE section on About.
  ///
  /// In en, this message translates to:
  /// **'Source code, issue tracker, and release artifacts live on GitHub.'**
  String get aboutSourceBody;

  /// Outlined button on the SOURCE section; opens the GitHub repo.
  ///
  /// In en, this message translates to:
  /// **'OPEN REPOSITORY'**
  String get aboutOpenRepositoryButton;

  /// Section card title on About.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get aboutSectionPrivacy;

  /// Body of the PRIVACY section on About.
  ///
  /// In en, this message translates to:
  /// **'Signet collects nothing. It sends nothing. There is no server, no account, no telemetry.'**
  String get aboutPrivacyBody;

  /// Outlined button on the PRIVACY section; opens PRIVACY.md.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY POLICY'**
  String get aboutPrivacyPolicyButton;

  /// Section card title on About.
  ///
  /// In en, this message translates to:
  /// **'REPORT A BUG'**
  String get aboutSectionReportBug;

  /// Body of the REPORT A BUG section on About.
  ///
  /// In en, this message translates to:
  /// **'Found a problem? File an issue on GitHub. Include the device, OS version, and the steps that triggered it.'**
  String get aboutReportBugBody;

  /// Outlined button on the REPORT A BUG section; opens the GitHub issue tracker.
  ///
  /// In en, this message translates to:
  /// **'OPEN ISSUES'**
  String get aboutOpenIssuesButton;

  /// Section card title on About (donation).
  ///
  /// In en, this message translates to:
  /// **'SUPPORT THE PROJECT'**
  String get aboutSectionSupport;

  /// Body of the SUPPORT THE PROJECT section on About.
  ///
  /// In en, this message translates to:
  /// **'If Signet is useful to you, consider buying me a coffee. Signet is solo-maintained, and there is no paid tier or upsell in the app. Support is optional and appreciated.'**
  String get aboutSupportBody;

  /// Highlighted filled button on the SUPPORT section; opens Buy Me a Coffee.
  ///
  /// In en, this message translates to:
  /// **'BUY ME A COFFEE'**
  String get aboutBuyMeCoffeeButton;

  /// Copyright line at the bottom of About. Author handle — keep untranslated.
  ///
  /// In en, this message translates to:
  /// **'© digital-grease'**
  String get aboutCopyright;

  /// AlertDialog title of the post-crash report dialog, shown in error color.
  ///
  /// In en, this message translates to:
  /// **'Signet had trouble'**
  String get crashReportTitle;

  /// First paragraph of the crash report dialog content.
  ///
  /// In en, this message translates to:
  /// **'The app crashed during your last session. Sending the report helps us fix what happened.'**
  String get crashReportIntroBody;

  /// Bold lead-in before the bullet list in the crash report dialog.
  ///
  /// In en, this message translates to:
  /// **'The report contains:'**
  String get crashReportContainsHeading;

  /// First bullet in the crash report dialog.
  ///
  /// In en, this message translates to:
  /// **'Your device + OS + app version'**
  String get crashReportBulletDevice;

  /// Second bullet in the crash report dialog explaining scrubbing. [redacted:N] is a literal marker — keep as-is.
  ///
  /// In en, this message translates to:
  /// **'A stack trace, with any cryptographic material (paired secrets, verify codes, backup payloads) replaced with [redacted:N] markers before it leaves your phone.'**
  String get crashReportBulletStack;

  /// Bold lead-in before the action buttons in the crash report dialog.
  ///
  /// In en, this message translates to:
  /// **'Choose how to send it:'**
  String get crashReportChooseHeading;

  /// TextButton closing the crash report dialog without sending.
  ///
  /// In en, this message translates to:
  /// **'DISMISS'**
  String get crashReportDismissButton;

  /// TextButton copying the scrubbed crash trace to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'COPY LOG'**
  String get crashReportCopyLogButton;

  /// FilledButton opening the pre-filled GitHub crash-report issue.
  ///
  /// In en, this message translates to:
  /// **'FILE ISSUE'**
  String get crashReportFileIssueButton;

  /// SnackBar after copying the crash log.
  ///
  /// In en, this message translates to:
  /// **'Crash log copied to clipboard.'**
  String get crashReportCopiedSnackbar;

  /// SnackBar when the browser could not be launched for the crash report.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser. The crash log has been copied to your clipboard so you can paste it manually.'**
  String get crashReportOpenFailedSnackbar;

  /// SnackBar when the crash-report URL was truncated and the full trace was placed on the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Trace was long — the full log is on your clipboard. Paste it below the truncation marker on GitHub.'**
  String get crashReportTruncatedSnackbar;

  /// AppBar title of the FAQ screen.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faqTitle;

  /// FAQ question 1 (expansion tile title).
  ///
  /// In en, this message translates to:
  /// **'What does Signet actually do?'**
  String get faqQ1;

  /// FAQ answer 1.
  ///
  /// In en, this message translates to:
  /// **'Signet lets you confirm that a person calling, texting, or video-chatting you is who they say they are — even if they sound right, know biographical facts, and are asking for something urgent. You pair once, in person, with someone you trust. From then on, either of you can ask for a 4-word code that only the real paired device can produce.'**
  String get faqA1;

  /// FAQ question 2.
  ///
  /// In en, this message translates to:
  /// **'What does \"verified\" actually prove?'**
  String get faqQ2;

  /// FAQ answer 2.
  ///
  /// In en, this message translates to:
  /// **'It proves the person on the other end has physical access to the phone you paired with, and that that phone hasn\'t been compromised. It does not prove their voice is real — a deepfake that can also compel someone to read a code off the real phone would still verify. Signet\'s job is to raise the attacker\'s cost from \'clone a voice\' to \'also physically steal an unlocked phone.\''**
  String get faqA2;

  /// FAQ question 3.
  ///
  /// In en, this message translates to:
  /// **'Why does the 4-word code keep changing?'**
  String get faqQ3;

  /// FAQ answer 3.
  ///
  /// In en, this message translates to:
  /// **'Each code is valid for 30 seconds. That way, even if an attacker records one code during a real call, they can\'t reuse it later. Signet accepts codes from the current window plus one before and one after, so a small clock mismatch or slow reader doesn\'t fail a legitimate verify.'**
  String get faqA3;

  /// FAQ question 4.
  ///
  /// In en, this message translates to:
  /// **'What if the codes don\'t match?'**
  String get faqQ4;

  /// FAQ answer 4.
  ///
  /// In en, this message translates to:
  /// **'Treat it as a red flag. A real paired contact\'s code will almost always match on the first try. If it doesn\'t: hang up, reach the person through a separate channel you independently know (their known phone number, in person, a mutual friend), and confirm before acting on anything they asked for.'**
  String get faqA4;

  /// FAQ question 5.
  ///
  /// In en, this message translates to:
  /// **'Can Signet see my pairings or my codes?'**
  String get faqQ5;

  /// FAQ answer 5.
  ///
  /// In en, this message translates to:
  /// **'No. Signet has no server, no account, no telemetry, no analytics. It doesn\'t ask for the internet permission on Android. Your shared secrets live in your phone\'s secure enclave (Keychain/Keystore) and don\'t leave the device. If Signet disappeared tomorrow, nothing of yours goes with it.'**
  String get faqA5;

  /// FAQ question 6.
  ///
  /// In en, this message translates to:
  /// **'What if I lose my phone?'**
  String get faqQ6;

  /// FAQ answer 6.
  ///
  /// In en, this message translates to:
  /// **'If you made a backup before losing it, you can restore the paired contact onto a new phone with \"Restore from backup\". Your counterparty doesn\'t need to do anything, and doesn\'t even know a restore happened. If you didn\'t back up, the pairing is gone and you\'d need to re-pair in person with that contact on the new device.'**
  String get faqA6;

  /// FAQ question about storing the two backup parts.
  ///
  /// In en, this message translates to:
  /// **'How do I keep a backup safe?'**
  String get faqQ12;

  /// FAQ answer about storing the two backup parts.
  ///
  /// In en, this message translates to:
  /// **'A backup has two parts: a PACKAGE file, which is locked, and 8 words, which unlock it. Keep them apart. Save the PACKAGE file off the phone, for example on your computer or a USB stick. Write the 8 words on paper and keep the paper somewhere else, like your wallet. Anyone who finds both parts can impersonate you to your contacts, so never keep them together and never send the words in a message. To restore, tap Restore from backup, load the PACKAGE file, then type the 8 words.'**
  String get faqA12;

  /// FAQ question 7.
  ///
  /// In en, this message translates to:
  /// **'Can I pair with more than one person?'**
  String get faqQ7;

  /// FAQ answer 7.
  ///
  /// In en, this message translates to:
  /// **'Yes. Add as many as you want — each pairing is independent. Every relationship gets its own secret; compromising one pairing doesn\'t reveal or affect any other.'**
  String get faqA7;

  /// FAQ question 8.
  ///
  /// In en, this message translates to:
  /// **'What\'s the challenge-response grid?'**
  String get faqQ8;

  /// FAQ answer 8.
  ///
  /// In en, this message translates to:
  /// **'An offline fallback for when the other person can\'t reach their phone. Both of you have the same 8x8 grid of code words derived from your shared secret. You say \"what\'s the phrase for orange-anchor?\" — they look it up (in the app or on a printed card) and read you the three-word answer. If it matches what your app says, the pairing is genuine.'**
  String get faqA8;

  /// FAQ question 9.
  ///
  /// In en, this message translates to:
  /// **'Why does video-call verify ask for a physical action?'**
  String get faqQ9;

  /// FAQ answer 9. 'VIDEO CALL' refers to the on-screen toggle label.
  ///
  /// In en, this message translates to:
  /// **'AI voice and video deepfakes keep getting better. A realtime deepfake that hears you ask for the 4 words can just say them — unless those words came from the paired device, which is why plain verify works. But a deepfake that hears you read a random prompt like \"touch your ear\" aloud can also mimic that action immediately. So Signet turns the action into something derived from the shared secret too: only the real paired device knows which action is expected in this window. When you turn on VIDEO CALL mode, passing requires BOTH the right 4 words AND the counterparty performing the expected action. A deepfake without the paired device can only guess, and the combined odds drop to roughly 1 in 100 trillion per 30-second window.'**
  String get faqA9;

  /// FAQ question 10.
  ///
  /// In en, this message translates to:
  /// **'Why no account? What if I need recovery?'**
  String get faqQ10;

  /// FAQ answer 10.
  ///
  /// In en, this message translates to:
  /// **'An account means a server, a password, and a path an attacker (or a subpoena) can use to reach your pairings without touching your phone. Signet exists specifically because those paths exist for every other auth tool. Recovery is manual: make a backup now, while things are calm, and keep it somewhere you can reach if you lose the phone.'**
  String get faqA10;

  /// FAQ question 11.
  ///
  /// In en, this message translates to:
  /// **'Someone is asking me to skip the verify step.'**
  String get faqQ11;

  /// FAQ answer 11.
  ///
  /// In en, this message translates to:
  /// **'Do not skip it. A real paired contact understands why verification exists and won\'t pressure you to bypass it. Urgency plus a request to skip verification is the exact pattern a scammer uses to short-circuit the safety net. If you\'re being pressured, assume the call is hostile until proven otherwise.'**
  String get faqA11;

  /// Monospace headline above the issue-filing block at the end of the FAQ. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'STILL STUCK //'**
  String get faqStillStuckHeader;

  /// Body text of the still-stuck block at the end of the FAQ.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t find your answer here? File an issue on GitHub. Include your device, OS version, and what you were trying to do.'**
  String get faqStillStuckBody;

  /// Outlined button at the end of the FAQ; opens the GitHub issue tracker.
  ///
  /// In en, this message translates to:
  /// **'CONTACT US'**
  String get faqContactUsButton;

  /// AppBar TextButton on Onboarding while not on the last page; finishes the walkthrough immediately.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get onboardingSkipButton;

  /// Monospace section tag on onboarding slide 1. Keep the ' //' structure and the 01 numbering.
  ///
  /// In en, this message translates to:
  /// **'BRIEFING // 01'**
  String get onboardingBriefingTag1;

  /// Section tag on onboarding slide 2.
  ///
  /// In en, this message translates to:
  /// **'BRIEFING // 02'**
  String get onboardingBriefingTag2;

  /// Section tag on onboarding slide 3.
  ///
  /// In en, this message translates to:
  /// **'BRIEFING // 03'**
  String get onboardingBriefingTag3;

  /// Headline of onboarding slide 1 (what Signet is for).
  ///
  /// In en, this message translates to:
  /// **'Verify who is on the line.'**
  String get onboardingSlide1Title;

  /// Body of onboarding slide 1.
  ///
  /// In en, this message translates to:
  /// **'Deepfake voice and video can sound like anyone — a family member, a colleague, a source. When someone calls with urgency, asking for money, for help, for access, Signet lets you ask for a rotating 4-word phrase only their real phone can produce. If the words match, you know.'**
  String get onboardingSlide1Body;

  /// Headline of onboarding slide 2 (how pairing works).
  ///
  /// In en, this message translates to:
  /// **'Pair once, in person.'**
  String get onboardingSlide2Title;

  /// Body of onboarding slide 2.
  ///
  /// In en, this message translates to:
  /// **'You pair two phones by scanning each other\'s QR codes while you\'re together. The shared secret stays on both devices — hardware-backed, offline, no cloud. Nothing to subpoena. Nothing to phish. Nothing to sync to a server that doesn\'t exist.'**
  String get onboardingSlide2Body;

  /// Headline of onboarding slide 3 (how to verify a call).
  ///
  /// In en, this message translates to:
  /// **'Ask for the phrase.'**
  String get onboardingSlide3Title;

  /// Body of onboarding slide 3.
  ///
  /// In en, this message translates to:
  /// **'During the call, open Signet, tap the peer, ask them to read their 4 words. Type what you hear. Green banner = verified, trust the call. Red banner = do not trust it. Hang up and call back on a number you already know.'**
  String get onboardingSlide3Body;

  /// Bottom filled button on Onboarding while not on the last page.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get onboardingContinueButton;

  /// AppBar title of pair step 1 (naming the contact).
  ///
  /// In en, this message translates to:
  /// **'Pair a contact'**
  String get pairStartTitle;

  /// Headline question on the pair-start screen.
  ///
  /// In en, this message translates to:
  /// **'What\'s this person\'s name?'**
  String get pairStartHeading;

  /// Explanatory text under the pair-start headline; example names are illustrative.
  ///
  /// In en, this message translates to:
  /// **'Only stored on your phone. Use whatever you will recognise at a glance — \"Mom\", \"Jake\", \"Finance Team\".'**
  String get pairStartPrivacyNote;

  /// labelText of the name field on pair start.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pairStartNameLabel;

  /// Validation error when continuing with an empty name on pair start.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name for this contact.'**
  String get pairStartEmptyNameError;

  /// BigButton advancing to the QR exchange step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get pairStartContinueButton;

  /// AppBar title of the QR exchange screen during a fresh pairing.
  ///
  /// In en, this message translates to:
  /// **'Pair with {contact}'**
  String pairExchangeTitlePair(String contact);

  /// AppBar title of the QR exchange screen during a rekey.
  ///
  /// In en, this message translates to:
  /// **'Rekey with {contact}'**
  String pairExchangeTitleRekey(String contact);

  /// Fallback word in the exchange AppBar title when no label has been set yet ('Pair with contact').
  ///
  /// In en, this message translates to:
  /// **'contact'**
  String get pairExchangeFallbackContact;

  /// Intro line at the top of the exchange overview pane.
  ///
  /// In en, this message translates to:
  /// **'Hold your phones together, in the same room. Each of you needs to do both of these. Only scan the other phone itself, never a photo or a video call: those codes can be swapped.'**
  String get pairExchangeIntro;

  /// Step card 1 title: display my pairing QR.
  ///
  /// In en, this message translates to:
  /// **'Show my QR'**
  String get pairExchangeStep1Title;

  /// Step card 1 subtitle.
  ///
  /// In en, this message translates to:
  /// **'Let the other person scan your code.'**
  String get pairExchangeStep1Subtitle;

  /// Step card 2 title: scan the other device's QR.
  ///
  /// In en, this message translates to:
  /// **'Scan their QR'**
  String get pairExchangeStep2Title;

  /// Step card 2 subtitle.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at their code.'**
  String get pairExchangeStep2Subtitle;

  /// Dev-only step card 3 title (paste-exchange pane, compile-time flag).
  ///
  /// In en, this message translates to:
  /// **'Paste string (dev)'**
  String get pairExchangeStep3Title;

  /// Dev-only step card 3 subtitle.
  ///
  /// In en, this message translates to:
  /// **'Two-emulator testing only. Bypasses the camera.'**
  String get pairExchangeStep3Subtitle;

  /// Status line under the step cards once both steps are complete.
  ///
  /// In en, this message translates to:
  /// **'Deriving shared secret…'**
  String get pairExchangeDerivingStatus;

  /// Status line under the step cards while steps are incomplete.
  ///
  /// In en, this message translates to:
  /// **'Waiting for both steps…'**
  String get pairExchangeWaitingStatus;

  /// Headline above the fullscreen pairing QR.
  ///
  /// In en, this message translates to:
  /// **'Let them scan this.'**
  String get pairExchangeShowHeading;

  /// BigButton under the QR confirming the other side has scanned.
  ///
  /// In en, this message translates to:
  /// **'They scanned — I\'m done'**
  String get pairExchangeShowDoneButton;

  /// Title of the camera-permission-denied pane.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is turned off.'**
  String get pairExchangeCameraPermissionTitle;

  /// Body of the permission-denied pane; {path} is the OS settings path.
  ///
  /// In en, this message translates to:
  /// **'Signet needs the camera only to scan pairing QR codes. Turn it on in your phone settings: {path}.'**
  String pairExchangeCameraPermissionBody(String path);

  /// iOS per-app camera settings path, interpolated into the permission body.
  ///
  /// In en, this message translates to:
  /// **'Settings → Signet → Camera'**
  String get pairCameraSettingsPathIos;

  /// Android per-app camera settings path, interpolated into the permission body.
  ///
  /// In en, this message translates to:
  /// **'Apps → Signet → Permissions → Camera'**
  String get pairCameraSettingsPathAndroid;

  /// Dev-only pane headline (paste string instead of camera).
  ///
  /// In en, this message translates to:
  /// **'Dev: paste-exchange'**
  String get pairExchangeDevHeading;

  /// Dev-only pane instructions; references the two field labels below.
  ///
  /// In en, this message translates to:
  /// **'Copy the \"Your string\" value into the other emulator\'s paste box, then paste theirs below.'**
  String get pairExchangeDevInstructions;

  /// Label above our own pairing string in the dev pane.
  ///
  /// In en, this message translates to:
  /// **'Your string'**
  String get pairExchangeDevYourString;

  /// Copy button next to our pairing string in the dev pane.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get pairExchangeDevCopyButton;

  /// SnackBar after copying our pairing string in the dev pane.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get pairExchangeDevCopiedSnackbar;

  /// Label above the input for the other device's pairing string in the dev pane.
  ///
  /// In en, this message translates to:
  /// **'Their string'**
  String get pairExchangeDevTheirString;

  /// BigButton submitting the pasted pairing string in the dev pane.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get pairExchangeDevSubmitButton;

  /// Disabled state of the dev-pane submit button.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get pairExchangeDevSubmittingButton;

  /// Validation error when submitting an empty pairing string in the dev pane.
  ///
  /// In en, this message translates to:
  /// **'Paste the other device’s pairing string.'**
  String get pairExchangePasteEmptyError;

  /// FormatException message from the pairing codec; shown in the scan pane and dev paste pane when the payload has the wrong prefix.
  ///
  /// In en, this message translates to:
  /// **'Not a Signet pairing QR (wrong scheme / version).'**
  String get pairingErrorNotPairingQr;

  /// FormatException message from the pairing codec when the decoded key length is wrong.
  ///
  /// In en, this message translates to:
  /// **'Decoded payload is {actual} bytes, expected 32.'**
  String pairingErrorBadPayloadLength(int actual);

  /// FormatException message from the pairing codec wrapping a base64 decode failure.
  ///
  /// In en, this message translates to:
  /// **'Could not decode pairing QR: {error}'**
  String pairingErrorDecodeFailed(String error);

  /// Error stored in pairing state when the scanned key has the wrong length; shown in the exchange overview error box.
  ///
  /// In en, this message translates to:
  /// **'Scanned key is {actual} bytes; expected {expected}.'**
  String pairingErrorBadKeyLength(int actual, int expected);

  /// Error stored in pairing state when ECDH derivation throws; shown in the exchange overview error box.
  ///
  /// In en, this message translates to:
  /// **'Failed to derive shared secret: {error}'**
  String pairingErrorDeriveFailed(String error);

  /// AppBar title of the phrase-confirmation step during a fresh pair.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get pairConfirmTitle;

  /// AppBar title of the phrase-confirmation step during a rekey.
  ///
  /// In en, this message translates to:
  /// **'Confirm rekey'**
  String get pairConfirmRekeyTitle;

  /// Headline above the 4-word phrase card on pair confirm.
  ///
  /// In en, this message translates to:
  /// **'Does this match their screen?'**
  String get pairConfirmHeading;

  /// Instruction under the pair-confirm headline.
  ///
  /// In en, this message translates to:
  /// **'Read it out loud. All four words should be identical on both devices.'**
  String get pairConfirmInstructions;

  /// BigButton confirming the phrases match; commits the pairing.
  ///
  /// In en, this message translates to:
  /// **'It matches'**
  String get pairConfirmMatchButton;

  /// Destructive BigButton when the phrases don't match; opens the abort dialog.
  ///
  /// In en, this message translates to:
  /// **'No match — start over'**
  String get pairConfirmMismatchButton;

  /// Title of the abort-confirmation dialog (uses a curly apostrophe in the source).
  ///
  /// In en, this message translates to:
  /// **'Phrases don’t match?'**
  String get pairConfirmMismatchDialogTitle;

  /// Body of the abort-confirmation dialog (curly apostrophes in the source).
  ///
  /// In en, this message translates to:
  /// **'If your phrase and theirs don’t match, something went wrong — this could be a bad scan or someone trying to get in the middle. Safer to throw this pairing away and start over.'**
  String get pairConfirmMismatchDialogBody;

  /// Destructive confirm button of the abort dialog.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get pairConfirmStartOverButton;

  /// SnackBar after a successful rekey commit.
  ///
  /// In en, this message translates to:
  /// **'Rekeyed pairing with {label}.'**
  String pairConfirmRekeySnackbar(String label);

  /// SnackBar after a successful fresh pairing commit.
  ///
  /// In en, this message translates to:
  /// **'Paired with {label}.'**
  String pairConfirmPairedSnackbar(String label);

  /// SnackBar error when confirm is tapped with missing pairing state.
  ///
  /// In en, this message translates to:
  /// **'Pairing state is incomplete.'**
  String get pairConfirmStateIncompleteError;

  /// SnackBar error when the relationship targeted by a rekey has disappeared.
  ///
  /// In en, this message translates to:
  /// **'Relationship to rekey is no longer paired.'**
  String get pairConfirmRekeyTargetMissingError;

  /// AppBar title of the post-commit practice screen.
  ///
  /// In en, this message translates to:
  /// **'PAIRED'**
  String get pairCompleteTitle;

  /// Monospace kicker above the headline on pair complete. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'PAIR COMMITTED //'**
  String get pairCompleteCommittedHeader;

  /// Large headline on pair complete; contains a manual line break.
  ///
  /// In en, this message translates to:
  /// **'You\'re both still here.\nTry a verify now.'**
  String get pairCompleteHeading;

  /// Instruction body on pair complete; 'Show-my-words' refers to the verify screen's own-words panel.
  ///
  /// In en, this message translates to:
  /// **'This is the easiest moment to practice. Ask {label} to open Signet, tap your name, and read the 4 words on their Show-my-words screen. Type what you hear into your verify input. Once the green banner lands, you\'ll know it works for real.'**
  String pairCompletePracticeBody(String label);

  /// Fallback for the peer label in pair-complete texts when the label can't be resolved yet.
  ///
  /// In en, this message translates to:
  /// **'your peer'**
  String get pairCompleteFallbackPeer;

  /// Tip box text on pair complete.
  ///
  /// In en, this message translates to:
  /// **'Skip this and you can still verify any time from Home. But the cheapest practice run you will ever get is right now.'**
  String get pairCompleteTipBody;

  /// FilledButton jumping into the first verify; the label is uppercased by the caller.
  ///
  /// In en, this message translates to:
  /// **'VERIFY {label} NOW'**
  String pairCompleteVerifyNowButton(String label);

  /// OutlinedButton leaving pair complete without practicing.
  ///
  /// In en, this message translates to:
  /// **'SKIP — DO IT LATER'**
  String get pairCompleteSkipButton;

  /// AppBar title of the transport-in unlock pane.
  ///
  /// In en, this message translates to:
  /// **'IMPORT PACKAGE'**
  String get pairTransportInImportTitle;

  /// Section header above the pasted-package field on transport in. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'INCOMING PACKAGE //'**
  String get pairTransportInIncomingHeader;

  /// Helper text above the package input on transport in; the wire prefix stays literal.
  ///
  /// In en, this message translates to:
  /// **'Paste the text the sender gave you. Starts with \"signet:tp1:\".'**
  String get pairTransportInPasteInstruction;

  /// Helper text above the PAKE word input on transport in.
  ///
  /// In en, this message translates to:
  /// **'The 8 words the sender shared with you over a trusted channel (paper, encrypted email, a prior meeting note). Do not accept these words over an unverified voice call.'**
  String get pairTransportInPakeDescription;

  /// FilledButton unlocking the incoming package on transport in.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK PACKAGE'**
  String get pairTransportInUnlockButton;

  /// Validation error when unlocking with an empty package field on transport in.
  ///
  /// In en, this message translates to:
  /// **'Paste the package from the sender.'**
  String get pairTransportInPasteEmptyError;

  /// Validation error when the 8 PAKE words aren't complete on transport in.
  ///
  /// In en, this message translates to:
  /// **'Enter all 8 words from the sender.'**
  String get pairTransportInWordsIncompleteError;

  /// Generic catch-all unlock error on transport in.
  ///
  /// In en, this message translates to:
  /// **'Failed to process package: {error}'**
  String pairTransportInProcessFailedError(String error);

  /// Instruction above the phrase card on transport in.
  ///
  /// In en, this message translates to:
  /// **'Check these 4 words with the sender face to face, or by calling a number you already had for them. Not by message, and never on a call or number someone gave you. If they match, the package is authentic.'**
  String get pairTransportInPhraseInstruction;

  /// Section header above the response package on transport in. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'YOUR RESPONSE //'**
  String get pairTransportInResponseHeader;

  /// Instruction above the response wire text on transport in.
  ///
  /// In en, this message translates to:
  /// **'Send this back to the sender, using the same channel you used to receive theirs. They will paste it to finish pairing.'**
  String get pairTransportInResponseInstruction;

  /// Copy button next to the response package on transport in.
  ///
  /// In en, this message translates to:
  /// **'Copy response'**
  String get pairTransportInCopyResponseButton;

  /// AppBar title of the transport-out setup phase.
  ///
  /// In en, this message translates to:
  /// **'NEW PACKAGE'**
  String get pairTransportOutNewPackageTitle;

  /// AppBar title of the transport-out share-and-wait phase.
  ///
  /// In en, this message translates to:
  /// **'SHARE + WAIT'**
  String get pairTransportOutShareWaitTitle;

  /// Helper text under the NAME THIS CONTACT header on transport out.
  ///
  /// In en, this message translates to:
  /// **'The label that will appear on your home screen after pairing. The peer will see this as a hint when they import the package but can rename it on their side.'**
  String get pairTransportOutNameDescription;

  /// FilledButton generating the outgoing package on transport out.
  ///
  /// In en, this message translates to:
  /// **'GENERATE PACKAGE'**
  String get pairTransportOutGenerateButton;

  /// Inline error when minting the ephemeral key pair / encoding the outgoing LDP package fails on transport out. Shows the underlying exception message.
  ///
  /// In en, this message translates to:
  /// **'Could not generate package: {error}'**
  String pairTransportOutGenerateError(String error);

  /// Section header above the outgoing wire text on transport out. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'OUTGOING PACKAGE //'**
  String get pairTransportOutOutgoingHeader;

  /// Instruction above the outgoing wire text on transport out.
  ///
  /// In en, this message translates to:
  /// **'Send this text to {label}. Encrypted email, Signal, paper courier, printed QR — any channel is fine. Only useful to someone who also has the 8 PAKE words below.'**
  String pairTransportOutOutgoingInstruction(String label);

  /// Warning box about out-of-band PAKE delivery on transport out.
  ///
  /// In en, this message translates to:
  /// **'Send the 8 words on a DIFFERENT channel than the package. Never on a call or number someone gave you. Paper, a prior-meeting fact, or another already-paired Signet relationship are all safer than speaking them aloud.'**
  String get pairTransportOutChannelWarning;

  /// Section header above the response input on transport out. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'RECEIVE RESPONSE //'**
  String get pairTransportOutReceiveHeader;

  /// Instruction above the response input on transport out.
  ///
  /// In en, this message translates to:
  /// **'{label} will send you a response package. Paste it here.'**
  String pairTransportOutReceiveInstruction(String label);

  /// Validation error when unlocking with an empty response field on transport out.
  ///
  /// In en, this message translates to:
  /// **'Paste the response package from the receiver.'**
  String get pairTransportOutPasteEmptyError;

  /// FilledButton unlocking the receiver's response on transport out.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK RESPONSE'**
  String get pairTransportOutUnlockResponseButton;

  /// Error when the response package fails to unlock on transport out.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock response: {error}'**
  String pairTransportOutUnlockFailedError(String error);

  /// In-person QR pairing: the scanned code carries a low-order or reflected public key (possible tampering). Must not reassure; tells both people to cancel and restart.
  ///
  /// In en, this message translates to:
  /// **'Stop. This code is not safe to use. Cancel pairing on both phones and start again. Do not trust any words either phone showed.'**
  String get pairingWeakKeyInPersonError;

  /// Long-distance pairing: the package or response carries a low-order or reflected public key (possible tampering, or the user's own package sent back). Must not reassure; tells the user to restart over a different channel.
  ///
  /// In en, this message translates to:
  /// **'This package is not safe to use. It may have been tampered with. Close this screen, make a new package, and send it a different way than before. Do not trust any words either phone showed.'**
  String get pairingWeakKeyRemoteError;

  /// Instruction above the phrase card on transport out.
  ///
  /// In en, this message translates to:
  /// **'Check these 4 words with {label} face to face, or by calling a number you already had for them. Not by message, and never on a call or number someone gave you. If they match, pairing is real.'**
  String pairTransportOutPhraseInstruction(String label);

  /// AppBar title of the single-relationship paper backup export.
  ///
  /// In en, this message translates to:
  /// **'BACK UP TO PAPER'**
  String get backupExportTitle;

  /// Error shown when minting the backup bundle fails.
  ///
  /// In en, this message translates to:
  /// **'Could not generate backup: {error}'**
  String backupExportGenerateError(String error);

  /// Headline of the backup export content.
  ///
  /// In en, this message translates to:
  /// **'Back up {label}'**
  String backupExportHeading(String label);

  /// Explanatory body under the export headline.
  ///
  /// In en, this message translates to:
  /// **'A backup lets you restore this pairing on a new phone if you lose this one. {label}\'s phone won\'t know anything changed.'**
  String backupExportIntro(String label);

  /// Body of the STORE THESE SEPARATELY warning on single export.
  ///
  /// In en, this message translates to:
  /// **'This backup has two parts: the package and the 8 words that unlock it. Keep them in different places. If someone finds both, they can restore this pairing on their own phone.'**
  String get backupExportStoreSeparatelyBody;

  /// Body of the REMEMBER warning on single export.
  ///
  /// In en, this message translates to:
  /// **'If someone else ever finds both the package and the 8 words, unpair {label} right away and pair again in person. The backup holds the same secret your current pairing uses.'**
  String backupExportRememberBody(String label);

  /// AppBar title of the backup-import unlock pane.
  ///
  /// In en, this message translates to:
  /// **'RESTORE BACKUP'**
  String get backupImportRestoreTitle;

  /// AppBar title of the backup-import commit pane.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM IMPORT'**
  String get backupImportConfirmTitle;

  /// The picked file is larger than any backup could be (checked before reading it).
  ///
  /// In en, this message translates to:
  /// **'That file is too large to be a Signet backup. Pick the small text file you saved when you made the backup.'**
  String get backupImportFileTooLargeError;

  /// Picking or reading the backup file failed. Never shows exception text (it can contain cache paths).
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected file. Try picking it again.'**
  String get backupImportFileReadError;

  /// Validation error when unlocking with an empty package field.
  ///
  /// In en, this message translates to:
  /// **'Load or paste your backup package first.'**
  String get backupImportPasteEmptyError;

  /// Validation error when the 8 PAKE words aren't complete on backup import.
  ///
  /// In en, this message translates to:
  /// **'Enter all 8 backup words.'**
  String get backupImportWordsIncompleteError;

  /// Restore screen: header above the package input.
  ///
  /// In en, this message translates to:
  /// **'STEP 1 // THE PACKAGE'**
  String get backupImportPackageHeader;

  /// Restore screen: opens the file picker for the PACKAGE file.
  ///
  /// In en, this message translates to:
  /// **'Load PACKAGE file'**
  String get backupImportLoadPackageFile;

  /// Restore screen: header above the 8-word input.
  ///
  /// In en, this message translates to:
  /// **'STEP 2 // THE 8 WORDS'**
  String get backupImportWordsHeader;

  /// Restore screen: opens the file picker for the WORDS file.
  ///
  /// In en, this message translates to:
  /// **'Load WORDS file'**
  String get backupImportLoadWordsFile;

  /// The package input was given the words file.
  ///
  /// In en, this message translates to:
  /// **'Those are the 8 words, not the package. Put them under step 2.'**
  String get backupImportIsWordsError;

  /// The words input was given the package file.
  ///
  /// In en, this message translates to:
  /// **'That is the package, not the words. Put it under step 1.'**
  String get backupImportIsPackageError;

  /// The words input was given text without 8 backup words.
  ///
  /// In en, this message translates to:
  /// **'No backup words found there. Look for a line of 8 words.'**
  String get backupImportNoWordsError;

  /// The words file's fingerprint does not match the package. Fingerprints are 6 digits shown as "123 456".
  ///
  /// In en, this message translates to:
  /// **'These words belong to a different backup (package {package}, words {words}). Find the words with fingerprint {package}.'**
  String backupImportFingerprintMismatchError(String package, String words);

  /// Shown when an old combined backup file is loaded.
  ///
  /// In en, this message translates to:
  /// **'This old backup keeps the words and the package together in one file. After restoring, make a new backup and delete this file.'**
  String get backupImportLegacyNotice;

  /// Error when the payload type can't be recognized.
  ///
  /// In en, this message translates to:
  /// **'Not a valid Signet backup.'**
  String get backupImportNotBackupError;

  /// Error when an LDP pairing package is pasted into the backup import.
  ///
  /// In en, this message translates to:
  /// **'That\'s a pairing invitation, not a backup. Use the pair flow from Home.'**
  String get backupImportInvitationError;

  /// Error when paste-from-clipboard finds nothing on backup import.
  ///
  /// In en, this message translates to:
  /// **'The clipboard is empty.'**
  String get backupImportClipboardEmptyError;

  /// Helper text above the package input on backup import; the wire prefix stays literal.
  ///
  /// In en, this message translates to:
  /// **'Load the PACKAGE file, or paste the package text. It starts with \"signet:tp1:\".'**
  String get backupImportPasteInstruction;

  /// Helper text above the PAKE word input on backup import.
  ///
  /// In en, this message translates to:
  /// **'Type the 8 words you wrote down, or load the WORDS file if you saved one.'**
  String get backupImportWordsInstruction;

  /// FilledButton unlocking the pasted backup.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK BACKUP'**
  String get backupImportUnlockButton;

  /// Section header above the decoded-contact summary on backup import. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'RESTORED PEER //'**
  String get backupImportRestoredPeerHeader;

  /// Monospace key in the restored-peer summary; the value is the wire role letter. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'ROLE //'**
  String get backupImportRoleLabel;

  /// Monospace key in the restored-peer summary; the value is the original pairing date. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'ORIGINALLY //'**
  String get backupImportOriginallyLabel;

  /// Monospace key in the restored-peer summary; the value is ON/OFF. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'HAPTICS //'**
  String get backupImportHapticsLabel;

  /// Value for the HAPTICS key when silent haptics is enabled.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get backupImportHapticsOff;

  /// Value for the HAPTICS key when silent haptics is disabled.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get backupImportHapticsOn;

  /// Secondary info-block headline on backup import. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'WHAT THIS DOES //'**
  String get backupImportWhatItDoesHeader;

  /// Body of the WHAT THIS DOES block on backup import.
  ///
  /// In en, this message translates to:
  /// **'This phone will start sharing a secret with {label} using the same key material as the old phone. {label}\'s phone won\'t know anything changed. If they\'ve already rekeyed with someone else since your backup, verifies will fail until you re-pair in person.'**
  String backupImportWhatItDoesBody(String label);

  /// FilledButton writing the restored relationship on backup import.
  ///
  /// In en, this message translates to:
  /// **'COMMIT IMPORT'**
  String get backupImportCommitButton;

  /// AppBar title of bulk export before generation.
  ///
  /// In en, this message translates to:
  /// **'BACK UP EVERYTHING'**
  String get bulkBackupExportSetupTitle;

  /// AppBar title of bulk export after generation.
  ///
  /// In en, this message translates to:
  /// **'BULK BACKUP READY'**
  String get bulkBackupExportReadyTitle;

  /// Error shown when preparing the bulk backup fails.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare backup: {error}'**
  String bulkBackupExportPrepareError(String error);

  /// Thrown when no relationship secret could be read; surfaces inside the prepare-error text.
  ///
  /// In en, this message translates to:
  /// **'No relationships had retrievable secrets.'**
  String get bulkBackupExportNoSecretsError;

  /// Headline of the bulk-export empty state.
  ///
  /// In en, this message translates to:
  /// **'Nothing to back up yet.'**
  String get bulkBackupExportEmptyTitle;

  /// Body of the bulk-export empty state.
  ///
  /// In en, this message translates to:
  /// **'Pair with someone first, then come back here to create a bulk backup.'**
  String get bulkBackupExportEmptyBody;

  /// Headline of the bulk-export pre-generation pane.
  ///
  /// In en, this message translates to:
  /// **'Back up {count, plural, =1{1 relationship} other{{count} relationships}}'**
  String bulkBackupExportReadyHeading(int count);

  /// Body under the bulk-export pre-generation headline.
  ///
  /// In en, this message translates to:
  /// **'Every paired contact below goes into one encrypted file with one 8-word PAKE. You store the file and the words separately, then use them to bring every pairing across to a new phone.'**
  String get bulkBackupExportReadyBody;

  /// FilledButton generating the bulk backup.
  ///
  /// In en, this message translates to:
  /// **'GENERATE BULK BACKUP'**
  String get bulkBackupExportGenerateButton;

  /// Headline of the generated-bulk-backup pane.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 relationship backed up} other{{count} relationships backed up}}'**
  String bulkBackupExportDoneHeading(int count);

  /// Body of the STORE THESE SEPARATELY warning on bulk export (every-pairing variant).
  ///
  /// In en, this message translates to:
  /// **'This backup has two parts: the package and the 8 words that unlock it. Keep them in different places. If someone finds both, they can restore every pairing on their own phone.'**
  String get bulkBackupExportStoreSeparatelyBody;

  /// Instruction above the PAKE word list on bulk export.
  ///
  /// In en, this message translates to:
  /// **'Write these 8 words somewhere safe. You will type them into the new phone to unlock everything at once.'**
  String get bulkBackupExportWordsInstruction;

  /// Instruction above the bulk package text on bulk export.
  ///
  /// In en, this message translates to:
  /// **'The whole set of pairings, encrypted with the 8 words above. Share this via any channel — the words keep it sealed.'**
  String get bulkBackupExportPackageInstruction;

  /// Subject line handed to the OS share sheet for a bulk backup.
  ///
  /// In en, this message translates to:
  /// **'Signet bulk backup - {count} peers'**
  String bulkBackupExportShareSubject(int count);

  /// Body of the REMEMBER warning on bulk export.
  ///
  /// In en, this message translates to:
  /// **'If someone else ever finds both the package and the 8 words, unpair every contact in it and pair again in person. The backup holds the same secrets your current pairings use.'**
  String get bulkBackupExportRememberBody;

  /// AppBar title of the bulk-import preview pane.
  ///
  /// In en, this message translates to:
  /// **'BULK RESTORE'**
  String get bulkBackupImportTitle;

  /// AppBar title of the bulk-import success pane.
  ///
  /// In en, this message translates to:
  /// **'RESTORED'**
  String get bulkBackupImportDoneTitle;

  /// Top-level error text on the bulk-import screen.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String bulkBackupImportGenericError(String error);

  /// Headline of the bulk-import preview pane.
  ///
  /// In en, this message translates to:
  /// **'Restore {count, plural, =1{1 relationship} other{{count} relationships}}'**
  String bulkBackupImportPreviewHeading(int count);

  /// A package's unauthenticated version or type byte says it needs a newer Signet. Anyone can trigger this without the 8 words, so it must steer users only to their normal install source and warn against links or files (scam lever).
  ///
  /// In en, this message translates to:
  /// **'This needs a newer version of Signet. Update Signet only from the app store you installed it from. Signet never sends updates as a link or file. If you were not expecting this, check with whoever sent it, in person.'**
  String get packageNeedsNewerSignetError;

  /// A package unlocked with the correct 8 words contains a must-understand field this build does not know. Only the holder of the words can produce this, so plain wording is fine.
  ///
  /// In en, this message translates to:
  /// **'This was made by a newer version of Signet. Update Signet from the app store you installed it from, then try again.'**
  String get packageNeedsNewerSignetVerifiedError;

  /// Any malformed transport package (backup or pairing): replaces English developer error text.
  ///
  /// In en, this message translates to:
  /// **'This package is damaged or incomplete. Check that you copied all of it, or ask for it to be sent again.'**
  String get packageDamagedError;

  /// Single-backup restore: the stored pairing date was invalid and was reset to the import time. The secret is intact.
  ///
  /// In en, this message translates to:
  /// **'Part of this backup was unreadable and has been fixed: the pairing date was reset to today. The pairing itself is not affected.'**
  String get backupImportRepairedDateNotice;

  /// Single-backup restore: the stored name was not valid text and some characters were replaced. The secret is intact.
  ///
  /// In en, this message translates to:
  /// **'Part of this backup was unreadable and has been fixed: a few characters in the name were replaced. Check the name before you restore. The pairing itself is not affected.'**
  String get backupImportRepairedLabelNotice;

  /// Bulk restore preview: records whose pairing date or label was repaired on decode. Matches the FIXED badge on each row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 relationship in this backup had an unreadable date or name that has been fixed. It is marked FIXED below; check its name before you restore.} other{{count} relationships in this backup had an unreadable date or name that has been fixed. They are marked FIXED below; check their names before you restore.}}'**
  String bulkBackupImportRepairedNotice(int count);

  /// Bulk restore preview and summary: records skipped because they carry a must-understand field this build does not know.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 relationship in this backup needs a newer version of Signet and is not shown. Keep your old phone until it is restored. Update Signet only from the app store you installed it from, then restore again.} other{{count} relationships in this backup need a newer version of Signet and are not shown. Keep your old phone until they are restored. Update Signet only from the app store you installed it from, then restore again.}}'**
  String bulkBackupImportSkippedNewerNotice(int count);

  /// Small badge on a bulk-restore row whose date or name was repaired on decode.
  ///
  /// In en, this message translates to:
  /// **'FIXED'**
  String get bulkBackupImportRepairedBadge;

  /// Bulk-restore summary row label: records not restored because they need a newer Signet. Operator-style header with the trailing ' //'.
  ///
  /// In en, this message translates to:
  /// **'NEEDS NEWER SIGNET //'**
  String get bulkBackupImportSummarySkippedNewer;

  /// Body when no restored label collides with an existing pairing.
  ///
  /// In en, this message translates to:
  /// **'Tick the rows you want to restore. Every pairing below will come back with its original label and pair date.'**
  String get bulkBackupImportNoConflictBody;

  /// Body when some restored labels collide with existing pairings.
  ///
  /// In en, this message translates to:
  /// **'Some of these labels are already paired on this phone. Choose what to do for each — default is skip.'**
  String get bulkBackupImportConflictBody;

  /// Monospace progress line shown while committing bulk records.
  ///
  /// In en, this message translates to:
  /// **'Restoring {committed} of {total}…'**
  String bulkBackupImportProgressText(int committed, int total);

  /// Disabled state of the bulk restore button.
  ///
  /// In en, this message translates to:
  /// **'RESTORING…'**
  String get bulkBackupImportRestoringButton;

  /// Disabled state of the bulk restore button when zero records are selected.
  ///
  /// In en, this message translates to:
  /// **'NOTHING SELECTED'**
  String get bulkBackupImportNothingSelectedButton;

  /// Bulk restore button with the number of selected records.
  ///
  /// In en, this message translates to:
  /// **'RESTORE {count}'**
  String bulkBackupImportRestoreButton(int count);

  /// Red chip replacing the checkbox on rows whose label already exists on this device.
  ///
  /// In en, this message translates to:
  /// **'ALREADY PAIRED'**
  String get bulkBackupImportAlreadyPairedChip;

  /// Placeholder shown when a bulk record has an empty label.
  ///
  /// In en, this message translates to:
  /// **'(no label)'**
  String get bulkBackupImportNoLabel;

  /// Monospace metadata line on each bulk-import row: wire role letter and pairing date.
  ///
  /// In en, this message translates to:
  /// **'ROLE {role} · PAIRED {date}'**
  String bulkBackupImportRecordMeta(String role, String date);

  /// Conflict radio option: keep the existing pairing untouched.
  ///
  /// In en, this message translates to:
  /// **'Skip — leave existing pairing alone'**
  String get bulkBackupImportSkipOption;

  /// Conflict radio option: import under a suffixed label; the suffix is stored on the contact name.
  ///
  /// In en, this message translates to:
  /// **'Rename restored copy to \"{label} (restored)\"'**
  String bulkBackupImportRenameOption(String label);

  /// Conflict radio option: replace the existing pairing's secret.
  ///
  /// In en, this message translates to:
  /// **'Overwrite existing pairing'**
  String get bulkBackupImportOverwriteOption;

  /// Headline of the bulk-import success pane.
  ///
  /// In en, this message translates to:
  /// **'Restore complete.'**
  String get bulkBackupImportCompleteHeading;

  /// Summary row label: records created. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'RESTORED //'**
  String get bulkBackupImportSummaryRestored;

  /// Summary row label: records imported under a new label. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'RENAMED //'**
  String get bulkBackupImportSummaryRenamed;

  /// Summary row label: existing pairings overwritten. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'OVERWROTE //'**
  String get bulkBackupImportSummaryOverwrote;

  /// Summary row label: records skipped. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'SKIPPED //'**
  String get bulkBackupImportSummarySkipped;

  /// Success-pane body when zero records were committed.
  ///
  /// In en, this message translates to:
  /// **'Nothing was changed on this phone.'**
  String get bulkBackupImportNothingChangedBody;

  /// Success-pane body when at least one record was committed.
  ///
  /// In en, this message translates to:
  /// **'Each restored pairing uses the same shared secret as the old phone; their other side won\'t notice the restore unless they rekey.'**
  String get bulkBackupImportDoneBody;

  /// AppBar title of the binding-phrase re-check screen.
  ///
  /// In en, this message translates to:
  /// **'VERIFY BINDING'**
  String get bindingPhraseTitle;

  /// Error state message on the binding-phrase screen.
  ///
  /// In en, this message translates to:
  /// **'Could not read your pairing.'**
  String get bindingPhraseLoadError;

  /// Instruction above the phrase card on the binding-phrase screen.
  ///
  /// In en, this message translates to:
  /// **'These 4 words were derived the moment you and {label} paired. Ask {label} to open Signet and tap this same screen. Compare them face to face, or on a call you place to a number you already had. If the 4 words on both devices match, the pairing is intact.'**
  String bindingPhraseExplanation(String label);

  /// Red warning headline on the binding-phrase screen. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'IF THEY DO NOT MATCH //'**
  String get bindingPhraseMismatchHeader;

  /// Body of the mismatch warning on the binding-phrase screen.
  ///
  /// In en, this message translates to:
  /// **'Unpair and re-pair in person. Do not verify any calls against this pairing until you have.'**
  String get bindingPhraseMismatchBody;

  /// Button on the binding-phrase error state.
  ///
  /// In en, this message translates to:
  /// **'BACK TO HOME'**
  String get bindingPhraseBackHomeButton;

  /// AppBar title of the challenge-response grid viewer.
  ///
  /// In en, this message translates to:
  /// **'CHALLENGE-RESPONSE'**
  String get crGridTitle;

  /// Tooltip of the print icon in the cr-grid AppBar.
  ///
  /// In en, this message translates to:
  /// **'Print grid'**
  String get crGridPrintTooltip;

  /// Error shown when deriving the grid fails.
  ///
  /// In en, this message translates to:
  /// **'Could not load grid: {error}'**
  String crGridLoadError(String error);

  /// Headline of the cr-grid viewer.
  ///
  /// In en, this message translates to:
  /// **'Grid for {label}'**
  String crGridHeading(String label);

  /// Explanation under the cr-grid headline; the example cell uses the first row/column labels.
  ///
  /// In en, this message translates to:
  /// **'When {label} can\'t use their phone but can speak, use this grid as a fallback. You ask for a cell (e.g. \"{row} × {col}\"); they read the answer from the paper copy you both shared. Compare silently on your side.'**
  String crGridFallbackExplanation(String label, String row, String col);

  /// Amber info box on the cr-grid viewer.
  ///
  /// In en, this message translates to:
  /// **'This is a FALLBACK. If you can run a rotating-word verify, do that first — its defenses are stronger. Use this only when the responder has no phone.'**
  String get crGridFallbackNotice;

  /// Section header above the grid table. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'GRID // 8×8 //'**
  String get crGridSectionHeader;

  /// AlertDialog title when tapping a grid cell; the row/column word labels.
  ///
  /// In en, this message translates to:
  /// **'{row} × {col}'**
  String crGridCellDialogTitle(String row, String col);

  /// Button closing the cell-answer dialog.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get crGridCloseButton;

  /// PDF document metadata title for the printed card.
  ///
  /// In en, this message translates to:
  /// **'Signet challenge-response · {label}'**
  String crPdfDocTitle(String label);

  /// Printed header line on the PDF card.
  ///
  /// In en, this message translates to:
  /// **'SIGNET CHALLENGE-RESPONSE CARD'**
  String get crPdfCardTitle;

  /// Printed warning headline on the PDF card.
  ///
  /// In en, this message translates to:
  /// **'TREAT THIS CARD LIKE A SAFE COMBINATION'**
  String get crPdfWarningTitle;

  /// Printed warning paragraph on the PDF card.
  ///
  /// In en, this message translates to:
  /// **'Anyone who finds this card can answer challenges for this pairing. Challenge-response is a fallback - the rotating word verify in the app is still the stronger check for day-to-day calls. If you lose this card, unpair this relationship in the app and re-pair in person.'**
  String get crPdfWarningBody;

  /// Axis legend panel title on the PDF card. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'ROWS //'**
  String get crPdfRowsHeader;

  /// Axis legend panel title on the PDF card. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'COLUMNS //'**
  String get crPdfColumnsHeader;

  /// Printed attribution footer on the PDF card.
  ///
  /// In en, this message translates to:
  /// **'Signet - challenge-response v1'**
  String get crPdfFooter;

  /// AppBar title of the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsTitle;

  /// Settings section card title for the theme picker.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get settingsAppearanceSection;

  /// Body of the appearance section; the quoted words are the picker labels below.
  ///
  /// In en, this message translates to:
  /// **'Override the system theme. \"System\" follows your device; \"Dark\" and \"Light\" pin Signet regardless.'**
  String get settingsAppearanceBody;

  /// Theme option label: follow the OS.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM'**
  String get settingsThemeSystemLabel;

  /// Theme option subtitle for SYSTEM.
  ///
  /// In en, this message translates to:
  /// **'Follow device theme'**
  String get settingsThemeSystemSubtitle;

  /// Theme option label: always dark.
  ///
  /// In en, this message translates to:
  /// **'DARK'**
  String get settingsThemeDarkLabel;

  /// Theme option subtitle for DARK (the app's default aesthetic).
  ///
  /// In en, this message translates to:
  /// **'Operator default'**
  String get settingsThemeDarkSubtitle;

  /// Theme option label: always light.
  ///
  /// In en, this message translates to:
  /// **'LIGHT'**
  String get settingsThemeLightLabel;

  /// Theme option subtitle for LIGHT.
  ///
  /// In en, this message translates to:
  /// **'High-contrast daylight'**
  String get settingsThemeLightSubtitle;

  /// Settings section card title for bulk backup.
  ///
  /// In en, this message translates to:
  /// **'BULK BACKUP'**
  String get settingsBulkBackupSection;

  /// Body of the bulk-backup section when no relationships exist.
  ///
  /// In en, this message translates to:
  /// **'No relationships paired yet. Pair with someone first, then you can back up every pairing at once.'**
  String get settingsBulkBackupEmptyBody;

  /// Body of the bulk-backup section when relationships exist.
  ///
  /// In en, this message translates to:
  /// **'Back up all {count, plural, =1{1 relationship} other{{count} relationships}} into one encrypted file with one 8-word PAKE. Use this when switching phones — the new phone unlocks every pairing in one step.'**
  String settingsBulkBackupBody(int count);

  /// Outlined action button of the bulk-backup section.
  ///
  /// In en, this message translates to:
  /// **'BACK UP ALL {count}'**
  String settingsBulkBackupAction(int count);

  /// Settings section card title for opt-in debug logging (hidden when unavailable).
  ///
  /// In en, this message translates to:
  /// **'DEBUG LOGGING'**
  String get settingsDebugSection;

  /// Body of the debug section while a session is active; {expiry} is a formatted expiry phrase.
  ///
  /// In en, this message translates to:
  /// **'Recording app activity to an encrypted file on this device. It auto-erases {expiry} (or tap Stop). Export it to send a bug report — secrets are removed and contacts become tags like <peer-1> before it leaves your phone.'**
  String settingsDebugActiveBody(String expiry);

  /// Body of the debug section while inactive.
  ///
  /// In en, this message translates to:
  /// **'Off — nothing is recorded. If you hit a bug, turn this on, reproduce it, then export the log to send us. It never includes your secrets or your contacts\' names.'**
  String get settingsDebugInactiveBody;

  /// Action button enabling debug logging.
  ///
  /// In en, this message translates to:
  /// **'ENABLE DEBUG LOGGING'**
  String get settingsDebugEnableAction;

  /// Snackbar when starting a debug-logging session fails (e.g. the secure key store is unavailable). Logging stays off.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t turn on debug logging. Nothing was recorded. Try again.'**
  String get settingsDebugEnableFailed;

  /// Outlined button opening the debug-log export sheet.
  ///
  /// In en, this message translates to:
  /// **'EXPORT DEBUG LOGS'**
  String get settingsDebugExportButton;

  /// Outlined button stopping the debug session and erasing its log.
  ///
  /// In en, this message translates to:
  /// **'STOP & WIPE'**
  String get settingsDebugStopWipeButton;

  /// SnackBar when exporting an empty debug log.
  ///
  /// In en, this message translates to:
  /// **'No debug log captured yet.'**
  String get settingsDebugNoLogSnackbar;

  /// Expiry phrase when no exact expiry timestamp is known.
  ///
  /// In en, this message translates to:
  /// **'in 24h'**
  String get settingsDebugExpiryIn24h;

  /// Expiry phrase with a local timestamp, e.g. 'at 14:30 on 2026-10-01'.
  ///
  /// In en, this message translates to:
  /// **'at {time} on {date}'**
  String settingsDebugExpiryAt(String time, String date);

  /// Settings section card title for replaying onboarding.
  ///
  /// In en, this message translates to:
  /// **'GUIDED TOUR'**
  String get settingsTourSection;

  /// Body of the guided-tour section.
  ///
  /// In en, this message translates to:
  /// **'Watch the first-run walkthrough again. Useful after a backup restore or if you want to re-read the pairing instructions.'**
  String get settingsTourBody;

  /// Action button replaying the onboarding.
  ///
  /// In en, this message translates to:
  /// **'REPLAY INTRO'**
  String get settingsTourReplayAction;

  /// Settings section card title linking to About.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get settingsAboutSection;

  /// Body of the settings About section.
  ///
  /// In en, this message translates to:
  /// **'App version, license, source code, privacy policy, and support links.'**
  String get settingsAboutBody;

  /// Action button opening the About screen.
  ///
  /// In en, this message translates to:
  /// **'OPEN ABOUT'**
  String get settingsAboutOpenAction;

  /// Title of the one-tap confirm dialog before bulk export.
  ///
  /// In en, this message translates to:
  /// **'BACK UP EVERYTHING?'**
  String get settingsBulkConfirmTitle;

  /// Body of the bulk-export confirm dialog.
  ///
  /// In en, this message translates to:
  /// **'This exports the shared secret for all {count, plural, =1{1 relationship} other{{count} relationships}} into one file. Losing the 8-word PAKE means losing all {count} backups. The PAKE will be shown once — write it down before closing the screen.'**
  String settingsBulkConfirmBody(int count);

  /// Filled confirm button of the bulk-export dialog.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get settingsBulkConfirmContinue;

  /// Headline of the debug-log export bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'EXPORT DEBUG LOG'**
  String get logExportTitle;

  /// Scrubbing explanation in the export sheet; <peer-1> is a literal example tag.
  ///
  /// In en, this message translates to:
  /// **'Secrets are removed and your contacts are shown as tags like <peer-1>. The log still describes app behavior, so review it before sharing. If you file a GitHub issue, don\'t type a contact\'s name in the description box — that box is not scrubbed.'**
  String get logExportScrubNotice;

  /// Outlined button opening the pre-filled GitHub issue with the log.
  ///
  /// In en, this message translates to:
  /// **'FILE A GITHUB ISSUE'**
  String get logExportFileIssueButton;

  /// Outlined button handing the log to the OS share sheet.
  ///
  /// In en, this message translates to:
  /// **'SHARE…'**
  String get logExportShareButton;

  /// Outlined button copying the scrubbed log.
  ///
  /// In en, this message translates to:
  /// **'COPY TO CLIPBOARD'**
  String get logExportCopyButton;

  /// SnackBar when the GitHub issue URL can't be opened from the export sheet.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the browser — log copied instead.'**
  String get logExportOpenFailedSnackbar;

  /// Subject line handed to the OS share sheet for the debug log.
  ///
  /// In en, this message translates to:
  /// **'Signet debug log'**
  String get logExportShareSubject;

  /// SnackBar after copying the debug log.
  ///
  /// In en, this message translates to:
  /// **'Debug log copied to clipboard.'**
  String get logExportCopiedSnackbar;

  /// AppBar title of the verify screen.
  ///
  /// In en, this message translates to:
  /// **'VERIFY'**
  String get verifyTitle;

  /// Section header above the ask-for-words block. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'CHALLENGE //'**
  String get verifySectionChallenge;

  /// Large instruction headline in the challenge section.
  ///
  /// In en, this message translates to:
  /// **'Ask {label} for their 4 words.'**
  String verifyAskForWordsHeading(String label);

  /// Small instruction under the challenge headline; 'slot' means the word input slots.
  ///
  /// In en, this message translates to:
  /// **'Type what you hear. Tap a suggestion to fill a slot.'**
  String get verifyTypeInstruction;

  /// Section header above the word input. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'INPUT //'**
  String get verifySectionInput;

  /// Red monospace headline of the education bottom sheet. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'IF VERIFY FAILS //'**
  String get verifyFailHeader;

  /// Large statement at the top of the education sheet.
  ///
  /// In en, this message translates to:
  /// **'Something is wrong with this call.'**
  String get verifyFailHeading;

  /// Education sheet step 01.
  ///
  /// In en, this message translates to:
  /// **'Hang up. Do not explain why. Do not argue. Do not agree to anything they\'re asking for.'**
  String get verifyFailStep1;

  /// Education sheet step 02.
  ///
  /// In en, this message translates to:
  /// **'Call {label} back on a number you have used before — saved in your contacts, written down, something you know. Do not use a number the caller gave you.'**
  String verifyFailStep2(String label);

  /// Education sheet step 03.
  ///
  /// In en, this message translates to:
  /// **'If {label} does not answer, call a family member or someone close who can physically check on them. A real {label} will never be upset that you checked.'**
  String verifyFailStep3(String label);

  /// Education sheet step 04; SHOW BINDING PHRASE refers to the Home row-menu item.
  ///
  /// In en, this message translates to:
  /// **'If you are unsure whether Signet itself is broken: go to the home screen, tap \"SHOW BINDING PHRASE\", and compare with {label} on a channel you trust. If the phrases match, Signet is working correctly and the red banner means the call was fake.'**
  String verifyFailStep4(String label);

  /// Monospace kicker on the green result banner (HTTP-style). Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'STATUS // 200 OK'**
  String get verifyStatusOk;

  /// Monospace kicker on the red result banner (HTTP-style). Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'STATUS // 403 MISMATCH'**
  String get verifyStatusFail;

  /// Headline of the green result banner.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED'**
  String get verifyBannerVerified;

  /// Headline of the red result banner.
  ///
  /// In en, this message translates to:
  /// **'NOT VERIFIED — BE SUSPICIOUS'**
  String get verifyBannerNotVerified;

  /// Green banner subline in video mode when both checks passed.
  ///
  /// In en, this message translates to:
  /// **'Words matched AND you saw the expected physical action. You can trust this call.'**
  String get verifySublineVerifiedWithAction;

  /// Green banner subline in plain mode.
  ///
  /// In en, this message translates to:
  /// **'The words match. You can trust this call.'**
  String get verifySublineVerified;

  /// Red banner subline when the typed words failed.
  ///
  /// In en, this message translates to:
  /// **'The words did not match. Someone may be impersonating them.'**
  String get verifySublineWordsMismatch;

  /// Red banner subline when words passed but the video action failed.
  ///
  /// In en, this message translates to:
  /// **'Words matched but the physical action did not. Be suspicious and treat this as a failed verify.'**
  String get verifySublineActionMismatch;

  /// Outlined button on the red banner opening the education sheet.
  ///
  /// In en, this message translates to:
  /// **'WHAT SHOULD I DO?'**
  String get verifyWhatShouldIDoButton;

  /// Semantics label of the video-mode toggle row.
  ///
  /// In en, this message translates to:
  /// **'Video call mode'**
  String get verifyVideoModeSemanticsLabel;

  /// Semantics hint of the video-mode toggle row.
  ///
  /// In en, this message translates to:
  /// **'Turn on to also check a physical action on video.'**
  String get verifyVideoModeSemanticsHint;

  /// Monospace header of the video-mode toggle row. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'VIDEO CALL //'**
  String get verifyVideoModeHeader;

  /// Toggle row description while video mode is on.
  ///
  /// In en, this message translates to:
  /// **'Request a physical action too. Defeats deepfakes.'**
  String get verifyVideoModeOnText;

  /// Toggle row description while video mode is off.
  ///
  /// In en, this message translates to:
  /// **'Turn on to also check a physical action.'**
  String get verifyVideoModeOffText;

  /// Header of the expected-action row in video mode. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'WATCH FOR //'**
  String get verifyWatchForHeader;

  /// Visible text of the expected-action row; {action} is the human-readable action phrase.
  ///
  /// In en, this message translates to:
  /// **'{label} should: {action}.'**
  String verifyExpectedActionText(String label, String action);

  /// Semantics live-region label of the expected-action row.
  ///
  /// In en, this message translates to:
  /// **'Watch for: {label} should {action}.'**
  String verifyExpectedActionSemantics(String label, String action);

  /// Header of the action-judgment panel in video mode. Keep the ' //' structure.
  ///
  /// In en, this message translates to:
  /// **'ACTION //'**
  String get verifyActionHeader;

  /// Prompt in the action-judgment panel after the words verified; keep the ✅ emoji.
  ///
  /// In en, this message translates to:
  /// **'Words ✅. Did you see {label}: {action}?'**
  String verifyActionJudgmentPrompt(String label, String action);

  /// Destructive judgment button: the action was not performed.
  ///
  /// In en, this message translates to:
  /// **'DID NOT SEE'**
  String get verifyActionNotSeenButton;

  /// Confirming judgment button: the action was performed.
  ///
  /// In en, this message translates to:
  /// **'SAW IT'**
  String get verifyActionSeenButton;

  /// Collapsible section title: my own rotating words.
  ///
  /// In en, this message translates to:
  /// **'Show my 4 words'**
  String get verifyShowMyWords;

  /// Subtitle under the show-my-words title.
  ///
  /// In en, this message translates to:
  /// **'If {label} wants to verify you, read these.'**
  String verifyShowMyWordsSubtitle(String label);

  /// Monospace badge marking that screenshots are blocked on this panel. Technical Android flag name — keep as-is.
  ///
  /// In en, this message translates to:
  /// **'FLAG_SECURE'**
  String get verifyFlagSecureBadge;

  /// Line under my own words in video mode; {action} is a gerund phrase from the verifyGerund* keys.
  ///
  /// In en, this message translates to:
  /// **'...while {action}.'**
  String verifyOwnActionWhile(String action);

  /// Gerund of the look-up liveness action, used in verifyOwnActionWhile.
  ///
  /// In en, this message translates to:
  /// **'looking up at the ceiling'**
  String get verifyGerundLookUp;

  /// Gerund of the look-down liveness action.
  ///
  /// In en, this message translates to:
  /// **'looking down at the floor'**
  String get verifyGerundLookDown;

  /// Gerund of the look-left liveness action.
  ///
  /// In en, this message translates to:
  /// **'looking over your left shoulder'**
  String get verifyGerundLookLeft;

  /// Gerund of the look-right liveness action.
  ///
  /// In en, this message translates to:
  /// **'looking over your right shoulder'**
  String get verifyGerundLookRight;

  /// Gerund of the touch-nose liveness action.
  ///
  /// In en, this message translates to:
  /// **'touching the tip of your nose'**
  String get verifyGerundTouchNose;

  /// Gerund of the touch-forehead liveness action.
  ///
  /// In en, this message translates to:
  /// **'touching your forehead'**
  String get verifyGerundTouchForehead;

  /// Gerund of the touch-left-ear liveness action.
  ///
  /// In en, this message translates to:
  /// **'touching your left ear'**
  String get verifyGerundTouchLeftEar;

  /// Gerund of the touch-right-ear liveness action.
  ///
  /// In en, this message translates to:
  /// **'touching your right ear'**
  String get verifyGerundTouchRightEar;

  /// Imperative form of the look-up liveness action, shown to the verifier as the gesture to watch for and judge. Must stay in lockstep with LivenessAction.humanReadable in English.
  ///
  /// In en, this message translates to:
  /// **'Look up at the ceiling'**
  String get verifyActionLookUp;

  /// Imperative form of the look-down liveness action, shown to the verifier as the gesture to watch for and judge. Must stay in lockstep with LivenessAction.humanReadable in English.
  ///
  /// In en, this message translates to:
  /// **'Look down at the floor'**
  String get verifyActionLookDown;

  /// Imperative form of the look-left liveness action, shown to the verifier as the gesture to watch for and judge. Must stay in lockstep with LivenessAction.humanReadable in English.
  ///
  /// In en, this message translates to:
  /// **'Look over your left shoulder'**
  String get verifyActionLookLeft;

  /// Imperative form of the look-right liveness action, shown to the verifier as the gesture to watch for and judge. Must stay in lockstep with LivenessAction.humanReadable in English.
  ///
  /// In en, this message translates to:
  /// **'Look over your right shoulder'**
  String get verifyActionLookRight;

  /// Imperative form of the touch-nose liveness action, shown to the verifier as the gesture to watch for and judge. Must stay in lockstep with LivenessAction.humanReadable in English.
  ///
  /// In en, this message translates to:
  /// **'Touch the tip of your nose'**
  String get verifyActionTouchNose;

  /// Imperative form of the touch-forehead liveness action, shown to the verifier as the gesture to watch for and judge. Must stay in lockstep with LivenessAction.humanReadable in English.
  ///
  /// In en, this message translates to:
  /// **'Touch your forehead'**
  String get verifyActionTouchForehead;

  /// Imperative form of the touch-left-ear liveness action, shown to the verifier as the gesture to watch for and judge. Must stay in lockstep with LivenessAction.humanReadable in English.
  ///
  /// In en, this message translates to:
  /// **'Touch your left ear'**
  String get verifyActionTouchLeftEar;

  /// Imperative form of the touch-right-ear liveness action, shown to the verifier as the gesture to watch for and judge. Must stay in lockstep with LivenessAction.humanReadable in English.
  ///
  /// In en, this message translates to:
  /// **'Touch your right ear'**
  String get verifyActionTouchRightEar;

  /// Title of the verify error state.
  ///
  /// In en, this message translates to:
  /// **'Could not read your paired contact.'**
  String get verifyLoadError;

  /// Button on the verify error state.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get verifyBackHomeButton;

  /// Button resetting every word slot in the shared WordInput widget.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get wordInputClearAllButton;

  /// Shown while the parent verifies the submitted words.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get wordInputChecking;

  /// Semantics label of each word slot.
  ///
  /// In en, this message translates to:
  /// **'Word {index} of {total}'**
  String wordInputSlotSemantics(int index, int total);

  /// hintText of each word slot (BIP-39 word placeholder).
  ///
  /// In en, this message translates to:
  /// **'word'**
  String get wordInputHint;

  /// errorText when a slot holds text that no wordlist word starts with.
  ///
  /// In en, this message translates to:
  /// **'Not a valid word'**
  String get wordInputInvalidWordError;

  /// Tooltip of the per-slot clear (x) icon button.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get wordInputClearTooltip;

  /// Semantics label of the rotating words display.
  ///
  /// In en, this message translates to:
  /// **'Verification phrase: {words}, {seconds} seconds remaining'**
  String wordsDisplaySemantics(String words, int seconds);

  /// Countdown text under the words, e.g. '27 s'.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String wordsDisplayCountdown(int seconds);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
