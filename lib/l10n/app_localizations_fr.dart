// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonAppTitle => 'SIGNET';

  @override
  String get commonOfflineFreeChip => '100 % HORS LIGNE';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonCancelCaps => 'ANNULER';

  @override
  String get commonDone => 'TERMINÉ';

  @override
  String get commonGotIt => 'COMPRIS';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonCopyPackage => 'Copier le paquet';

  @override
  String get backupStep1Header => 'ÉTAPE 1 // ENREGISTRER LE PAQUET';

  @override
  String get backupStep1Body =>
      'Enregistrez ce paquet ailleurs que sur ce téléphone, par exemple sur votre ordinateur ou une clé USB, ou imprimez le code. Si vous perdez le téléphone, la copie qui s’y trouve est perdue aussi. Le paquet ne contient pas les 8 mots : à lui seul, il ne permet de rien restaurer.';

  @override
  String get backupStep1BodyNoQr =>
      'Enregistrez ce paquet ailleurs que sur ce téléphone, par exemple sur votre ordinateur ou une clé USB. Si vous perdez le téléphone, la copie qui s’y trouve est perdue aussi. Le paquet ne contient pas les 8 mots : à lui seul, il ne permet de rien restaurer.';

  @override
  String get backupSavePackageFile => 'Enregistrer le fichier du paquet';

  @override
  String get backupSavedAnotherWay => 'Je l’ai enregistré autrement';

  @override
  String get backupStep2Header => 'ÉTAPE 2 // GARDER LES 8 MOTS AILLEURS';

  @override
  String get backupStep2Locked =>
      'Terminez d’abord l’étape 1. Les 8 mots s’affichent ici une fois le paquet enregistré.';

  @override
  String get backupStep2Body =>
      'Écrivez ces 8 mots sur papier, ainsi que l’empreinte ci-dessous, pour savoir à quel paquet ils correspondent. Rangez le papier loin du paquet, par exemple dans votre portefeuille. Toute personne qui a les deux peut restaurer vos associations.';

  @override
  String get backupWroteOnPaper => 'Je les ai écrits sur papier';

  @override
  String get backupSaveWordsFile => 'Enregistrer plutôt un fichier de mots';

  @override
  String get backupWordsFileWarning =>
      'Si vous enregistrez les mots dans un fichier, mettez-le ailleurs que le paquet : pas dans le même dossier, ni sur le même téléphone, ni dans le même compte en ligne.';

  @override
  String backupFingerprintLine(String fingerprint) {
    return 'Empreinte : $fingerprint (le paquet et les mots affichent la même)';
  }

  @override
  String get backupStepDone => 'TERMINÉ';

  @override
  String get backupSavedBoth => 'J’AI ENREGISTRÉ LES DEUX';

  @override
  String get backupShareFailed =>
      'Impossible d’ouvrir le menu de partage. Réessayez.';

  @override
  String get commonCopiedProtected =>
      'Copié. Signet l’efface du presse-papiers au bout d’une minute, ou à votre prochain retour dans Signet.';

  @override
  String get commonCopiedPlain => 'Copié dans le presse-papiers.';

  @override
  String get commonCopyFailed => 'Impossible de copier. Réessayez.';

  @override
  String backupPackageCopiedSnackbar(String copied) {
    return '$copied Collez-le maintenant ailleurs que sur ce téléphone, puis touchez « Je l’ai enregistré autrement ».';
  }

  @override
  String get commonStoreSeparatelyHeader => 'À RANGER SÉPARÉMENT //';

  @override
  String get commonRememberHeader => 'À RETENIR //';

  @override
  String get commonPakeSecretHeader => 'SECRET PAKE //';

  @override
  String get commonPairTimePhraseHeader => 'PHRASE DE CONTRÔLE //';

  @override
  String get commonNameThisContactHeader => 'NOMMER CE CONTACT //';

  @override
  String get commonNameHintExample => 'ex. : Alice';

  @override
  String get labelRejectEmpty => 'Saisissez un nom pour ce contact.';

  @override
  String get labelRejectData =>
      'Cela ressemble à des données Signet, pas à un nom. Essayez par exemple « Maman ».';

  @override
  String get labelRejectKey =>
      'Cela ressemble à une clé, pas à un nom. Essayez par exemple « Maman ».';

  @override
  String get labelRejectTooLong =>
      'Ce nom est trop long. Choisissez-en un plus court.';

  @override
  String get labelRestoredFallback => 'Contact restauré';

  @override
  String get labelRestoredSuffix => ' (restauré)';

  @override
  String get scannerCameraErrorTitle => 'L’appareil photo n’a pas démarré';

  @override
  String get scannerCameraErrorBody =>
      'Fermez toute autre application qui utilise l’appareil photo, puis réessayez.';

  @override
  String get scannerCameraErrorBodyPaste =>
      'Fermez toute autre application qui utilise l’appareil photo, puis réessayez. Vous pouvez aussi coller le texte.';

  @override
  String get scannerRetry => 'Réessayer';

  @override
  String get scannerUsePaste => 'Coller plutôt';

  @override
  String get scannerNotSignetPackage =>
      'Ce code QR n’est pas un paquet Signet. Scannez le code de votre sauvegarde.';

  @override
  String get scannerTitle => 'SCANNER';

  @override
  String get backupImportScanQr => 'Scanner le code QR';

  @override
  String backupImportReplacedLabelNotice(String label) {
    return 'Le nom enregistré dans cette sauvegarde était inutilisable : ce contact est donc restauré sous le nom « $label ». Vous pourrez le renommer ensuite.';
  }

  @override
  String labelLengthCounter(int used, int max) {
    return '$used / $max';
  }

  @override
  String get pairTransportOutYourNameHeader =>
      'VOTRE NOM VU PAR L’AUTRE PERSONNE //';

  @override
  String get pairTransportOutYourNameDescription =>
      'Facultatif. Le téléphone de l’autre personne proposera ce nom pour vous ; elle pourra le modifier. Le chinois, l’arabe et certaines autres écritures prennent plus de place par lettre : choisissez un nom court.';

  @override
  String get pairTransportOutOwnPackageError =>
      'C’est le paquet que vous avez créé. Collez celui que votre contact vous a renvoyé.';

  @override
  String get commonPasteFromClipboard => 'Coller depuis le presse-papiers';

  @override
  String get commonUnlocking => 'OUVERTURE…';

  @override
  String get commonSaving => 'ENREGISTREMENT…';

  @override
  String get commonGenerating => 'CRÉATION…';

  @override
  String get commonCommitPair => 'VALIDER L’ASSOCIATION';

  @override
  String get commonConfirmPairingTitle => 'CONFIRMATION';

  @override
  String commonUnlockFailedError(String error) {
    return 'Impossible d’ouvrir : $error';
  }

  @override
  String commonSaveFailedError(String error) {
    return 'Impossible d’enregistrer : $error';
  }

  @override
  String get pairConfirmSaveIncompleteError =>
      'Signet n’a pas pu finir d’enregistrer cette association. Fermez Signet et rouvrez-le. Si le contact est dans votre liste, c’est enregistré. Sinon, refaites l’association ensemble.';

  @override
  String get pairConfirmRekeySaveIncompleteError =>
      'Le renouvellement de clé n’est pas allé au bout. Refaites-le sur les deux téléphones avant de compter sur Signet pour vérifier ce contact.';

  @override
  String get commonGiveContactName => 'Donnez un nom à ce contact.';

  @override
  String get commonRelationshipNotFound => 'Contact introuvable.';

  @override
  String get commonAirplaneFooter =>
      'Fonctionne hors ligne. Signet ne se connecte jamais à Internet.';

  @override
  String get homeHelpTooltip => 'Aide';

  @override
  String get homeMoreTooltip => 'Plus';

  @override
  String get homeMenuFaq => 'FAQ';

  @override
  String get homeMenuContactUs => 'Nous contacter';

  @override
  String get homeMenuSettings => 'Paramètres';

  @override
  String get homeMenuShowIntro => 'Revoir l’introduction';

  @override
  String get homeMenuAbout => 'À propos';

  @override
  String homeErrorLoadFailed(String error) {
    return 'Impossible de lire vos contacts associés.\n$error';
  }

  @override
  String get homeTryAgainButton => 'RÉESSAYER';

  @override
  String get homeFabPair => 'ASSOCIER';

  @override
  String get homeEmptyTitle => 'Aucun contact associé pour l’instant.';

  @override
  String get homeEmptyBody =>
      'Associez-vous en personne avec quelqu’un de confiance. Vous pourrez ensuite vous vérifier l’un l’autre lors de n’importe quel appel.';

  @override
  String get homeEmptyPairContactButton => 'ASSOCIER UN CONTACT';

  @override
  String get homeEmptySendPackageButton => 'ENVOYER UN PAQUET';

  @override
  String get homeEmptyHavePackageButton => 'J’AI UN PAQUET';

  @override
  String get homeEmptyRestoreBackupButton => 'RESTAURER UNE SAUVEGARDE';

  @override
  String get homeRenameDialogTitle => 'Renommer le contact';

  @override
  String get homeRenameFieldLabel => 'Nom du contact';

  @override
  String get homeRenameEmptyError => 'Le nom ne peut pas être vide.';

  @override
  String get homeSaveButton => 'Enregistrer';

  @override
  String homeUnpairDialogTitle(String label) {
    return 'Dissocier $label ?';
  }

  @override
  String get homeUnpairDialogBody =>
      'Cela supprime le secret partagé sur cet appareil. Pour vérifier à nouveau, il faudrait refaire l’association depuis le début.';

  @override
  String get homeUnpairConfirmButton => 'Dissocier';

  @override
  String homeUnpairSnackbar(String label) {
    return 'Association avec $label supprimée.';
  }

  @override
  String get homeUndoAction => 'ANNULER';

  @override
  String get homePairMenuInPerson => 'Associer en personne';

  @override
  String get homePairMenuInPersonSubtitle =>
      'Les deux téléphones ensemble, chacun scanne l’autre';

  @override
  String get homePairMenuSendPackage => 'Envoyer un paquet';

  @override
  String get homePairMenuSendPackageSubtitle =>
      'Associer une personne éloignée par un moyen de confiance';

  @override
  String get homePairMenuHavePackage => 'J’ai un paquet';

  @override
  String get homePairMenuHavePackageSubtitle =>
      'Importer le paquet d’une autre personne';

  @override
  String get homePairMenuRestoreBackup => 'Restaurer une sauvegarde';

  @override
  String get homePairMenuRestoreBackupSubtitle =>
      'Récupérer un contact associé grâce à votre sauvegarde papier';

  @override
  String homeRowMenuRename(String label) {
    return 'Renommer $label';
  }

  @override
  String get homeRowMenuHapticsOn => 'Activer les vibrations';

  @override
  String get homeRowMenuHapticsOff => 'Désactiver les vibrations';

  @override
  String get homeRowMenuShowBinding => 'Afficher la phrase d’association';

  @override
  String get homeRowMenuVerifyVideo => 'Vérifier (appel vidéo)';

  @override
  String get homeRowMenuVerifyVideoSubtitle =>
      'Ajoute un geste à vérifier : résiste aux deepfakes';

  @override
  String get homeRowMenuCrGrid => 'Grille question-réponse';

  @override
  String get homeRowMenuCrGridSubtitle =>
      'En secours, si l’autre personne n’a pas de téléphone';

  @override
  String homeRowMenuRekey(String label) {
    return 'Renouveler la clé avec $label';
  }

  @override
  String get homeRowMenuRekeySubtitle =>
      'Renouveler le secret partagé, en personne';

  @override
  String get homeRowMenuBackupPaper => 'Sauvegarder sur papier';

  @override
  String get homeRowMenuBackupPaperSubtitle =>
      'Pour restaurer sur un nouveau téléphone si vous perdez celui-ci';

  @override
  String homeRowMenuUnpair(String label) {
    return 'Dissocier $label';
  }

  @override
  String get homeDebugBannerSemantics =>
      'Journal de débogage actif. Touchez deux fois pour le gérer dans les Paramètres.';

  @override
  String get homeDebugBannerText =>
      'JOURNAL DE DÉBOGAGE ACTIF : enregistrement de l’activité de l’application';

  @override
  String get homeSectionRelationships => 'CONTACTS //';

  @override
  String homeRowMetadata(String role, String fingerprint, String date) {
    return 'rôle : $role · $fingerprint · $date';
  }

  @override
  String get homeHapticsOffChip => 'VIBRATIONS // COUPÉES';

  @override
  String get aboutTitle => 'À PROPOS';

  @override
  String get aboutSectionSignet => 'SIGNET';

  @override
  String get aboutIntroBody =>
      'Authentification cryptographique à plusieurs facteurs pour les relations humaines. Protège contre les arnaques téléphoniques par deepfake vocal et vidéo grâce à des codes changeants, d’appareil à appareil. Aucun serveur, conçu pour fonctionner hors ligne.';

  @override
  String aboutVersionLabel(String version) {
    return 'Version : $version';
  }

  @override
  String get aboutSectionLicense => 'LICENCE';

  @override
  String get aboutLicenseBody =>
      'AGPL-3.0-only. Signet est un logiciel libre : vous pouvez l’utiliser, le modifier et le redistribuer selon les termes de la GNU Affero General Public License version 3.';

  @override
  String get aboutSectionSource => 'CODE SOURCE';

  @override
  String get aboutSourceBody =>
      'Le code source, le suivi des problèmes et les fichiers des versions se trouvent sur GitHub.';

  @override
  String get aboutOpenRepositoryButton => 'OUVRIR LE DÉPÔT';

  @override
  String get aboutSectionPrivacy => 'CONFIDENTIALITÉ';

  @override
  String get aboutPrivacyBody =>
      'Signet ne collecte rien. Il n’envoie rien. Il n’y a ni serveur, ni compte, ni télémétrie.';

  @override
  String get aboutPrivacyPolicyButton => 'POLITIQUE DE CONFIDENTIALITÉ';

  @override
  String get aboutSectionReportBug => 'SIGNALER UN PROBLÈME';

  @override
  String get aboutReportBugBody =>
      'Vous avez trouvé un problème ? Ouvrez un ticket sur GitHub. Indiquez l’appareil, la version du système et les étapes qui l’ont déclenché.';

  @override
  String get aboutOpenIssuesButton => 'VOIR LES TICKETS';

  @override
  String get aboutSectionSupport => 'SOUTENIR LE PROJET';

  @override
  String get aboutSupportBody =>
      'Si Signet vous est utile, pensez à m’offrir un café. Signet est maintenu par une seule personne, et l’application n’a ni version payante ni offre à acheter. Le soutien est facultatif et apprécié.';

  @override
  String get aboutBuyMeCoffeeButton => 'OFFREZ-MOI UN CAFÉ';

  @override
  String get aboutCopyright => '© digital-grease';

  @override
  String get crashReportTitle => 'Signet a rencontré un problème';

  @override
  String get crashReportIntroBody =>
      'L’app s’est arrêtée brutalement lors de votre dernière session. Envoyer le rapport nous aide à corriger le problème.';

  @override
  String get crashReportContainsHeading => 'Le rapport contient :';

  @override
  String get crashReportBulletDevice =>
      'Votre appareil, son système et la version de l’application';

  @override
  String get crashReportBulletStack =>
      'Une trace d’exécution, où tout élément cryptographique (secrets d’association, codes de vérification, contenu des sauvegardes) est remplacé par des marqueurs [redacted:N] avant de quitter votre téléphone.';

  @override
  String get crashReportChooseHeading => 'Choisissez comment l’envoyer :';

  @override
  String get crashReportDismissButton => 'FERMER';

  @override
  String get crashReportCopyLogButton => 'COPIER LE JOURNAL';

  @override
  String get crashReportFileIssueButton => 'OUVRIR UN TICKET';

  @override
  String get crashReportCopiedSnackbar =>
      'Journal de plantage copié dans le presse-papiers.';

  @override
  String get crashReportOpenFailedSnackbar =>
      'Impossible d’ouvrir le navigateur. Le journal de plantage a été copié dans le presse-papiers pour que vous puissiez le coller vous-même.';

  @override
  String get crashReportTruncatedSnackbar =>
      'La trace était longue : le journal complet est dans votre presse-papiers. Collez-le sur GitHub sous le marqueur de troncature.';

  @override
  String get faqTitle => 'FAQ';

  @override
  String get faqQ1 => 'Que fait Signet, concrètement ?';

  @override
  String get faqA1 =>
      'Signet vous permet de confirmer qu’une personne qui vous appelle, vous écrit ou vous parle en vidéo est bien celle qu’elle prétend être, même si sa voix semble juste, qu’elle connaît des détails de sa vie et qu’elle demande quelque chose d’urgent. Vous vous associez une fois, en personne, avec quelqu’un de confiance. Ensuite, chacun de vous peut demander à l’autre un code de 4 mots que seul le vrai téléphone associé peut produire.';

  @override
  String get faqQ2 => 'Que prouve vraiment « vérifié » ?';

  @override
  String get faqA2 =>
      'Cela prouve que la personne au bout du fil a physiquement accès au téléphone associé au vôtre, et que ce téléphone n’a pas été piraté. Cela ne prouve pas que sa voix est réelle : un deepfake qui pourrait aussi forcer quelqu’un à lire un code sur le vrai téléphone passerait quand même la vérification. Le rôle de Signet est de rendre l’attaque bien plus coûteuse : il ne suffit plus de « copier une voix », il faut aussi « voler un téléphone déverrouillé ».';

  @override
  String get faqQ3 => 'Pourquoi le code de 4 mots change-t-il sans cesse ?';

  @override
  String get faqA3 =>
      'Chaque code est valable 30 secondes. Ainsi, même si un fraudeur enregistre un code pendant un vrai appel, il ne pourra pas le réutiliser plus tard. Signet accepte le code de la période en cours, plus celui d’avant et celui d’après : un léger décalage d’horloge ou une lecture lente ne fait pas échouer une vraie vérification.';

  @override
  String get faqQ4 => 'Et si les codes ne correspondent pas ?';

  @override
  String get faqA4 =>
      'Prenez-le comme un signal d’alarme. Le code d’un vrai contact associé correspond presque toujours du premier coup. Sinon : raccrochez, joignez la personne par un autre moyen que vous connaissez déjà (son numéro habituel, en personne, un ami commun) et vérifiez avant de donner suite à sa demande.';

  @override
  String get faqQ5 => 'Signet peut-il voir mes associations ou mes codes ?';

  @override
  String get faqA5 =>
      'Non. Signet n’a ni serveur, ni compte, ni télémétrie, ni statistiques d’utilisation. Sur Android, il ne demande même pas l’autorisation d’accéder à Internet. Vos secrets partagés restent dans la zone sécurisée de votre téléphone (Keychain/Keystore) et ne quittent pas l’appareil. Si Signet disparaissait demain, rien de ce qui vous appartient ne disparaîtrait avec lui.';

  @override
  String get faqQ6 => 'Et si je perds mon téléphone ?';

  @override
  String get faqA6 =>
      'Si vous aviez fait une sauvegarde avant de le perdre, vous pouvez restaurer le contact associé sur un nouveau téléphone avec « Restaurer une sauvegarde ». L’autre personne n’a rien à faire et ne sait même pas qu’une restauration a eu lieu. Sans sauvegarde, l’association est perdue : il faudra refaire l’association en personne avec ce contact sur le nouvel appareil.';

  @override
  String get faqQ12 => 'Comment garder une sauvegarde en sécurité ?';

  @override
  String get faqA12 =>
      'Une sauvegarde a deux parties : un fichier PACKAGE (le paquet), qui est verrouillé, et 8 mots, qui l’ouvrent. Gardez-les séparés. Enregistrez le fichier PACKAGE ailleurs que sur le téléphone, par exemple sur votre ordinateur ou une clé USB. Écrivez les 8 mots sur papier et rangez ce papier ailleurs, par exemple dans votre portefeuille. Quiconque trouve les deux parties peut se faire passer pour vous auprès de vos contacts : ne les gardez jamais ensemble et n’envoyez jamais les mots par message. Pour restaurer, touchez « Restaurer une sauvegarde », chargez le fichier PACKAGE, puis tapez les 8 mots (ou chargez le fichier WORDS).';

  @override
  String get faqQ7 => 'Puis-je m’associer avec plusieurs personnes ?';

  @override
  String get faqA7 =>
      'Oui. Ajoutez-en autant que vous voulez : chaque association est indépendante. Chaque contact a son propre secret ; si une association est compromise, les autres ne sont ni révélées ni touchées.';

  @override
  String get faqQ8 => 'Qu’est-ce que la grille question-réponse ?';

  @override
  String get faqA8 =>
      'Une solution de secours hors ligne, pour quand l’autre personne ne peut pas accéder à son téléphone. Vous avez tous les deux la même grille de 8 × 8 mots de code, tirée de votre secret partagé. Vous demandez par exemple « quelle est la réponse pour la case X × Y ? », l’autre personne la cherche (dans l’application ou sur une carte imprimée) et vous lit la réponse de trois mots. Si elle correspond à ce qu’affiche votre application, l’association est authentique.';

  @override
  String get faqQ9 =>
      'Pourquoi la vérification en appel vidéo demande-t-elle un geste ?';

  @override
  String get faqA9 =>
      'Les deepfakes vocaux et vidéo créés par IA s’améliorent sans cesse. Un deepfake en temps réel qui vous entend demander les 4 mots ne peut pas les deviner : ils viennent du téléphone associé, et c’est pour cela que la vérification simple fonctionne. En revanche, un deepfake qui vous entend lire à voix haute une consigne au hasard comme « touchez votre oreille » peut imiter ce geste aussitôt. Signet tire donc le geste, lui aussi, du secret partagé : seul le vrai téléphone associé sait quel geste est attendu pendant cette période. En mode APPEL VIDÉO, il faut À LA FOIS les 4 bons mots ET que l’autre personne fasse le geste attendu. Un deepfake sans le téléphone associé ne peut que deviner, et ses chances tombent à environ 1 sur 100 000 milliards par période de 30 secondes. Si vous utilisez un lecteur d’écran, portez un casque ou des écouteurs pendant l’appel : Signet ne lit jamais le geste à voix haute de lui-même, mais toucher la ligne À OBSERVER le fait lire, et sur haut-parleur l’autre personne pourrait l’entendre.';

  @override
  String get faqQ10 =>
      'Pourquoi pas de compte ? Et si je dois tout récupérer ?';

  @override
  String get faqA10 =>
      'Un compte, c’est un serveur, un mot de passe et un chemin qu’un fraudeur (ou une décision de justice) peut emprunter pour atteindre vos associations sans toucher votre téléphone. Signet existe justement parce que ces chemins existent pour tous les autres outils d’authentification. La récupération se fait à la main : faites une sauvegarde maintenant, tant que tout est calme, et rangez-la là où vous pourrez la retrouver si vous perdez le téléphone.';

  @override
  String get faqQ11 => 'Quelqu’un me demande de sauter la vérification.';

  @override
  String get faqA11 =>
      'Ne la sautez pas. Un vrai contact associé comprend pourquoi la vérification existe et ne vous poussera pas à la contourner. L’urgence plus une demande de sauter la vérification, c’est exactement la méthode d’un escroc pour court-circuiter le filet de sécurité. Si on vous met la pression, considérez l’appel comme hostile jusqu’à preuve du contraire.';

  @override
  String get faqQ13 => 'Signet dit qu’il a besoin d’une mise à jour.';

  @override
  String get faqA13 =>
      'Signet change parfois la façon dont ses codes d’association et ses sauvegardes sont créés, et une version plus ancienne ne peut pas lire le nouveau format.\n\nSi un code ou une sauvegarde vient d’une version plus récente de Signet, il indique que ce téléphone doit être mis à jour. Lors d’une association, si l’autre téléphone a une version plus ancienne, il indique que l’autre téléphone doit être mis à jour. Pour s’associer, les deux téléphones doivent avoir Signet 0.4.0 ou plus récent. Une sauvegarde peut être restaurée avec la même version de Signet ou une plus récente.\n\nFaites la mise à jour uniquement depuis la boutique d’applications où vous avez installé Signet. Signet n’envoie jamais de mise à jour sous forme de lien ou de fichier. Si quelqu’un vous en envoie une, ou vous pousse à installer quelque chose pour terminer l’association, c’est une arnaque.\n\nSignet 0.3.6 et les versions plus anciennes ne peuvent pas afficher ce message. Elles indiquent à la place que le code n’est pas un code Signet.';

  @override
  String get faqStillStuckHeader => 'BESOIN D’AIDE //';

  @override
  String get faqStillStuckBody =>
      'Vous n’avez pas trouvé votre réponse ici ? Ouvrez un ticket sur GitHub. Indiquez votre appareil, la version du système et ce que vous essayiez de faire.';

  @override
  String get faqContactUsButton => 'NOUS CONTACTER';

  @override
  String get onboardingSkipButton => 'PASSER';

  @override
  String get onboardingBriefingTag1 => 'À SAVOIR // 01';

  @override
  String get onboardingBriefingTag2 => 'À SAVOIR // 02';

  @override
  String get onboardingBriefingTag3 => 'À SAVOIR // 03';

  @override
  String get onboardingSlide1Title => 'Vérifiez qui est au bout du fil.';

  @override
  String get onboardingSlide1Body =>
      'Une voix ou une vidéo truquée par deepfake peut imiter n’importe qui : un proche, un collègue, une source. Quand quelqu’un appelle en urgence pour demander de l’argent, de l’aide ou un accès, Signet vous permet de lui demander 4 mots changeants que seul son vrai téléphone peut produire. Si les mots correspondent, c’est bien la bonne personne.';

  @override
  String get onboardingSlide2Title => 'Associez-vous une fois, en personne.';

  @override
  String get onboardingSlide2Body =>
      'Vous associez deux téléphones en scannant chacun le code QR de l’autre, quand vous êtes ensemble. Le secret partagé reste sur les deux appareils : protégé par le matériel, hors ligne, sans cloud. Rien qu’un juge puisse réclamer. Rien à hameçonner. Rien à synchroniser avec un serveur qui n’existe pas.';

  @override
  String get onboardingSlide3Title => 'Demandez les mots.';

  @override
  String get onboardingSlide3Body =>
      'Pendant l’appel, ouvrez Signet, touchez le nom de la personne et demandez-lui de lire ses 4 mots. Tapez ce que vous entendez. Bandeau vert = vérifié, vous pouvez faire confiance à l’appel. Bandeau rouge = ne faites pas confiance. Raccrochez et rappelez un numéro que vous connaissez déjà.';

  @override
  String get onboardingContinueButton => 'CONTINUER';

  @override
  String get pairStartTitle => 'Associer un contact';

  @override
  String get pairStartHeading => 'Comment s’appelle cette personne ?';

  @override
  String get pairStartPrivacyNote =>
      'Enregistré uniquement sur votre téléphone. Choisissez un nom que vous reconnaîtrez d’un coup d’œil : « Maman », « Jake », « Équipe finance ».';

  @override
  String get pairStartNameLabel => 'Nom';

  @override
  String get pairStartEmptyNameError =>
      'Veuillez saisir un nom pour ce contact.';

  @override
  String get pairStartContinueButton => 'Continuer';

  @override
  String pairExchangeTitlePair(String contact) {
    return 'Association avec $contact';
  }

  @override
  String pairExchangeTitleRekey(String contact) {
    return 'Renouveler la clé avec $contact';
  }

  @override
  String get pairExchangeFallbackContact => 'ce contact';

  @override
  String get pairInPersonIntro =>
      'Tenez vos téléphones côte à côte, dans la même pièce. Scannez uniquement l’autre téléphone lui-même, jamais une photo ni un appel vidéo : ces codes-là peuvent être remplacés.';

  @override
  String get pairInPersonRoleHint =>
      'Décidez à voix haute qui commence. Sur ce téléphone-là, touchez Démarrer. Sur l’autre, touchez Rejoindre.';

  @override
  String get pairInPersonNextButton => 'SUIVANT';

  @override
  String get pairInPersonNextHint =>
      'Touchez SUIVANT quand l’autre téléphone affiche son propre code.';

  @override
  String get pairInPersonShowWordsButton => 'AFFICHER LES MOTS';

  @override
  String get pairInPersonFinishHint =>
      'Touchez AFFICHER LES MOTS quand l’autre téléphone affiche 4 mots.';

  @override
  String get pairInPersonShowAgainButton => 'Réafficher mon code';

  @override
  String get pairInPersonQrLabel => 'Code QR d’association';

  @override
  String get pairCodeAlreadyScannedNotice =>
      'Déjà scanné. Attendez le code suivant de l’autre téléphone.';

  @override
  String get pairInPersonPasteFromClipboard =>
      'COLLER DEPUIS LE PRESSE-PAPIERS';

  @override
  String pairInPersonCopiedSnackbar(String status) {
    return '$status Transmettez-le vous-même à l’autre téléphone, puis vérifiez les 4 mots ensemble, en personne.';
  }

  @override
  String get pairInPersonStartButton => 'DÉMARRER';

  @override
  String get pairInPersonStartSubtitle =>
      'Ce téléphone montre son code en premier.';

  @override
  String get pairInPersonJoinButton => 'REJOINDRE';

  @override
  String get pairInPersonJoinSubtitle =>
      'Ce téléphone scanne l’autre en premier.';

  @override
  String pairInPersonStepLabel(int step) {
    return 'Étape $step sur 3';
  }

  @override
  String get pairInPersonShowHeading =>
      'Laissez l’autre téléphone scanner ce code.';

  @override
  String get pairInPersonShowRevealHeading =>
      'Laissez l’autre téléphone scanner aussi celui-ci.';

  @override
  String get pairInPersonScanHeading => 'Scannez l’autre téléphone.';

  @override
  String get pairInPersonScanRevealHeading =>
      'Scannez l’autre téléphone encore une fois.';

  @override
  String get pairInPersonPreparing => 'Préparation…';

  @override
  String get pairInPersonDeriving => 'Calcul des mots…';

  @override
  String get pairInPersonJoinIdleHint =>
      'Rien n’a encore été scanné. L’autre téléphone est-il sur Démarrer, avec un code affiché ? Si les deux téléphones ont touché Rejoindre, touchez RECOMMENCER sur les deux, puis un seul téléphone touche Démarrer.';

  @override
  String get pairInPersonStartIdleHint =>
      'Rien n’a encore été scanné. L’autre téléphone est-il sur Rejoindre, avec un code affiché ? Si les deux téléphones ont touché Démarrer, touchez RECOMMENCER sur les deux, puis un seul téléphone touche Rejoindre.';

  @override
  String get pairInPersonShowAsText => 'Afficher le code en texte';

  @override
  String get pairInPersonShowAsQr => 'Afficher le code QR';

  @override
  String get pairInPersonCopyCode => 'COPIER LE CODE';

  @override
  String get pairInPersonPasteInstead => 'Coller un code à la place';

  @override
  String get pairInPersonPasteHeading => 'Collez le code de l’autre téléphone';

  @override
  String get pairInPersonPasteLabel => 'Code';

  @override
  String get pairInPersonPasteSubmit => 'UTILISER CE CODE';

  @override
  String get pairInPersonPasteEmptyError =>
      'Collez d’abord le code de l’autre téléphone.';

  @override
  String get pairInPersonBackToCamera => 'Revenir à l’appareil photo';

  @override
  String get pairInPersonStartOverButton => 'RECOMMENCER';

  @override
  String get pairInPersonStartOverBoth =>
      'Sur les deux téléphones, touchez RECOMMENCER, ou « Ça ne correspond pas, recommencer » si un téléphone affiche déjà des mots. Ensuite, un téléphone touche Démarrer et l’autre Rejoindre.';

  @override
  String get pairCodeMalformedNotice =>
      'Ce code est incomplet ou abîmé. Scannez-le ou collez-le à nouveau.';

  @override
  String get pairCodeNotPairingNotice =>
      'Ce n’est pas un code d’association Signet. Scannez le code affiché sur l’écran d’association de l’autre téléphone.';

  @override
  String get pairCodeMultipleNotice => 'Collez un seul code à la fois.';

  @override
  String get pairCodePeerNeedsUpdateNotice =>
      'L’autre téléphone a une version plus ancienne de Signet. Il doit être mis à jour avant l’association. Mettez Signet à jour uniquement depuis la boutique d’applications où vous l’avez installé. Signet n’envoie jamais de mise à jour sous forme de lien ou de fichier.';

  @override
  String get pairCodeThisNeedsUpdateNotice =>
      'Ce code vient d’une version plus récente de Signet. Mettez d’abord Signet à jour sur ce téléphone, uniquement depuis la boutique d’applications où vous l’avez installé. Signet n’envoie jamais de mise à jour sous forme de lien ou de fichier.';

  @override
  String get pairFailStartStart =>
      'Ce téléphone a scanné un code Démarrer. Un téléphone doit toucher Démarrer et l’autre Rejoindre.';

  @override
  String get pairFailJoinJoin =>
      'Ce téléphone a scanné un code Rejoindre. Un téléphone doit toucher Démarrer et l’autre Rejoindre.';

  @override
  String get pairFailSecondCode =>
      'Un autre code a été scanné en cours de route : cette tentative a été arrêtée par sécurité.';

  @override
  String get pairFailWrongCode =>
      'Ce code appartient à une autre étape : cette tentative a été arrêtée par sécurité.';

  @override
  String get pairFailRevealMismatch =>
      'Arrêtez. Le dernier code ne correspond pas au premier. Quelqu’un essaie peut-être d’intervenir. Si l’autre téléphone affiche des mots, touchez « Ça ne correspond pas » dessus. N’enregistrez pas cette association.';

  @override
  String get pairFailTimedOut =>
      'Cela a pris trop de temps : la tentative a été arrêtée.';

  @override
  String get pairFailInternal => 'Un problème est survenu sur ce téléphone.';

  @override
  String get pairExchangeCameraPermissionTitle =>
      'L’accès à l’appareil photo est désactivé.';

  @override
  String pairExchangeCameraPermissionBody(String path) {
    return 'Signet utilise l’appareil photo uniquement pour scanner les codes QR d’association. Activez-le dans les réglages de votre téléphone : $path.';
  }

  @override
  String get pairCameraSettingsPathIos => 'Réglages → Signet → Appareil photo';

  @override
  String get pairCameraSettingsPathAndroid =>
      'Applications → Signet → Autorisations → Appareil photo';

  @override
  String get pairConfirmTitle => 'Confirmer';

  @override
  String get pairConfirmRekeyTitle => 'Confirmer le renouvellement de clé';

  @override
  String get pairConfirmHeading => 'Est-ce identique sur l’autre téléphone ?';

  @override
  String get pairConfirmInstructions =>
      'Lisez les mots à voix haute. Les quatre mots doivent être identiques sur les deux appareils.';

  @override
  String get pairConfirmMatchButton => 'Ça correspond';

  @override
  String get pairConfirmMismatchButton => 'Ça ne correspond pas, recommencer';

  @override
  String get pairConfirmMismatchDialogTitle =>
      'Les phrases ne correspondent pas ?';

  @override
  String get pairConfirmMismatchDialogBody =>
      'Si votre phrase et la sienne ne correspondent pas, quelque chose s’est mal passé : un mauvais scan, ou quelqu’un qui essaie de s’interposer. Il est plus sûr d’abandonner cette association et de recommencer.';

  @override
  String get pairConfirmStartOverButton => 'Recommencer';

  @override
  String pairConfirmRekeySnackbar(String label) {
    return 'Clé renouvelée avec $label.';
  }

  @override
  String pairConfirmPairedSnackbar(String label) {
    return 'Association avec $label enregistrée.';
  }

  @override
  String get pairConfirmStateIncompleteError =>
      'Les données d’association sont incomplètes.';

  @override
  String get pairConfirmRekeyTargetMissingError =>
      'Le contact dont la clé devait être renouvelée n’est plus associé.';

  @override
  String get pairCompleteTitle => 'ASSOCIÉS';

  @override
  String get pairCompleteCommittedHeader => 'ASSOCIATION VALIDÉE //';

  @override
  String get pairCompleteHeading =>
      'Vous êtes encore ensemble.\nEssayez une vérification.';

  @override
  String pairCompletePracticeBody(String label) {
    return 'C’est le moment le plus simple pour vous entraîner. Demandez à $label d’ouvrir Signet, de toucher votre nom et de lire les 4 mots de son écran « Afficher mes 4 mots ». Tapez ce que vous entendez dans votre champ de vérification. Quand le bandeau vert apparaît, vous savez que ça marche pour de vrai.';
  }

  @override
  String get pairCompleteRemoteHeading =>
      'Associés à distance.\nEntraînez-vous lors de votre prochain appel.';

  @override
  String pairCompleteRemoteBody(String label) {
    return 'La prochaine fois que vous parlerez avec $label, demandez-lui d’ouvrir Signet, de toucher votre nom et de lire les 4 mots de son écran « Afficher mes 4 mots ». Tapez ce que vous entendez dans votre champ de vérification. Quand le bandeau vert apparaît, vous savez que ça marche pour de vrai.';
  }

  @override
  String pairCompleteRemoteWaitNote(String label) {
    return 'La vérification fonctionnera une fois que $label aura collé votre paquet de réponse.';
  }

  @override
  String get pairCompleteFallbackPeer => 'votre contact';

  @override
  String get pairCompleteTipBody =>
      'Vous pouvez passer et vérifier plus tard depuis l’accueil. Mais vous n’aurez jamais d’entraînement plus facile que maintenant.';

  @override
  String pairCompleteVerifyNowButton(String label) {
    return 'VÉRIFIER $label MAINTENANT';
  }

  @override
  String get pairCompleteSkipButton => 'LE FAIRE PLUS TARD';

  @override
  String get pairTransportInImportTitle => 'IMPORTER UN PAQUET';

  @override
  String get pairTransportInIncomingHeader => 'PAQUET REÇU //';

  @override
  String get pairTransportInPasteInstruction =>
      'Collez le texte que l’autre personne vous a donné. Il commence par « signet:tp1: ».';

  @override
  String get pairTransportInPakeDescription =>
      'Les 8 mots que l’autre personne vous a transmis par un moyen de confiance (papier, e-mail chiffré, note d’une rencontre précédente). N’acceptez pas ces mots lors d’un appel vocal non vérifié.';

  @override
  String get pairTransportInUnlockButton => 'OUVRIR LE PAQUET';

  @override
  String get pairTransportInPasteEmptyError =>
      'Collez le paquet de l’autre personne.';

  @override
  String get pairTransportInWordsIncompleteError =>
      'Saisissez les 8 mots de l’autre personne.';

  @override
  String pairTransportInProcessFailedError(String error) {
    return 'Impossible de traiter le paquet : $error';
  }

  @override
  String get pairTransportInPhraseInstruction =>
      'Vérifiez les 8 mots, un par un et dans l’ordre, et que les deux téléphones en affichent exactement 8. Faites-le avec l’autre personne face à face, ou en l’appelant à un numéro que vous aviez déjà. Pas par message, et jamais lors d’un appel ou à un numéro que quelqu’un vous a donné. S’ils correspondent, le paquet est authentique.';

  @override
  String get pairTransportInResponseHeader => 'VOTRE RÉPONSE //';

  @override
  String get pairTransportInResponseInstruction =>
      'Renvoyez ceci à l’autre personne, par le même moyen que celui qu’elle a utilisé pour vous envoyer son paquet. Elle le collera pour terminer l’association.';

  @override
  String get pairTransportInCopyResponseButton => 'Copier la réponse';

  @override
  String get pairTransportOutNewPackageTitle => 'NOUVEAU PAQUET';

  @override
  String get pairTransportOutShareWaitTitle => 'PARTAGER ET ATTENDRE';

  @override
  String get pairTransportOutNameDescription =>
      'Le nom qui apparaîtra sur votre écran d’accueil pour ce contact. Il n’est visible que par vous.';

  @override
  String get pairTransportOutGenerateButton => 'CRÉER LE PAQUET';

  @override
  String pairTransportOutGenerateError(String error) {
    return 'Impossible de créer le paquet : $error';
  }

  @override
  String get pairTransportOutOutgoingHeader => 'PAQUET À ENVOYER //';

  @override
  String pairTransportOutOutgoingInstruction(String label) {
    return 'Envoyez ce texte à $label. E-mail chiffré, Signal, courrier papier, code QR imprimé : tout moyen convient. Il n’est utile qu’à quelqu’un qui a aussi les 8 mots ci-dessous.';
  }

  @override
  String get pairTransportOutChannelWarning =>
      'Envoyez les 8 mots par un moyen DIFFÉRENT de celui du paquet. Jamais lors d’un appel ou à un numéro que quelqu’un vous a donné. Un papier, un souvenir d’une rencontre passée ou un autre contact déjà associé dans Signet sont tous plus sûrs que de les dire à voix haute.';

  @override
  String get pairTransportOutReceiveHeader => 'RECEVOIR LA RÉPONSE //';

  @override
  String pairTransportOutReceiveInstruction(String label) {
    return '$label va vous envoyer un paquet de réponse. Collez-le ici.';
  }

  @override
  String get pairTransportOutPasteEmptyError =>
      'Collez le paquet de réponse de l’autre personne.';

  @override
  String get pairTransportOutUnlockResponseButton => 'OUVRIR LA RÉPONSE';

  @override
  String pairTransportOutUnlockFailedError(String error) {
    return 'Impossible d’ouvrir la réponse : $error';
  }

  @override
  String get pairingWeakKeyInPersonError =>
      'Arrêtez. Ce code n’est pas sûr. Annulez l’association sur les deux téléphones et recommencez. Ne vous fiez à aucun mot affiché par l’un ou l’autre téléphone.';

  @override
  String get pairingWeakKeyRemoteError =>
      'Ce paquet n’est pas sûr. Quelqu’un l’a peut-être modifié. Fermez cet écran, créez un nouveau paquet et envoyez-le par un autre moyen que la première fois. Ne vous fiez à aucun mot affiché par l’un ou l’autre téléphone.';

  @override
  String pairTransportOutPhraseInstruction(String label) {
    return 'Vérifiez les 8 mots, un par un et dans l’ordre, et que les deux téléphones en affichent exactement 8. Faites-le avec $label face à face, ou en appelant un numéro que vous aviez déjà. Pas par message, et jamais lors d’un appel ou à un numéro que quelqu’un vous a donné. S’ils correspondent, l’association est authentique.';
  }

  @override
  String get backupExportTitle => 'SAUVEGARDER SUR PAPIER';

  @override
  String backupExportGenerateError(String error) {
    return 'Impossible de créer la sauvegarde : $error';
  }

  @override
  String backupExportHeading(String label) {
    return 'Sauvegarder $label';
  }

  @override
  String backupExportIntro(String label) {
    return 'Une sauvegarde vous permet de restaurer cette association sur un nouveau téléphone si vous perdez celui-ci. $label ne verra aucun changement sur son téléphone.';
  }

  @override
  String get backupExportStoreSeparatelyBody =>
      'Cette sauvegarde a deux parties : le paquet et les 8 mots qui l’ouvrent. Rangez-les à des endroits différents. Quiconque trouve les deux peut restaurer cette association sur son propre téléphone.';

  @override
  String backupExportRememberBody(String label) {
    return 'Si quelqu’un d’autre trouve un jour à la fois le paquet et les 8 mots, dissociez $label tout de suite et refaites l’association en personne. La sauvegarde contient le même secret que votre association actuelle.';
  }

  @override
  String get backupImportRestoreTitle => 'RESTAURATION';

  @override
  String get backupImportConfirmTitle => 'CONFIRMER';

  @override
  String get backupImportFileTooLargeError =>
      'Ce fichier est trop gros pour être une sauvegarde Signet. Choisissez le petit fichier texte enregistré lors de la sauvegarde.';

  @override
  String get backupImportFileReadError =>
      'Impossible de lire le fichier choisi. Essayez de le choisir à nouveau.';

  @override
  String get backupImportPasteEmptyError =>
      'Chargez ou collez d’abord le paquet de sauvegarde.';

  @override
  String get backupImportWordsIncompleteError =>
      'Saisissez les 8 mots de la sauvegarde.';

  @override
  String get backupImportPackageHeader => 'ÉTAPE 1 // LE PAQUET';

  @override
  String get backupImportLoadPackageFile => 'Charger le fichier PACKAGE';

  @override
  String get backupImportWordsHeader => 'ÉTAPE 2 // LES 8 MOTS';

  @override
  String get backupImportLoadWordsFile => 'Charger le fichier WORDS (les mots)';

  @override
  String get backupImportIsWordsError =>
      'Ce sont les 8 mots, pas le paquet. Mettez-les à l’étape 2.';

  @override
  String get backupImportIsPackageError =>
      'C’est le paquet, pas les mots. Mettez-le à l’étape 1.';

  @override
  String get backupImportNoWordsError =>
      'Aucun mot de sauvegarde trouvé ici. Cherchez une ligne de 8 mots.';

  @override
  String backupImportFingerprintMismatchError(String package, String words) {
    return 'Ces mots appartiennent à une autre sauvegarde (paquet $package, mots $words). Cherchez les mots dont l’empreinte est $package.';
  }

  @override
  String get backupImportLegacyNotice =>
      'Cette ancienne sauvegarde garde les mots et le paquet ensemble dans un seul fichier. Après la restauration, faites une nouvelle sauvegarde et supprimez ce fichier.';

  @override
  String get backupImportNotBackupError =>
      'Ce n’est pas une sauvegarde Signet valide.';

  @override
  String get backupImportInvitationError =>
      'C’est une invitation à s’associer, pas une sauvegarde. Associez-vous depuis l’accueil.';

  @override
  String get backupImportClipboardEmptyError => 'Le presse-papiers est vide.';

  @override
  String get backupImportPasteInstruction =>
      'Chargez le fichier PACKAGE ou collez le texte du paquet. Il commence par « signet:tp1: ».';

  @override
  String get backupImportWordsInstruction =>
      'Tapez les 8 mots que vous avez notés, ou chargez le fichier WORDS si vous en avez enregistré un.';

  @override
  String get backupImportUnlockButton => 'OUVRIR LA SAUVEGARDE';

  @override
  String get backupImportRestoredPeerHeader => 'CONTACT RESTAURÉ //';

  @override
  String get backupImportRoleLabel => 'RÔLE //';

  @override
  String get backupImportOriginallyLabel => 'ASSOCIÉ LE //';

  @override
  String get backupImportHapticsLabel => 'VIBRATIONS //';

  @override
  String get backupImportHapticsOff => 'DÉSACTIVÉES';

  @override
  String get backupImportHapticsOn => 'ACTIVÉES';

  @override
  String get backupImportWhatItDoesHeader => 'CE QUE CELA FAIT //';

  @override
  String backupImportWhatItDoesBody(String label) {
    return 'Ce téléphone va partager un secret avec $label, avec les mêmes clés que l’ancien téléphone. $label ne verra aucun changement sur son téléphone. Si la clé a été renouvelée depuis votre sauvegarde, les vérifications échoueront jusqu’à ce que vous refassiez l’association en personne.';
  }

  @override
  String get backupImportCommitButton => 'VALIDER LA RESTAURATION';

  @override
  String get bulkBackupExportSetupTitle => 'TOUT SAUVEGARDER';

  @override
  String get bulkBackupExportReadyTitle => 'SAUVEGARDE PRÊTE';

  @override
  String bulkBackupExportPrepareError(String error) {
    return 'Impossible de préparer la sauvegarde : $error';
  }

  @override
  String get bulkBackupExportNoSecretsError =>
      'Aucun secret de contact n’a pu être lu.';

  @override
  String get bulkBackupExportEmptyTitle => 'Rien à sauvegarder pour l’instant.';

  @override
  String get bulkBackupExportEmptyBody =>
      'Associez-vous d’abord avec quelqu’un, puis revenez ici pour créer une sauvegarde complète.';

  @override
  String bulkBackupExportReadyHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
      one: '$count contact',
    );
    return 'Sauvegarder $_temp0';
  }

  @override
  String get bulkBackupExportReadyBody =>
      'Tous les contacts associés ci-dessous vont dans une seule sauvegarde : un paquet et les 8 mots qui l’ouvrent. Gardez les deux séparés, puis servez-vous-en pour retrouver toutes vos associations sur un nouveau téléphone.';

  @override
  String get bulkBackupExportGenerateButton => 'CRÉER LA SAUVEGARDE COMPLÈTE';

  @override
  String bulkBackupExportDoneHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts sauvegardés',
      one: '$count contact sauvegardé',
    );
    return '$_temp0';
  }

  @override
  String get bulkBackupExportStoreSeparatelyBody =>
      'Cette sauvegarde a deux parties : le paquet et les 8 mots qui l’ouvrent. Rangez-les à des endroits différents. Quiconque trouve les deux peut restaurer toutes les associations sur son propre téléphone.';

  @override
  String get bulkBackupExportWordsInstruction =>
      'Écrivez ces 8 mots en lieu sûr. Vous les taperez sur le nouveau téléphone pour tout ouvrir d’un coup.';

  @override
  String get bulkBackupExportPackageInstruction =>
      'L’ensemble de vos associations, chiffré avec les 8 mots ci-dessus. Partagez-le par n’importe quel moyen : les mots le gardent fermé.';

  @override
  String bulkBackupExportShareSubject(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
      one: '$count contact',
    );
    return 'Sauvegarde complète Signet ($_temp0)';
  }

  @override
  String get bulkBackupExportRememberBody =>
      'Si quelqu’un d’autre trouve un jour à la fois le paquet et les 8 mots, dissociez tous les contacts de cette sauvegarde et refaites les associations en personne. La sauvegarde contient les mêmes secrets que vos associations actuelles.';

  @override
  String get bulkBackupImportTitle => 'RESTAURATION COMPLÈTE';

  @override
  String get bulkBackupImportDoneTitle => 'RESTAURATION FAITE';

  @override
  String bulkBackupImportGenericError(String error) {
    return 'Erreur : $error';
  }

  @override
  String bulkBackupImportPreviewHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
      one: '$count contact',
    );
    return 'Restaurer $_temp0';
  }

  @override
  String get packageNeedsNewerSignetError =>
      'Il faut une version plus récente de Signet. Mettez Signet à jour uniquement depuis la boutique d’applications où vous l’avez installé. Signet n’envoie jamais de mise à jour sous forme de lien ou de fichier. Si vous ne vous y attendiez pas, parlez-en de vive voix avec la personne qui vous a envoyé ce paquet.';

  @override
  String get packageNeedsNewerSignetVerifiedError =>
      'Ceci a été créé par une version plus récente de Signet. Mettez Signet à jour depuis la boutique d’applications où vous l’avez installé, puis réessayez.';

  @override
  String get packageFromOlderSignetError =>
      'Ceci a été créé par une version plus ancienne de Signet. Pour s’associer à distance, les deux téléphones doivent avoir Signet 0.4.0 ou plus récent. Demandez à l’autre personne de mettre Signet à jour depuis la boutique d’applications où elle l’a installé, puis de créer un nouveau paquet.';

  @override
  String get packageDamagedError =>
      'Ce paquet est abîmé ou incomplet. Vérifiez que vous l’avez copié en entier, ou demandez qu’on vous le renvoie.';

  @override
  String get backupImportRepairedDateNotice =>
      'Une partie de cette sauvegarde était illisible et a été réparée : la date d’association a été remise à aujourd’hui. L’association elle-même n’est pas touchée.';

  @override
  String get backupImportRepairedLabelNotice =>
      'Une partie de cette sauvegarde était illisible et a été réparée : quelques caractères du nom ont été remplacés. Vérifiez le nom avant de restaurer. L’association elle-même n’est pas touchée.';

  @override
  String bulkBackupImportRepairedNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contacts de cette sauvegarde avaient une date ou un nom illisible, qui a été réparé. Ils sont marqués RÉPARÉ ci-dessous ; vérifiez leur nom avant de restaurer.',
      one:
          '$count contact de cette sauvegarde avait une date ou un nom illisible, qui a été réparé. Il est marqué RÉPARÉ ci-dessous ; vérifiez son nom avant de restaurer.',
    );
    return '$_temp0';
  }

  @override
  String bulkBackupImportSkippedNewerNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contacts de cette sauvegarde nécessitent une version plus récente de Signet et ne sont pas affichés. Gardez votre ancien téléphone jusqu’à ce que ces contacts soient restaurés. Mettez Signet à jour uniquement depuis la boutique d’applications où vous l’avez installé, puis relancez la restauration.',
      one:
          '$count contact de cette sauvegarde nécessite une version plus récente de Signet et n’est pas affiché. Gardez votre ancien téléphone jusqu’à ce que ce contact soit restauré. Mettez Signet à jour uniquement depuis la boutique d’applications où vous l’avez installé, puis relancez la restauration.',
    );
    return '$_temp0';
  }

  @override
  String get bulkBackupImportRepairedBadge => 'RÉPARÉ';

  @override
  String get bulkBackupImportSummarySkippedNewer =>
      'SIGNET PLUS RÉCENT REQUIS //';

  @override
  String get bulkBackupImportNoConflictBody =>
      'Cochez les lignes à restaurer. Chaque association ci-dessous reviendra avec son nom et sa date d’association d’origine.';

  @override
  String get bulkBackupImportConflictBody =>
      'Certains de ces contacts sont déjà associés sur ce téléphone. Choisissez quoi faire pour chacun ; par défaut, ils sont ignorés.';

  @override
  String bulkBackupImportProgressText(int committed, int total) {
    return 'Restauration : $committed sur $total…';
  }

  @override
  String get bulkBackupImportRestoringButton => 'RESTAURATION…';

  @override
  String get bulkBackupImportNothingSelectedButton => 'AUCUNE SÉLECTION';

  @override
  String bulkBackupImportRestoreButton(int count) {
    return 'RESTAURER $count';
  }

  @override
  String get bulkBackupImportAlreadyPairedChip => 'DÉJÀ ASSOCIÉ';

  @override
  String bulkBackupImportRecordMeta(String role, String date) {
    return 'RÔLE $role · ASSOCIÉ LE $date';
  }

  @override
  String get bulkBackupImportSkipOption =>
      'Ignorer : garder l’association existante';

  @override
  String bulkBackupImportRenameOption(String label) {
    return 'Le restaurer sous le nom « $label »';
  }

  @override
  String get bulkBackupImportOverwriteOption =>
      'Remplacer l’association existante';

  @override
  String get bulkBackupImportOverwriteUnavailable =>
      'Le remplacement n’est pas proposé ici : plusieurs contacts portent ce nom, ou une autre entrée de cette sauvegarde le remplace déjà.';

  @override
  String get bulkBackupImportCompleteHeading => 'Restauration terminée.';

  @override
  String get bulkBackupImportSummaryRestored => 'RESTAURÉS //';

  @override
  String get bulkBackupImportSummaryRenamed => 'RENOMMÉS //';

  @override
  String get bulkBackupImportSummaryOverwrote => 'REMPLACÉS //';

  @override
  String get bulkBackupImportSummarySkipped => 'IGNORÉS //';

  @override
  String get bulkBackupImportSummaryFailed => 'NON ENREGISTRÉS //';

  @override
  String get bulkBackupImportFailedNote =>
      'Certains contacts n’ont pas pu être enregistrés sur ce téléphone. Restaurez à nouveau la même sauvegarde pour réessayer ; ceux déjà restaurés apparaîtront comme déjà associés.';

  @override
  String get bulkBackupImportNothingChangedBody =>
      'Rien n’a été modifié sur ce téléphone.';

  @override
  String get bulkBackupImportDoneBody =>
      'Chaque association restaurée utilise le même secret partagé que l’ancien téléphone ; l’autre personne ne remarquera rien, sauf si elle renouvelle la clé.';

  @override
  String get bindingPhraseTitle => 'VÉRIFIER L’ASSOCIATION';

  @override
  String get bindingPhraseLoadError => 'Impossible de lire votre association.';

  @override
  String bindingPhraseExplanation(String label) {
    return 'Ces 4 mots viennent du secret que vous partagez avec $label. Ce ne sont peut-être pas les mots que vous aviez comparés lors de l’association ; c’est normal. Demandez à $label d’ouvrir Signet et d’afficher ce même écran. Comparez-les face à face, ou lors d’un appel que vous passez vous-même à un numéro que vous aviez déjà. Si les deux téléphones affichent maintenant les mêmes 4 mots, l’association est intacte.';
  }

  @override
  String get bindingPhraseMismatchHeader => 'S’ILS NE CORRESPONDENT PAS //';

  @override
  String get bindingPhraseMismatchBody =>
      'Dissociez ce contact, puis refaites l’association en personne. D’ici là, ne vérifiez aucun appel avec cette association.';

  @override
  String get bindingPhraseBackHomeButton => 'RETOUR À L’ACCUEIL';

  @override
  String get crGridTitle => 'QUESTION-RÉPONSE';

  @override
  String get crGridPrintTooltip => 'Imprimer la grille';

  @override
  String crGridLoadError(String error) {
    return 'Impossible de charger la grille : $error';
  }

  @override
  String crGridHeading(String label) {
    return 'Grille pour $label';
  }

  @override
  String crGridFallbackExplanation(String label, String row, String col) {
    return 'Quand $label ne peut pas utiliser son téléphone mais peut parler, servez-vous de cette grille en secours. Vous demandez une case (par exemple « $row × $col ») ; l’autre personne lit la réponse sur la copie papier que vous avez tous les deux. Comparez en silence de votre côté.';
  }

  @override
  String get crGridFallbackNotice =>
      'Ceci est une SOLUTION DE SECOURS. Si vous pouvez faire une vérification avec les 4 mots, faites-la d’abord : elle protège mieux. N’utilisez ceci que si l’autre personne n’a pas de téléphone.';

  @override
  String get crGridSectionHeader => 'GRILLE // 8×8 //';

  @override
  String crGridCellDialogTitle(String row, String col) {
    return '$row × $col';
  }

  @override
  String get crGridCloseButton => 'FERMER';

  @override
  String crPdfDocTitle(String label) {
    return 'Signet question-réponse · $label';
  }

  @override
  String get crPdfCardTitle => 'CARTE QUESTION-RÉPONSE SIGNET';

  @override
  String get crPdfWarningTitle =>
      'GARDEZ CETTE CARTE COMME LE CODE D’UN COFFRE-FORT';

  @override
  String get crPdfWarningBody =>
      'Quiconque trouve cette carte peut répondre aux questions pour cette association. La question-réponse est une solution de secours : la vérification avec les 4 mots dans l’application reste le contrôle le plus sûr pour les appels de tous les jours. Si vous perdez cette carte, dissociez ce contact dans l’application et refaites l’association en personne.';

  @override
  String get crPdfRowsHeader => 'LIGNES //';

  @override
  String get crPdfColumnsHeader => 'COLONNES //';

  @override
  String get crPdfFooter => 'Signet - question-réponse v1';

  @override
  String get settingsTitle => 'PARAMÈTRES';

  @override
  String get settingsAppearanceSection => 'APPARENCE';

  @override
  String get settingsAppearanceBody =>
      'Remplace le thème du système. « Système » suit votre appareil ; « Sombre » et « Clair » imposent ce thème à Signet dans tous les cas.';

  @override
  String get settingsThemeSystemLabel => 'SYSTÈME';

  @override
  String get settingsThemeSystemSubtitle => 'Suivre le thème de l’appareil';

  @override
  String get settingsThemeDarkLabel => 'SOMBRE';

  @override
  String get settingsThemeDarkSubtitle => 'Thème par défaut';

  @override
  String get settingsThemeLightLabel => 'CLAIR';

  @override
  String get settingsThemeLightSubtitle => 'Contraste élevé, plein jour';

  @override
  String get settingsBulkBackupSection => 'SAUVEGARDE COMPLÈTE';

  @override
  String get settingsBulkBackupEmptyBody =>
      'Aucun contact associé pour l’instant. Associez-vous d’abord avec quelqu’un ; vous pourrez ensuite sauvegarder toutes vos associations d’un coup.';

  @override
  String settingsBulkBackupBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vos $count contacts',
      one: 'votre contact',
    );
    return 'Sauvegardez $_temp0 en une fois : un paquet et une série de 8 mots. Utile pour changer de téléphone : le nouveau restaure toutes les associations en une seule étape.';
  }

  @override
  String settingsBulkBackupAction(int count) {
    return 'TOUT SAUVEGARDER ($count)';
  }

  @override
  String get settingsDebugSection => 'JOURNAL DE DÉBOGAGE';

  @override
  String settingsDebugActiveBody(String expiry) {
    return 'Enregistrement de l’activité de l’application dans un fichier chiffré sur cet appareil. Il s’efface automatiquement $expiry (ou touchez « ARRÊTER ET EFFACER »). Exportez-le pour envoyer un rapport de problème : les secrets sont retirés et les contacts deviennent des étiquettes comme <peer-1> avant qu’il ne quitte votre téléphone.';
  }

  @override
  String get settingsDebugInactiveBody =>
      'Désactivé : rien n’est enregistré. Si vous rencontrez un problème, activez-le, reproduisez le problème, puis exportez le journal pour nous l’envoyer. Il ne contient jamais vos secrets ni les noms de vos contacts.';

  @override
  String get settingsDebugEnableAction => 'ACTIVER LE JOURNAL DE DÉBOGAGE';

  @override
  String get settingsDebugEnableFailed =>
      'Impossible d’activer le journal de débogage. Rien n’a été enregistré. Réessayez.';

  @override
  String get settingsDebugExportButton => 'EXPORTER LE JOURNAL';

  @override
  String get settingsDebugStopWipeButton => 'ARRÊTER ET EFFACER';

  @override
  String get settingsDebugNoLogSnackbar =>
      'Aucun journal de débogage pour l’instant.';

  @override
  String get settingsDebugExpiryIn24h => 'dans 24 h';

  @override
  String settingsDebugExpiryAt(String time, String date) {
    return 'à $time le $date';
  }

  @override
  String get settingsTourSection => 'VISITE GUIDÉE';

  @override
  String get settingsTourBody =>
      'Revoir la présentation du premier lancement. Utile après une restauration de sauvegarde, ou pour relire les instructions d’association.';

  @override
  String get settingsTourReplayAction => 'REVOIR L’INTRODUCTION';

  @override
  String get settingsAboutSection => 'À PROPOS';

  @override
  String get settingsAboutBody =>
      'Version de l’application, licence, code source, politique de confidentialité et liens de soutien.';

  @override
  String get settingsAboutOpenAction => 'OUVRIR À PROPOS';

  @override
  String get settingsBulkConfirmTitle => 'TOUT SAUVEGARDER ?';

  @override
  String get settingsUnreadableSection => 'CONTACTS ILLISIBLES';

  @override
  String settingsUnreadableBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts associés n’ont pas pu être lus',
      one: '$count contact associé n’a pas pu être lu',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'les a peut-être enregistrés',
      one: 'l’a peut-être enregistré',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'les',
      one: 'le',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ils n’apparaissent pas sur l’accueil et ne sont',
      one: 'Il n’apparaît pas sur l’accueil et n’est',
    );
    return '$_temp0. Une version plus récente de Signet $_temp1 ; mettez Signet à jour pour $_temp2 revoir. $_temp3 pas inclus dans les sauvegardes.';
  }

  @override
  String get settingsUnreadableRemove => 'Supprimer les contacts illisibles';

  @override
  String get settingsUnreadableConfirmTitle => 'LES SUPPRIMER ?';

  @override
  String get settingsUnreadableConfirmBody =>
      'Ces contacts seront dissociés sur ce téléphone, exactement comme depuis l’accueil. Pour vérifier à nouveau avec eux, il faudra refaire l’association.';

  @override
  String get settingsUnreadableConfirmButton => 'Supprimer';

  @override
  String get settingsUnreadableRemoveFailed =>
      'Certains n’ont pas pu être supprimés. Réessayez.';

  @override
  String bulkBackupExportSkipsUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts n’ont pas pu être lus et ne seront pas',
      one: '$count contact n’a pas pu être lu et ne sera pas',
    );
    return '$_temp0 dans cette sauvegarde. Voir les Paramètres.';
  }

  @override
  String settingsBulkConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vos $count contacts',
      one: 'votre contact',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'la sauvegarde des $count contacts',
      one: 'la sauvegarde',
    );
    return 'Cela place le secret partagé de $_temp0 dans une seule sauvegarde. Sans ses 8 mots, la sauvegarde ne peut pas être ouverte : les perdre, c’est perdre $_temp1. Les mots ne s’affichent qu’une fois : notez-les avant de quitter l’écran.';
  }

  @override
  String get settingsBulkConfirmContinue => 'CONTINUER';

  @override
  String get logExportTitle => 'EXPORTER LE JOURNAL';

  @override
  String get logExportScrubNotice =>
      'Les secrets sont retirés et vos contacts apparaissent sous forme d’étiquettes comme <peer-1>. Le journal décrit quand même le fonctionnement de l’application : relisez-le avant de le partager. Si vous ouvrez un ticket GitHub, ne tapez pas le nom d’un contact dans la description : ce champ n’est pas nettoyé.';

  @override
  String get logExportFileIssueButton => 'OUVRIR UN TICKET GITHUB';

  @override
  String get logExportShareButton => 'PARTAGER…';

  @override
  String get logExportCopyButton => 'COPIER LE JOURNAL';

  @override
  String get logExportOpenFailedSnackbar =>
      'Impossible d’ouvrir le navigateur : le journal a été copié à la place.';

  @override
  String get logExportShareSubject => 'Journal de débogage Signet';

  @override
  String get logExportCopiedSnackbar =>
      'Journal de débogage copié dans le presse-papiers.';

  @override
  String get verifyTitle => 'VÉRIFIER';

  @override
  String get verifySectionChallenge => 'QUESTION //';

  @override
  String verifyAskForWordsHeading(String label) {
    return 'Demandez ses 4 mots à $label.';
  }

  @override
  String get verifyTypeInstruction =>
      'Tapez ce que vous entendez. Touchez une suggestion pour remplir une case.';

  @override
  String get verifySectionInput => 'SAISIE //';

  @override
  String get verifyFailHeader => 'SI LA VÉRIFICATION ÉCHOUE //';

  @override
  String get verifyFailHeading => 'Quelque chose ne va pas avec cet appel.';

  @override
  String get verifyFailStep1 =>
      'Raccrochez. N’expliquez pas pourquoi. Ne discutez pas. N’acceptez rien de ce qu’on vous demande.';

  @override
  String verifyFailStep2(String label) {
    return 'Rappelez $label à un numéro que vous avez déjà utilisé : enregistré dans vos contacts, noté sur papier, un numéro que vous connaissez. N’utilisez pas un numéro donné par l’appelant.';
  }

  @override
  String verifyFailStep3(String label) {
    return 'Si $label ne répond pas, appelez un membre de la famille ou un proche qui peut aller voir sur place. Si c’est vraiment $label, cette personne ne vous en voudra jamais d’avoir vérifié.';
  }

  @override
  String verifyFailStep4(String label) {
    return 'Si vous vous demandez si Signet lui-même est en panne : touchez « Vérifier la phrase d’association » ci-dessous et comparez-la avec $label par un moyen de confiance. Si les phrases correspondent, Signet fonctionne correctement et le bandeau rouge signifie que l’appel était truqué.';
  }

  @override
  String get verifyFailCheckBindingButton => 'Vérifier la phrase d’association';

  @override
  String get verifyStatusOk => 'RÉSULTAT //';

  @override
  String get verifyStatusFail => 'RÉSULTAT //';

  @override
  String get verifyBannerVerified => 'VÉRIFIÉ';

  @override
  String get verifyBannerNotVerified => 'NON VÉRIFIÉ : MÉFIEZ-VOUS';

  @override
  String get verifySublineVerifiedWithAction =>
      'Les mots correspondent ET vous avez vu le geste attendu. Vous pouvez faire confiance à cet appel.';

  @override
  String get verifySublineVerified =>
      'Les mots correspondent. Vous pouvez faire confiance à cet appel.';

  @override
  String get verifySublineWordsMismatch =>
      'Les mots ne correspondent pas. Quelqu’un se fait peut-être passer pour cette personne.';

  @override
  String get verifySublineActionMismatch =>
      'Les mots correspondent, mais pas le geste. Méfiez-vous : considérez que la vérification a échoué.';

  @override
  String get verifyWhatShouldIDoButton => 'QUE DOIS-JE FAIRE ?';

  @override
  String get verifyVideoModeSemanticsLabel => 'Mode appel vidéo';

  @override
  String get verifyVideoModeSemanticsHint =>
      'Activez pour vérifier aussi un geste en vidéo.';

  @override
  String get verifyVideoModeHeader => 'APPEL VIDÉO //';

  @override
  String get verifyVideoModeOnText =>
      'Un geste est vérifié en plus, sans le dire à voix haute. Déjoue les deepfakes.';

  @override
  String get verifyVideoModeOffText => 'Activez pour vérifier aussi un geste.';

  @override
  String get verifyWatchForHeader => 'À OBSERVER //';

  @override
  String verifyExpectedActionText(String label, String action) {
    return '$label doit faire ce geste : « $action ».';
  }

  @override
  String verifyExpectedActionSemantics(String label, String action) {
    return 'À observer. $label doit faire ce geste : « $action ».';
  }

  @override
  String get verifyActionHeader => 'GESTE //';

  @override
  String verifyActionJudgmentPrompt(String label, String action) {
    return 'Mots ✅. Avez-vous vu $label faire ce geste : « $action » ?';
  }

  @override
  String verifyActionJudgmentAnnouncement(String label) {
    return 'Les mots correspondent. Avez-vous vu $label faire le geste affiché à l’écran ? Répondez JE L’AI VU ou PAS VU.';
  }

  @override
  String get verifyActionNotSeenButton => 'PAS VU';

  @override
  String get verifyActionSeenButton => 'JE L’AI VU';

  @override
  String verifyActionOneGesture(String label) {
    return '$label doit faire un seul geste. S’il y en a eu plusieurs, touchez PAS VU.';
  }

  @override
  String verifyActionChangedNote(String label) {
    return 'Le geste à observer a changé : les mots lus par $label étaient ceux des 30 secondes précédentes ou suivantes, et voici le geste qui va avec.';
  }

  @override
  String get verifyCheckWordsButton => 'VÉRIFIER LES MOTS';

  @override
  String verifyOldPairingNote(String label) {
    return 'Ces mots correspondent à l’association que vous aviez avec $label avant un renouvellement de clé. Si vous venez de renouveler la clé avec $label, refaites-le ensemble, en personne. Sinon, considérez cet appel comme une arnaque.';
  }

  @override
  String get verifyShowMyWords => 'Afficher mes 4 mots';

  @override
  String verifyShowMyWordsSubtitle(String label) {
    return 'Si $label veut vous vérifier, lisez-lui ces mots.';
  }

  @override
  String get verifyFlagSecureBadge => 'CAPTURES D’ÉCRAN BLOQUÉES';

  @override
  String verifyOwnActionWhile(String action) {
    return '…en $action.';
  }

  @override
  String get verifyGerundLookUp => 'levant les yeux vers le plafond';

  @override
  String get verifyGerundLookDown => 'baissant les yeux vers le sol';

  @override
  String get verifyGerundLookLeft => 'regardant par-dessus votre épaule gauche';

  @override
  String get verifyGerundLookRight =>
      'regardant par-dessus votre épaule droite';

  @override
  String get verifyGerundTouchNose => 'touchant le bout de votre nez';

  @override
  String get verifyGerundTouchForehead => 'touchant votre front';

  @override
  String get verifyGerundTouchLeftEar => 'touchant votre oreille gauche';

  @override
  String get verifyGerundTouchRightEar => 'touchant votre oreille droite';

  @override
  String get verifyActionLookUp => 'Levez les yeux vers le plafond';

  @override
  String get verifyActionLookDown => 'Baissez les yeux vers le sol';

  @override
  String get verifyActionLookLeft => 'Regardez par-dessus votre épaule gauche';

  @override
  String get verifyActionLookRight => 'Regardez par-dessus votre épaule droite';

  @override
  String get verifyActionTouchNose => 'Touchez le bout de votre nez';

  @override
  String get verifyActionTouchForehead => 'Touchez votre front';

  @override
  String get verifyActionTouchLeftEar => 'Touchez votre oreille gauche';

  @override
  String get verifyActionTouchRightEar => 'Touchez votre oreille droite';

  @override
  String get verifyLoadError => 'Impossible de lire votre contact associé.';

  @override
  String get verifyBackHomeButton => 'Retour à l’accueil';

  @override
  String get wordInputClearAllButton => 'Tout effacer';

  @override
  String get wordInputChecking => 'Vérification…';

  @override
  String wordInputSlotSemantics(int index, int total) {
    return 'Mot $index sur $total';
  }

  @override
  String get wordInputHint => 'mot';

  @override
  String get wordInputInvalidWordError => 'Mot non valide';

  @override
  String get wordInputClearTooltip => 'Effacer';

  @override
  String wordsDisplaySemantics(String words, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds secondes',
      one: '$seconds seconde',
    );
    return 'Mots de vérification : $words, encore $_temp0';
  }

  @override
  String wordsDisplayCountdown(int seconds) {
    return '$seconds s';
  }

  @override
  String pakeUnknownWordError(int slot) {
    return 'Le mot $slot ne fait pas partie des mots utilisés par Signet. Vérifiez son orthographe.';
  }

  @override
  String get pakeMixedLanguagesError =>
      'Les 8 mots doivent être dans la même langue. Vérifiez que vous les avez tous recopiés depuis le même papier ou le même fichier.';

  @override
  String pakeOtherLanguageWordError(int slot) {
    return 'Le mot $slot n’est pas dans la même langue que les sept autres. Vérifiez que vous l’avez recopié depuis le même papier ou le même fichier que les autres.';
  }

  @override
  String get verifyWatchForChangedAnnouncement =>
      'Nouveau geste à observer. Touchez la ligne À OBSERVER pour l’entendre.';

  @override
  String wordLanguageUnknownMessage(String label) {
    return 'Les mots de $label utilisent une langue que cette version de Signet ne connaît pas. Mettez Signet à jour pour les voir.';
  }

  @override
  String wordLanguageUnknownWarning(String label) {
    return 'Tant que ce problème n’est pas résolu, vous ne pouvez pas vérifier $label. Ne donnez suite à aucune demande urgente : raccrochez et rappelez $label à un numéro que vous connaissez déjà.';
  }

  @override
  String wordLanguageDamagedMessage(String label) {
    return 'La langue des mots enregistrée pour $label vient d’une sauvegarde abîmée : ses mots ne peuvent donc pas s’afficher. Sur l’accueil, appuyez longuement sur $label, choisissez « Langue des mots » et sélectionnez la langue que vous utilisez tous les deux.';
  }

  @override
  String get wordLanguageTitle => 'Langue des mots';

  @override
  String get wordLanguagePickerBody =>
      'Signet affiche de courts mots que vous vous lisez l’un à l’autre pour prouver qui vous êtes. Choisissez leur langue. Pour chaque personne avec qui vous vous associez, vous devez choisir tous les deux la même langue. Vous pourrez en choisir une autre pour un contact au moment de l’association.';

  @override
  String get settingsWordLanguageSection => 'LANGUE DES MOTS';

  @override
  String get settingsWordLanguageBody =>
      'La langue des mots pour les nouveaux contacts. Les contacts existants gardent la leur.';

  @override
  String wordLanguageSampleSemantics(String language, String sample) {
    return '$language. Exemples de mots : $sample';
  }

  @override
  String homeWordLanguageNotice(String language) {
    return 'Signet peut désormais afficher vos mots en $language. Pour utiliser cette langue avec vos nouveaux contacts, choisissez-la dans les Paramètres. Un contact existant reste en anglais tant que vous n’avez pas changé sa langue tous les deux : appuyez longuement sur ce contact sur l’accueil.';
  }

  @override
  String get homeWordLanguageNoticeSettings => 'PARAMÈTRES';

  @override
  String wordLanguageRowLabel(String language) {
    return 'Mots : $language';
  }

  @override
  String get wordLanguageRowChange => 'CHANGER';

  @override
  String get wordLanguageRowPairingHint =>
      'Les mots que vous vous lirez. Choisissez la même langue sur les deux téléphones.';

  @override
  String get wordLanguageRowConfirmHint =>
      'Les deux écrans doivent afficher la même langue avant que vous compariez les mots.';

  @override
  String wordLanguageTheyChose(String language) {
    return 'L’autre téléphone a choisi $language. Touchez CHANGER et choisissez $language pour que vos mots correspondent.';
  }

  @override
  String get homeRowMenuWordLanguage => 'Langue des mots';

  @override
  String wordLanguageDialogBody(String label) {
    return '$label doit choisir la même langue sur son téléphone. Tant que les deux téléphones n’ont pas la même langue, la vérification indique NON VÉRIFIÉ. Changez-la ensemble avec $label, jamais parce qu’un appelant vous le demande.';
  }

  @override
  String wordLanguageChangedOn(String date) {
    return 'Dernière modification le $date.';
  }

  @override
  String wordLanguageChangedSnackbar(String label, String language) {
    return 'Les mots de $label sont désormais en $language. Changez aussi la langue sur le téléphone de $label.';
  }

  @override
  String bulkImportOverwriteChangesLanguage(String language) {
    return 'Change aussi la langue des mots en $language.';
  }

  @override
  String get wordLanguageRowChangeSemantics => 'Changer la langue des mots';

  @override
  String get homeRowMenuWordLanguageUnknown =>
      'Inconnue : mettez Signet à jour';

  @override
  String get backupWordsAnyLanguage =>
      'Signet peut lire ces mots, quelle que soit la langue choisie dans l’application.';

  @override
  String get wordLanguageTheyChoseUnknown =>
      'L’autre téléphone a choisi pour les mots une langue que cette version de Signet ne connaît pas. Mettez Signet à jour, ou choisissez tous les deux une langue que vos deux téléphones proposent.';

  @override
  String verifyOtherLanguageNote(String other, String label, String current) {
    return 'Ces mots ne correspondent à l’association avec $label que s’ils sont lus en $other, mais sur ce téléphone, les mots de $label sont en $current. Le résultat reste NON VÉRIFIÉ. Après cet appel, choisissez la même langue des mots sur les deux téléphones (appuyez longuement sur $label sur l’accueil), puis vérifiez à nouveau.';
  }

  @override
  String get pairConfirmMismatchLanguageHint =>
      'Vérifiez d’abord que les deux écrans affichent la même langue des mots au-dessus de la phrase. Sinon, touchez Annuler, choisissez la même langue sur les deux téléphones et comparez à nouveau.';

  @override
  String wordInputOtherLanguageHelper(String other, String own) {
    return 'Un mot en $other. Les mots de ce contact sont en $own.';
  }

  @override
  String get faqQ14 => 'Les mots de mon contact sont dans une autre langue.';

  @override
  String get faqA14 =>
      'Chaque contact a sa langue des mots, et vous devez tous les deux choisir la même. Si cette personne vous lit les bons mots dans une autre langue, la vérification indique quand même NON VÉRIFIÉ et ajoute une note pour le signaler.\n\nPour corriger, changez-la ensemble : sur les deux téléphones, appuyez longuement sur le contact sur l’accueil, choisissez « Langue des mots » et sélectionnez la même langue. Faites-le seulement avec la vraie personne, jamais parce qu’un appelant vous le demande. Chaque changement est daté, et sa date s’affiche dans la fenêtre « Langue des mots ».\n\nLa langue choisie au premier lancement n’est que la langue par défaut des nouveaux contacts ; changez-la dans les Paramètres. Une sauvegarde garde la langue de chaque contact.';

  @override
  String get faqQ15 => 'Pourquoi les mots chinois sont-ils marqués bêta ?';

  @override
  String get faqA15 =>
      'Les mots chinois de Signet ont été choisis à l’aide de dictionnaires, de données de fréquence, de tests d’écoute réalisés par ordinateur et de relectures par des modèles d’IA, pour qu’aucun mot ne sonne comme un autre pour une personne qui parle mandarin. Aucune personne de langue maternelle chinoise n’a encore vérifié la liste, ni l’interface chinoise, traduite de la même façon.\n\nCes mots sont exactement aussi sûrs que les mots anglais ou français. Si un mot est difficile à dire, difficile à entendre ou facile à confondre avec un autre, dites-le-nous avec le bouton NOUS CONTACTER ci-dessous. La liste elle-même ne change jamais, donc vos associations continuent de fonctionner, mais une future liste pourra corriger le problème.';

  @override
  String get aboutLicensesButton => 'LICENCES OPEN SOURCE';

  @override
  String get settingsChineseScriptSection => 'CARACTÈRES CHINOIS';

  @override
  String get settingsChineseScriptBody =>
      'La façon dont les mots chinois s’écrivent sur ce téléphone. Les deux écritures donnent les mêmes mots : un contact peut donc utiliser l’autre.';
}
