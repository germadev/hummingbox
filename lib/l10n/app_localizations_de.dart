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
  String importedFromFolder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen aus dem Ordner hinzugefügt',
      one: '1 Aufnahme aus dem Ordner hinzugefügt',
    );
    return '$_temp0';
  }

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
  String get savingCopies => 'Kopien werden gespeichert …';

  @override
  String get copiesFailed => 'Einige Kopien konnten nicht gespeichert werden';

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
  String get importTitle => 'Aufnahmen aus dem Ordner hinzufügen?';

  @override
  String importMessage(String folder, int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Audiodateien',
      one: '1 Audiodatei',
    );
    return '„$folder“ enthält $_temp0 ($size), die nicht in der App sind. Wenn du sie hinzufügst, erscheinen sie in der Liste und werden in die App kopiert.';
  }

  @override
  String get add => 'Hinzufügen';

  @override
  String get dontAdd => 'Nicht hinzufügen';

  @override
  String get folderFailed => 'Dieser Ordner kann nicht verwendet werden';

  @override
  String get copiesKept => 'Die Kopien im Ordner bleiben erhalten';

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
  String get recordingSection => 'Aufnahme';

  @override
  String get formatNote =>
      'Gilt für neue Aufnahmen. Beim Bearbeiten behält jede Aufnahme ihr Format.';

  @override
  String get storageSection => 'Speicherort der Aufnahmen';

  @override
  String get storageDescription =>
      'Aufnahmen werden immer in der App gespeichert. Zusätzlich kannst du von jeder eine Kopie in einem Ordner auf dem Gerät und in Google Drive behalten – mit dem Namen, den du ihr gegeben hast, und in ihrem Unterordner. Kopien werden beim Umbenennen oder Bearbeiten aktualisiert, aber beim Löschen nicht gelöscht.';

  @override
  String get deviceFolder => 'Ordner auf dem Gerät';

  @override
  String get noFolder => 'Wird in keinem Ordner gespeichert';

  @override
  String get stopSavingToFolder => 'Nicht mehr im Ordner speichern';

  @override
  String get chooseAnotherFolder => 'Anderen Ordner wählen';

  @override
  String get showFolderRecordings => 'Aufnahmen aus dem Ordner anzeigen';

  @override
  String get showFolderRecordingsSubtitle =>
      'Fügt der App die Audiodateien (.m4a und .wav) aus dem Ordner und seinen Unterordnern hinzu';

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
  String get copyNow => 'Jetzt kopieren';

  @override
  String get copyNowSubtitle =>
      'Es wird nur kopiert, was fehlt oder sich geändert hat';

  @override
  String copyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen konnten nicht kopiert werden',
      one: '1 Aufnahme konnte nicht kopiert werden',
    );
    return '$_temp0';
  }

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen aus dem Ordner konnten nicht hinzugefügt werden',
      one: '1 Aufnahme aus dem Ordner konnte nicht hinzugefügt werden',
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
}
