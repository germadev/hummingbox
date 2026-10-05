// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Enregistreur';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get discard => 'Abandonner';

  @override
  String get create => 'Créer';

  @override
  String get nameLabel => 'Nom';

  @override
  String get defaultRecordingName => 'Enregistrement';

  @override
  String editedCopyName(String name) {
    return '$name (modifié)';
  }

  @override
  String get loadRecordingsFailed =>
      'Impossible de charger les enregistrements';

  @override
  String importedFromFolder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrements ajoutés depuis le dossier',
      one: '1 enregistrement ajouté depuis le dossier',
    );
    return '$_temp0';
  }

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get invalidFolderName => 'Ce nom n\'est pas valide pour un dossier';

  @override
  String get microphonePermission =>
      'Autorisez l\'accès au micro dans les réglages pour enregistrer';

  @override
  String get startRecordingFailed => 'Impossible de démarrer l\'enregistrement';

  @override
  String get saveRecordingFailed =>
      'Impossible de sauvegarder l\'enregistrement';

  @override
  String savedAs(String name) {
    return 'Enregistré sous « $name »';
  }

  @override
  String get discardRecordingTitle => 'Abandonner l\'enregistrement ?';

  @override
  String get discardRecordingMessage =>
      'L\'audio enregistré jusqu\'ici sera perdu.';

  @override
  String get stopToPlay => 'Arrêtez l\'enregistrement pour lire';

  @override
  String get stopToEdit => 'Arrêtez l\'enregistrement pour modifier';

  @override
  String get stopToLeave => 'Arrêtez l\'enregistrement avant de quitter';

  @override
  String get changesSaved => 'Modifications enregistrées';

  @override
  String get renameFailed => 'Impossible de renommer l\'enregistrement';

  @override
  String get shareFailed => 'Impossible de partager l\'enregistrement';

  @override
  String deleteTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteMessage => 'Cette action est irréversible.';

  @override
  String get recordingDeleted => 'Enregistrement supprimé';

  @override
  String get deleteFailed => 'Impossible de supprimer l\'enregistrement';

  @override
  String get settings => 'Réglages';

  @override
  String get rootFolder => 'Enregistrements';

  @override
  String get savingCopies => 'Enregistrement des copies…';

  @override
  String get copiesFailed => 'Certaines copies n\'ont pas pu être enregistrées';

  @override
  String get emptyFolderTitle => 'Ce dossier est vide';

  @override
  String get emptyFolderHint =>
      'Appuyez sur le bouton rouge pour y enregistrer.';

  @override
  String get noRecordingsTitle => 'Aucun enregistrement pour l\'instant';

  @override
  String get noRecordingsHint =>
      'Appuyez sur le bouton rouge pour commencer à enregistrer.';

  @override
  String get folders => 'Dossiers';

  @override
  String get play => 'Lire';

  @override
  String get pause => 'Pause';

  @override
  String get rename => 'Renommer';

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String get edit => 'Modifier';

  @override
  String get share => 'Partager';

  @override
  String dateToday(String time) {
    return 'Aujourd\'hui, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'Hier, $time';
  }

  @override
  String dateOther(String date, String time) {
    return '$date, $time';
  }

  @override
  String get stereo => 'stéréo';

  @override
  String channels(int count) {
    return '$count canaux';
  }

  @override
  String bitDepth(int bits) {
    return '$bits bits';
  }

  @override
  String perMinute(String size) {
    return '$size par minute';
  }

  @override
  String get renameRecording => 'Renommer l\'enregistrement';

  @override
  String get hideRecordPanel => 'Masquer le panneau d\'enregistrement';

  @override
  String get showRecordPanel => 'Afficher le panneau d\'enregistrement';

  @override
  String get countdownStatus => 'L\'enregistrement commence dans…';

  @override
  String get waitingForVoice => 'En attente de votre voix…';

  @override
  String get readyToRecord => 'Prêt à enregistrer';

  @override
  String get recordingStatus => 'Enregistrement';

  @override
  String get pausedStatus => 'En pause';

  @override
  String countdownButton(int seconds) {
    return 'Enregistrer après un compte à rebours de $seconds s';
  }

  @override
  String get resume => 'Reprendre';

  @override
  String get voiceButton => 'Enregistrer dès que vous parlez';

  @override
  String get stopAndSave => 'Arrêter et enregistrer';

  @override
  String get startNow => 'Commencer maintenant';

  @override
  String get record => 'Enregistrer';

  @override
  String get previewFailed => 'Impossible de préparer l\'écoute';

  @override
  String get editSaveFailed => 'Impossible d\'enregistrer la modification';

  @override
  String get discardChangesTitle => 'Abandonner les modifications ?';

  @override
  String get discardChangesMessage =>
      'Les modifications non enregistrées seront perdues.';

  @override
  String get editRecording => 'Modifier l\'enregistrement';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get saving => 'Enregistrement…';

  @override
  String get saveCopy => 'Enregistrer une copie';

  @override
  String get openAudioFailed =>
      'Impossible d\'ouvrir l\'audio pour le modifier.';

  @override
  String get preparingAudio => 'Préparation de l\'audio…';

  @override
  String get trimStartLabel => 'Début';

  @override
  String get durationLabel => 'Durée';

  @override
  String get trimEndLabel => 'Fin';

  @override
  String get playSelection => 'Écouter la sélection';

  @override
  String get volume => 'Volume';

  @override
  String get normalize => 'Normaliser';

  @override
  String get clippingWarning => 'Les passages les plus forts satureront';

  @override
  String get fadeIn => 'Fondu d\'entrée';

  @override
  String get fadeOut => 'Fondu de sortie';

  @override
  String get trimStartHandle => 'Début du découpage';

  @override
  String get trimEndHandle => 'Fin du découpage';

  @override
  String get playbackPosition => 'Position de lecture';

  @override
  String get importTitle => 'Ajouter les enregistrements du dossier ?';

  @override
  String importMessage(String folder, int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers audio',
      one: '1 fichier audio',
    );
    return '« $folder » contient $_temp0 ($size) qui ne sont pas dans l\'app. Si vous les ajoutez, ils apparaîtront dans la liste et seront copiés dans l\'app.';
  }

  @override
  String get add => 'Ajouter';

  @override
  String get dontAdd => 'Ne pas ajouter';

  @override
  String get folderFailed => 'Impossible d\'utiliser ce dossier';

  @override
  String get copiesKept =>
      'Les copies déjà présentes dans le dossier sont conservées';

  @override
  String get driveConnectFailed => 'Impossible de se connecter à Google Drive';

  @override
  String get disconnectDriveTitle => 'Déconnecter Google Drive ?';

  @override
  String get disconnectDriveMessage =>
      'Les copies ne seront plus enregistrées sur Drive. Celles qui s\'y trouvent déjà sont conservées.';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get format => 'Format';

  @override
  String get aacDescription =>
      'Compressé : prend peu de place et se lit sur tous les appareils';

  @override
  String get wavDescription =>
      'Non compressé : fidélité maximale, mais prend beaucoup plus de place';

  @override
  String get quality => 'Qualité';

  @override
  String get qualityLow => 'Basse';

  @override
  String get qualityMedium => 'Moyenne';

  @override
  String get qualityHigh => 'Haute';

  @override
  String get countdown => 'Compte à rebours';

  @override
  String secondsCount(int seconds) {
    return '$seconds secondes';
  }

  @override
  String countdownSubtitle(int seconds) {
    return '$seconds secondes avant d\'enregistrer avec le bouton de compte à rebours';
  }

  @override
  String get recordingSection => 'Enregistrement';

  @override
  String get formatNote =>
      'S\'applique aux nouveaux enregistrements. Lors de la modification, chaque enregistrement conserve son format.';

  @override
  String get storageSection => 'Emplacement des enregistrements';

  @override
  String get storageDescription =>
      'Les enregistrements sont toujours conservés dans l\'app. Vous pouvez aussi garder une copie de chacun dans un dossier de l\'appareil et sur Google Drive, avec le nom que vous lui avez donné et dans son sous-dossier. Les copies sont mises à jour quand vous renommez ou modifiez un enregistrement, mais ne sont pas supprimées quand vous le supprimez.';

  @override
  String get deviceFolder => 'Dossier de l\'appareil';

  @override
  String get noFolder => 'Aucun dossier';

  @override
  String get stopSavingToFolder => 'Ne plus enregistrer dans le dossier';

  @override
  String get chooseAnotherFolder => 'Choisir un autre dossier';

  @override
  String get showFolderRecordings => 'Afficher les enregistrements du dossier';

  @override
  String get showFolderRecordingsSubtitle =>
      'Ajoute à l\'app les fichiers audio (.m4a et .wav) du dossier et de ses sous-dossiers';

  @override
  String driveAccount(String email, String folder) {
    return '$email · dossier « $folder »';
  }

  @override
  String get driveSaveCopy => 'Enregistrer une copie sur votre Google Drive';

  @override
  String get driveUnavailable =>
      'Indisponible : cette version de l\'app n\'est pas configurée pour accéder à Google';

  @override
  String get copyNow => 'Copier maintenant';

  @override
  String get copyNowSubtitle => 'Seul ce qui manque ou a changé est copié';

  @override
  String copyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossible de copier $count enregistrements',
      one: 'Impossible de copier 1 enregistrement',
    );
    return '$_temp0';
  }

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossible d\'ajouter $count enregistrements du dossier',
      one: 'Impossible d\'ajouter 1 enregistrement du dossier',
    );
    return '$_temp0';
  }

  @override
  String get readFolderFailed => 'Impossible de lire le dossier';

  @override
  String get readRecordingsFailed => 'Impossible de lire les enregistrements';

  @override
  String get driveReconnect => 'Reconnectez votre compte Google Drive';

  @override
  String get offline => 'Pas de connexion';

  @override
  String get noFolderPermission =>
      'L\'autorisation sur le dossier a été perdue. Choisissez-le à nouveau.';

  @override
  String errorWithDetail(String message, String detail) {
    return '$message : $detail';
  }
}
