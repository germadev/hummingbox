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
  String get folderFailed => 'Impossible d\'utiliser ce dossier';

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
  String get keepScreenOn => 'Garder l\'écran allumé';

  @override
  String get keepScreenOnSubtitle =>
      'Pendant l\'enregistrement ou l\'attente avant de commencer, pour que le système n\'arrête pas l\'app';

  @override
  String get recordingSection => 'Enregistrement';

  @override
  String get formatNote =>
      'S\'applique aux nouveaux enregistrements. Lors de la modification, chaque enregistrement conserve son format.';

  @override
  String get storageSection => 'Emplacement des enregistrements';

  @override
  String get deviceFolder => 'Dossier de l\'appareil';

  @override
  String get noFolder => 'Aucun';

  @override
  String get chooseAnotherFolder => 'Choisir un autre dossier';

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
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossible d\'ajouter $count enregistrements',
      one: 'Impossible d\'ajouter 1 enregistrement',
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

  @override
  String newRecordingsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux enregistrements',
      one: '1 nouvel enregistrement',
    );
    return '$_temp0';
  }

  @override
  String get playFailed => 'Impossible de lire l\'enregistrement';

  @override
  String deleteFromFolderMessage(String folder) {
    return 'Il sera aussi supprimé de « $folder ». Cette action est irréversible.';
  }

  @override
  String get deleteFromDriveMessage =>
      'Il sera placé dans la corbeille de votre Google Drive.';

  @override
  String get syncing => 'Synchronisation…';

  @override
  String get syncFailed => 'Impossible de tout synchroniser';

  @override
  String get setupTitle => 'Où voulez-vous conserver vos enregistrements ?';

  @override
  String get setupMessage =>
      'Vous pourrez le modifier plus tard dans les réglages.';

  @override
  String get setupFolder => 'Dans un dossier de l\'appareil';

  @override
  String get setupFolderDescription =>
      'Stockage interne, carte SD, iCloud Drive… Les enregistrements qui s\'y trouvent déjà apparaîtront dans l\'app.';

  @override
  String get setupDrive => 'Sur Google Drive';

  @override
  String get setupDriveDescription =>
      'Dans un dossier de votre Drive. Ceux qui ne peuvent pas encore être envoyés sont conservés dans l\'app.';

  @override
  String get storageFolderDescription =>
      'Les enregistrements sont conservés dans le dossier choisi, avec le nom que vous leur donnez et dans leur sous-dossier, et l\'app affiche tous les fichiers audio (.m4a et .wav) qu\'il contient. Ce que vous supprimez, renommez ou modifiez dans l\'app change aussi dans le dossier.';

  @override
  String storageDriveDescription(String folder) {
    return 'Les enregistrements sont conservés dans le dossier « $folder » de votre Google Drive et téléchargés pour les écouter ou les modifier. Ceux qui n\'ont pas encore pu être envoyés (par exemple, hors connexion) sont conservés dans l\'app. Si vous choisissez un dossier de l\'appareil, ils y seront conservés et Drive en gardera une copie.';
  }

  @override
  String get stopUsingFolder => 'Ne plus utiliser le dossier';

  @override
  String stopUsingFolderTitle(String folder) {
    return 'Ne plus utiliser « $folder » ?';
  }

  @override
  String get stopUsingFolderMessage =>
      'Les enregistrements resteront dans le dossier, mais n\'apparaîtront plus dans l\'app. Vous devrez ensuite choisir où conserver les nouveaux.';

  @override
  String get stopUsingFolderDriveMessage =>
      'Les enregistrements resteront dans le dossier et l\'app utilisera ceux de votre Google Drive, où les nouveaux seront conservés.';

  @override
  String get stopUsing => 'Ne plus l\'utiliser';

  @override
  String get disconnectDriveStorageMessage =>
      'Les enregistrements resteront dans votre Drive, mais n\'apparaîtront plus dans l\'app. Vous devrez ensuite choisir où conserver les nouveaux.';

  @override
  String folderInUse(String folder) {
    return 'Les enregistrements sont désormais conservés dans « $folder »';
  }

  @override
  String saveFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossible de conserver $count enregistrements',
      one: 'Impossible de conserver 1 enregistrement',
    );
    return '$_temp0';
  }

  @override
  String get readDriveFailed => 'Impossible de lire Google Drive';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get syncNowSubtitle =>
      'Conserve ce qui est en attente et recherche les changements là où sont les enregistrements';

  @override
  String get transcribe => 'Transcrire';

  @override
  String get viewTranscript => 'Voir la transcription';

  @override
  String transcribingProgress(String percent) {
    return 'Transcription… $percent';
  }

  @override
  String get preparingTranscription => 'Préparation de la transcription…';

  @override
  String get waitingToTranscribe => 'En attente de transcription…';

  @override
  String get cancelTranscription => 'Annuler la transcription';

  @override
  String get transcriptReady => 'Transcription prête';

  @override
  String get view => 'Voir';

  @override
  String get transcriptionFailed =>
      'Impossible de transcrire l\'enregistrement';

  @override
  String get noSpeechRecognized => 'Aucun mot n\'a été reconnu';

  @override
  String get stopToTranscribe => 'Arrêtez l\'enregistrement pour transcrire';

  @override
  String get systemSpeechUnavailableTitle =>
      'La reconnaissance vocale n\'est pas disponible';

  @override
  String get systemSpeechUnavailableMessage =>
      'Cet appareil ne peut pas transcrire avec la reconnaissance vocale du système (sur Android, la version 13 ou ultérieure est requise). Vous pouvez installer Whisper dans les réglages.';

  @override
  String unsupportedLanguageMessage(String language) {
    return 'La reconnaissance vocale du système ne prend pas en charge « $language » sur cet appareil. Vous pouvez installer Whisper ou choisir une autre langue dans les réglages.';
  }

  @override
  String get openSettings => 'Ouvrir les réglages';

  @override
  String downloadLanguageTitle(String language) {
    return 'Télécharger « $language » ?';
  }

  @override
  String get downloadLanguageMessage =>
      'La reconnaissance vocale du système doit télécharger cette langue pour transcrire sur l\'appareil. Réessayez une fois le téléchargement terminé.';

  @override
  String get download => 'Télécharger';

  @override
  String get languageDownloading =>
      'La langue est en cours de téléchargement. Réessayez une fois terminé.';

  @override
  String get speechPermission =>
      'Autorisez la reconnaissance vocale dans les réglages pour transcrire';

  @override
  String get whisperNotInstalledTitle => 'Whisper n\'est pas installé';

  @override
  String get whisperNotInstalledMessage =>
      'Pour transcrire avec Whisper, téléchargez un modèle dans les réglages.';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié dans le presse-papiers';

  @override
  String get transcribeAgain => 'Transcrire à nouveau';

  @override
  String get deleteTranscript => 'Supprimer la transcription';

  @override
  String get transcriptDeleted => 'Transcription supprimée';

  @override
  String get transcriptOutdated =>
      'L\'enregistrement a changé depuis sa transcription.';

  @override
  String get transcriptionSection => 'Transcription';

  @override
  String get transcriptionEngine => 'Transcrire avec';

  @override
  String get systemSpeechRecognition => 'Reconnaissance vocale du système';

  @override
  String get systemSpeechDescription =>
      'Aucun téléchargement. Sur Android, version 13 ou ultérieure requise';

  @override
  String get whisperDescription =>
      'Sur l\'appareil, hors connexion. Nécessite de télécharger un modèle';

  @override
  String get whisperModel => 'Modèle Whisper';

  @override
  String get whisperNotInstalled =>
      'Non installé. Touchez pour en télécharger un';

  @override
  String whisperInstalled(String model, String size) {
    return 'Installé : $model ($size)';
  }

  @override
  String whisperDownloading(String model, String percent, String size) {
    return 'Téléchargement de $model… $percent sur $size';
  }

  @override
  String get whisperDownloadFailed => 'Impossible de télécharger le modèle';

  @override
  String get chooseWhisperModel => 'Télécharger un modèle';

  @override
  String whisperTinyDescription(String size) {
    return '$size · Plus rapide, moins précis';
  }

  @override
  String whisperBaseDescription(String size) {
    return '$size · Plus précis, plus lent';
  }

  @override
  String get deleteWhisperModel => 'Supprimer le modèle';

  @override
  String get deleteWhisperModelTitle => 'Supprimer le modèle Whisper ?';

  @override
  String deleteWhisperModelMessage(String size) {
    return 'Cela libère $size. Vous pourrez le télécharger à nouveau.';
  }

  @override
  String get cancelDownload => 'Annuler le téléchargement';

  @override
  String get transcriptionLanguage => 'Langue';

  @override
  String appLanguageOption(String language) {
    return 'Celle de l\'app ($language)';
  }

  @override
  String get detectLanguageOption =>
      'Détecter automatiquement (Whisper uniquement)';
}
