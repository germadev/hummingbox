// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Rekorder';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get create => 'Erstellen';

  @override
  String get nameLabel => 'Name';

  @override
  String get defaultRecordingName => 'Aufnahme';

  @override
  String editedCopyName(String name) {
    return '$name (bearbeitet)';
  }

  @override
  String get loadRecordingsFailed =>
      'Die Aufnahmen konnten nicht geladen werden';

  @override
  String get newFolder => 'Neuer Ordner';

  @override
  String get invalidFolderName =>
      'Dieser Name ist für einen Ordner nicht zulässig';

  @override
  String get microphonePermission =>
      'Erlaube den Mikrofonzugriff in den Einstellungen, um aufzunehmen';

  @override
  String get startRecordingFailed =>
      'Die Aufnahme konnte nicht gestartet werden';

  @override
  String get saveRecordingFailed =>
      'Die Aufnahme konnte nicht gespeichert werden';

  @override
  String savedAs(String name) {
    return 'Gespeichert als „$name“';
  }

  @override
  String get discardRecordingTitle => 'Aufnahme verwerfen?';

  @override
  String get discardRecordingMessage =>
      'Der bisher aufgenommene Ton geht verloren.';

  @override
  String get stopToPlay => 'Beende die Aufnahme, um abzuspielen';

  @override
  String get stopToEdit => 'Beende die Aufnahme, um zu bearbeiten';

  @override
  String get stopToLeave => 'Beende die Aufnahme, bevor du die App verlässt';

  @override
  String get changesSaved => 'Änderungen gespeichert';

  @override
  String get renameFailed => 'Die Aufnahme konnte nicht umbenannt werden';

  @override
  String get shareFailed => 'Die Aufnahme konnte nicht geteilt werden';

  @override
  String deleteTitle(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get deleteMessage => 'Dies kann nicht rückgängig gemacht werden.';

  @override
  String get recordingDeleted => 'Aufnahme gelöscht';

  @override
  String get deleteFailed => 'Die Aufnahme konnte nicht gelöscht werden';

  @override
  String get settings => 'Einstellungen';

  @override
  String get rootFolder => 'Aufnahmen';

  @override
  String get emptyFolderTitle => 'Dieser Ordner ist leer';

  @override
  String get emptyFolderHint =>
      'Tippe auf den roten Knopf, um hier aufzunehmen.';

  @override
  String get noRecordingsTitle => 'Noch keine Aufnahmen';

  @override
  String get noRecordingsHint =>
      'Tippe auf den roten Knopf, um die Aufnahme zu starten.';

  @override
  String get folders => 'Ordner';

  @override
  String get play => 'Abspielen';

  @override
  String get pause => 'Pausieren';

  @override
  String get rename => 'Umbenennen';

  @override
  String get moreOptions => 'Weitere Optionen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get share => 'Teilen';

  @override
  String dateToday(String time) {
    return 'Heute, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'Gestern, $time';
  }

  @override
  String dateOther(String date, String time) {
    return '$date, $time';
  }

  @override
  String get stereo => 'Stereo';

  @override
  String channels(int count) {
    return '$count Kanäle';
  }

  @override
  String bitDepth(int bits) {
    return '$bits Bit';
  }

  @override
  String perMinute(String size) {
    return '$size pro Minute';
  }

  @override
  String get renameRecording => 'Aufnahme umbenennen';

  @override
  String get hideRecordPanel => 'Aufnahmebereich ausblenden';

  @override
  String get showRecordPanel => 'Aufnahmebereich einblenden';

  @override
  String get countdownStatus => 'Aufnahme beginnt in …';

  @override
  String get waitingForVoice => 'Warte, bis du sprichst …';

  @override
  String get readyToRecord => 'Bereit zur Aufnahme';

  @override
  String get recordingStatus => 'Aufnahme läuft';

  @override
  String get pausedStatus => 'Pausiert';

  @override
  String countdownButton(int seconds) {
    return 'Nach einem Countdown von $seconds s aufnehmen';
  }

  @override
  String get resume => 'Fortsetzen';

  @override
  String get voiceButton => 'Aufnehmen, sobald du sprichst';

  @override
  String get stopAndSave => 'Beenden und speichern';

  @override
  String get startNow => 'Jetzt starten';

  @override
  String get record => 'Aufnehmen';

  @override
  String get previewFailed => 'Die Vorschau konnte nicht vorbereitet werden';

  @override
  String get editSaveFailed =>
      'Die Bearbeitung konnte nicht gespeichert werden';

  @override
  String get discardChangesTitle => 'Änderungen verwerfen?';

  @override
  String get discardChangesMessage =>
      'Nicht gespeicherte Änderungen gehen verloren.';

  @override
  String get editRecording => 'Aufnahme bearbeiten';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get saving => 'Wird gespeichert …';

  @override
  String get saveCopy => 'Kopie speichern';

  @override
  String get openAudioFailed =>
      'Der Ton konnte zum Bearbeiten nicht geöffnet werden.';

  @override
  String get preparingAudio => 'Ton wird vorbereitet …';

  @override
  String get trimStartLabel => 'Anfang';

  @override
  String get durationLabel => 'Dauer';

  @override
  String get trimEndLabel => 'Ende';

  @override
  String get playSelection => 'Auswahl anhören';

  @override
  String get volume => 'Lautstärke';

  @override
  String get normalize => 'Normalisieren';

  @override
  String get clippingWarning => 'Die lautesten Stellen werden übersteuern';

  @override
  String get fadeIn => 'Einblenden';

  @override
  String get fadeOut => 'Ausblenden';

  @override
  String get trimStartHandle => 'Schnittanfang';

  @override
  String get trimEndHandle => 'Schnittende';

  @override
  String get playbackPosition => 'Wiedergabeposition';

  @override
  String get folderFailed => 'Dieser Ordner kann nicht verwendet werden';

  @override
  String get driveConnectFailed => 'Verbindung zu Google Drive fehlgeschlagen';

  @override
  String get disconnectDriveTitle => 'Google Drive trennen?';

  @override
  String get disconnectDriveMessage =>
      'Es werden keine Kopien mehr in Drive gespeichert. Vorhandene bleiben erhalten.';

  @override
  String get disconnect => 'Trennen';

  @override
  String get format => 'Format';

  @override
  String get aacDescription =>
      'Komprimiert: braucht wenig Platz und läuft auf jedem Gerät';

  @override
  String get wavDescription =>
      'Unkomprimiert: höchste Klangtreue, aber viel größere Dateien';

  @override
  String get quality => 'Qualität';

  @override
  String get qualityLow => 'Niedrig';

  @override
  String get qualityMedium => 'Mittel';

  @override
  String get qualityHigh => 'Hoch';

  @override
  String get countdown => 'Countdown';

  @override
  String secondsCount(int seconds) {
    return '$seconds Sekunden';
  }

  @override
  String countdownSubtitle(int seconds) {
    return '$seconds Sekunden vor der Aufnahme mit der Countdown-Taste';
  }

  @override
  String get keepScreenOn => 'Bildschirm eingeschaltet lassen';

  @override
  String get keepScreenOnSubtitle =>
      'Während der Aufnahme oder beim Warten auf den Start, damit das System die App nicht beendet';

  @override
  String get recordingSection => 'Aufnahme';

  @override
  String get formatNote =>
      'Gilt für neue Aufnahmen. Beim Bearbeiten behält jede Aufnahme ihr Format.';

  @override
  String get storageSection => 'Speicherort der Aufnahmen';

  @override
  String get deviceFolder => 'Ordner auf dem Gerät';

  @override
  String get noFolder => 'Keiner';

  @override
  String get chooseAnotherFolder => 'Anderen Ordner wählen';

  @override
  String driveAccount(String email, String folder) {
    return '$email · Ordner „$folder“';
  }

  @override
  String get driveSaveCopy => 'Eine Kopie in deinem Google Drive speichern';

  @override
  String get driveUnavailable =>
      'Nicht verfügbar: Diese App-Version ist nicht für den Zugriff auf Google eingerichtet';

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen konnten nicht hinzugefügt werden',
      one: '1 Aufnahme konnte nicht hinzugefügt werden',
    );
    return '$_temp0';
  }

  @override
  String get readFolderFailed => 'Der Ordner konnte nicht gelesen werden';

  @override
  String get readRecordingsFailed =>
      'Die Aufnahmen konnten nicht gelesen werden';

  @override
  String get driveReconnect => 'Verbinde dein Google-Drive-Konto erneut';

  @override
  String get offline => 'Keine Verbindung';

  @override
  String get noFolderPermission =>
      'Keine Berechtigung mehr für den Ordner. Wähle ihn erneut.';

  @override
  String errorWithDetail(String message, String detail) {
    return '$message: $detail';
  }

  @override
  String newRecordingsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Aufnahmen',
      one: '1 neue Aufnahme',
    );
    return '$_temp0';
  }

  @override
  String get playFailed => 'Die Aufnahme konnte nicht abgespielt werden';

  @override
  String deleteFromFolderMessage(String folder) {
    return 'Sie wird auch aus „$folder“ gelöscht. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get deleteFromDriveMessage =>
      'Sie wird in den Papierkorb deines Google Drive verschoben.';

  @override
  String get syncing => 'Wird synchronisiert…';

  @override
  String get syncFailed => 'Nicht alles konnte synchronisiert werden';

  @override
  String get setupTitle => 'Wo möchtest du deine Aufnahmen speichern?';

  @override
  String get setupMessage =>
      'Du kannst das später in den Einstellungen ändern.';

  @override
  String get setupFolder => 'In einem Ordner auf dem Gerät';

  @override
  String get setupFolderDescription =>
      'Interner Speicher, SD-Karte, iCloud Drive … Aufnahmen, die schon darin sind, erscheinen in der App.';

  @override
  String get setupDrive => 'In Google Drive';

  @override
  String get setupDriveDescription =>
      'In einem Ordner in deinem Drive. Was noch nicht hochgeladen werden kann, bleibt in der App.';

  @override
  String get storageFolderDescription =>
      'Die Aufnahmen werden im gewählten Ordner gespeichert, mit dem Namen, den du ihnen gibst, und in ihrem Unterordner. Die App zeigt alle Audiodateien (.m4a und .wav) darin an. Was du in der App löschst, umbenennst oder bearbeitest, ändert sich auch im Ordner.';

  @override
  String storageDriveDescription(String folder) {
    return 'Die Aufnahmen werden im Ordner „$folder“ deines Google Drive gespeichert und zum Anhören oder Bearbeiten heruntergeladen. Was noch nicht hochgeladen werden konnte (z. B. ohne Verbindung), bleibt in der App. Wenn du einen Ordner auf dem Gerät wählst, werden sie dort gespeichert und Drive behält eine Kopie.';
  }

  @override
  String get stopUsingFolder => 'Ordner nicht mehr verwenden';

  @override
  String stopUsingFolderTitle(String folder) {
    return '„$folder“ nicht mehr verwenden?';
  }

  @override
  String get stopUsingFolderMessage =>
      'Die Aufnahmen bleiben im Ordner, werden aber nicht mehr in der App angezeigt. Danach musst du wählen, wo neue gespeichert werden.';

  @override
  String get stopUsingFolderDriveMessage =>
      'Die Aufnahmen bleiben im Ordner, und die App verwendet dann die aus deinem Google Drive, wo auch neue gespeichert werden.';

  @override
  String get stopUsing => 'Nicht mehr verwenden';

  @override
  String get disconnectDriveStorageMessage =>
      'Die Aufnahmen bleiben in deinem Drive, werden aber nicht mehr in der App angezeigt. Danach musst du wählen, wo neue gespeichert werden.';

  @override
  String folderInUse(String folder) {
    return 'Aufnahmen werden jetzt in „$folder“ gespeichert';
  }

  @override
  String saveFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen konnten nicht gespeichert werden',
      one: '1 Aufnahme konnte nicht gespeichert werden',
    );
    return '$_temp0';
  }

  @override
  String get readDriveFailed => 'Google Drive konnte nicht gelesen werden';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncNowSubtitle =>
      'Speichert Ausstehendes und sucht nach Änderungen dort, wo die Aufnahmen gespeichert sind';

  @override
  String get transcribe => 'Transkribieren';

  @override
  String get viewTranscript => 'Transkript ansehen';

  @override
  String transcribingProgress(String percent) {
    return 'Transkribiere … $percent';
  }

  @override
  String get preparingTranscription => 'Transkription wird vorbereitet …';

  @override
  String get waitingToTranscribe => 'Wartet auf Transkription …';

  @override
  String get cancelTranscription => 'Transkription abbrechen';

  @override
  String get transcriptReady => 'Transkript fertig';

  @override
  String get view => 'Ansehen';

  @override
  String get transcriptionFailed =>
      'Die Aufnahme konnte nicht transkribiert werden';

  @override
  String get noSpeechRecognized => 'Es wurden keine Wörter erkannt';

  @override
  String get stopToTranscribe => 'Beende die Aufnahme, um zu transkribieren';

  @override
  String get systemSpeechUnavailableTitle =>
      'Spracherkennung ist nicht verfügbar';

  @override
  String get systemSpeechUnavailableMessage =>
      'Dieses Gerät kann nicht mit der Spracherkennung des Systems transkribieren (unter Android ist Version 13 oder neuer nötig). Du kannst Whisper in den Einstellungen installieren.';

  @override
  String unsupportedLanguageMessage(String language) {
    return 'Die Spracherkennung des Systems unterstützt „$language“ auf diesem Gerät nicht. Du kannst Whisper installieren oder in den Einstellungen eine andere Sprache wählen.';
  }

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String downloadLanguageTitle(String language) {
    return '„$language“ herunterladen?';
  }

  @override
  String get downloadLanguageMessage =>
      'Die Spracherkennung des Systems muss diese Sprache herunterladen, um auf dem Gerät zu transkribieren. Versuche es erneut, wenn der Download abgeschlossen ist.';

  @override
  String get download => 'Herunterladen';

  @override
  String get languageDownloading =>
      'Die Sprache wird noch heruntergeladen. Versuche es erneut, wenn der Download abgeschlossen ist.';

  @override
  String get speechPermission =>
      'Erlaube die Spracherkennung in den Einstellungen, um zu transkribieren';

  @override
  String get whisperNotInstalledTitle => 'Whisper ist nicht installiert';

  @override
  String get whisperNotInstalledMessage =>
      'Um mit Whisper zu transkribieren, lade in den Einstellungen ein Modell herunter.';

  @override
  String get copy => 'Kopieren';

  @override
  String get copied => 'In die Zwischenablage kopiert';

  @override
  String get transcribeAgain => 'Erneut transkribieren';

  @override
  String get deleteTranscript => 'Transkript löschen';

  @override
  String get transcriptDeleted => 'Transkript gelöscht';

  @override
  String get transcriptOutdated =>
      'Die Aufnahme wurde seit der Transkription geändert.';

  @override
  String get transcriptionSection => 'Transkription';

  @override
  String get transcriptionEngine => 'Transkribieren mit';

  @override
  String get systemSpeechRecognition => 'Spracherkennung des Systems';

  @override
  String get systemSpeechDescription =>
      'Ohne Downloads. Unter Android ab Version 13';

  @override
  String get whisperDescription =>
      'Auf dem Gerät, offline. Ein Modell muss heruntergeladen werden';

  @override
  String get whisperModel => 'Whisper-Modell';

  @override
  String get whisperNotInstalled =>
      'Nicht installiert. Tippe, um eins herunterzuladen';

  @override
  String whisperInstalled(String model, String size) {
    return 'Installiert: $model ($size)';
  }

  @override
  String whisperDownloading(String model, String percent, String size) {
    return '$model wird heruntergeladen … $percent von $size';
  }

  @override
  String get whisperDownloadFailed =>
      'Das Modell konnte nicht heruntergeladen werden';

  @override
  String get chooseWhisperModel => 'Modell herunterladen';

  @override
  String whisperTinyDescription(String size) {
    return '$size · Schneller, weniger genau';
  }

  @override
  String whisperBaseDescription(String size) {
    return '$size · Genauer, langsamer';
  }

  @override
  String get deleteWhisperModel => 'Modell löschen';

  @override
  String get deleteWhisperModelTitle => 'Whisper-Modell löschen?';

  @override
  String deleteWhisperModelMessage(String size) {
    return 'Dadurch werden $size frei. Du kannst es später erneut herunterladen.';
  }

  @override
  String get cancelDownload => 'Download abbrechen';

  @override
  String get transcriptionLanguage => 'Sprache';

  @override
  String appLanguageOption(String language) {
    return 'Die der App ($language)';
  }

  @override
  String get detectLanguageOption => 'Automatisch erkennen (nur Whisper)';

  @override
  String get appearanceSection => 'Darstellung';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'Automatisch (wie das System)';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';
}
