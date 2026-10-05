// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Registratore';

  @override
  String get cancel => 'Annulla';

  @override
  String get save => 'Salva';

  @override
  String get delete => 'Elimina';

  @override
  String get discard => 'Scarta';

  @override
  String get create => 'Crea';

  @override
  String get nameLabel => 'Nome';

  @override
  String get defaultRecordingName => 'Registrazione';

  @override
  String editedCopyName(String name) {
    return '$name (modificata)';
  }

  @override
  String get loadRecordingsFailed => 'Impossibile caricare le registrazioni';

  @override
  String importedFromFolder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aggiunte $count registrazioni dalla cartella',
      one: 'Aggiunta 1 registrazione dalla cartella',
    );
    return '$_temp0';
  }

  @override
  String get newFolder => 'Nuova cartella';

  @override
  String get invalidFolderName => 'Questo nome non è valido per una cartella';

  @override
  String get microphonePermission =>
      'Consenti l\'accesso al microfono nelle impostazioni per registrare';

  @override
  String get startRecordingFailed => 'Impossibile avviare la registrazione';

  @override
  String get saveRecordingFailed => 'Impossibile salvare la registrazione';

  @override
  String savedAs(String name) {
    return 'Salvata come «$name»';
  }

  @override
  String get discardRecordingTitle => 'Scartare la registrazione?';

  @override
  String get discardRecordingMessage =>
      'L\'audio registrato finora andrà perso.';

  @override
  String get stopToPlay => 'Interrompi la registrazione per riprodurre';

  @override
  String get stopToEdit => 'Interrompi la registrazione per modificare';

  @override
  String get stopToLeave => 'Interrompi la registrazione prima di uscire';

  @override
  String get changesSaved => 'Modifiche salvate';

  @override
  String get renameFailed => 'Impossibile rinominare la registrazione';

  @override
  String get shareFailed => 'Impossibile condividere la registrazione';

  @override
  String deleteTitle(String name) {
    return 'Eliminare «$name»?';
  }

  @override
  String get deleteMessage => 'Questa azione non può essere annullata.';

  @override
  String get recordingDeleted => 'Registrazione eliminata';

  @override
  String get deleteFailed => 'Impossibile eliminare la registrazione';

  @override
  String get settings => 'Impostazioni';

  @override
  String get rootFolder => 'Registrazioni';

  @override
  String get savingCopies => 'Salvataggio delle copie…';

  @override
  String get copiesFailed => 'Non è stato possibile salvare alcune copie';

  @override
  String get emptyFolderTitle => 'Questa cartella è vuota';

  @override
  String get emptyFolderHint => 'Tocca il pulsante rosso per registrare qui.';

  @override
  String get noRecordingsTitle => 'Ancora nessuna registrazione';

  @override
  String get noRecordingsHint =>
      'Tocca il pulsante rosso per iniziare a registrare.';

  @override
  String get folders => 'Cartelle';

  @override
  String get play => 'Riproduci';

  @override
  String get pause => 'Pausa';

  @override
  String get rename => 'Rinomina';

  @override
  String get moreOptions => 'Altre opzioni';

  @override
  String get edit => 'Modifica';

  @override
  String get share => 'Condividi';

  @override
  String dateToday(String time) {
    return 'Oggi, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'Ieri, $time';
  }

  @override
  String dateOther(String date, String time) {
    return '$date, $time';
  }

  @override
  String get stereo => 'stereo';

  @override
  String channels(int count) {
    return '$count canali';
  }

  @override
  String bitDepth(int bits) {
    return '$bits bit';
  }

  @override
  String perMinute(String size) {
    return '$size al minuto';
  }

  @override
  String get renameRecording => 'Rinomina registrazione';

  @override
  String get hideRecordPanel => 'Nascondi il pannello di registrazione';

  @override
  String get showRecordPanel => 'Mostra il pannello di registrazione';

  @override
  String get countdownStatus => 'La registrazione inizia tra…';

  @override
  String get waitingForVoice => 'In attesa che tu parli…';

  @override
  String get readyToRecord => 'Pronto per registrare';

  @override
  String get recordingStatus => 'Registrazione in corso';

  @override
  String get pausedStatus => 'In pausa';

  @override
  String countdownButton(int seconds) {
    return 'Registra dopo un conto alla rovescia di $seconds s';
  }

  @override
  String get resume => 'Riprendi';

  @override
  String get voiceButton => 'Registra quando inizi a parlare';

  @override
  String get stopAndSave => 'Interrompi e salva';

  @override
  String get startNow => 'Inizia ora';

  @override
  String get record => 'Registra';

  @override
  String get previewFailed => 'Impossibile preparare l\'anteprima';

  @override
  String get editSaveFailed => 'Impossibile salvare la modifica';

  @override
  String get discardChangesTitle => 'Scartare le modifiche?';

  @override
  String get discardChangesMessage =>
      'Le modifiche non salvate andranno perse.';

  @override
  String get editRecording => 'Modifica registrazione';

  @override
  String get reset => 'Ripristina';

  @override
  String get saving => 'Salvataggio…';

  @override
  String get saveCopy => 'Salva copia';

  @override
  String get openAudioFailed => 'Impossibile aprire l\'audio per modificarlo.';

  @override
  String get preparingAudio => 'Preparazione dell\'audio…';

  @override
  String get trimStartLabel => 'Inizio';

  @override
  String get durationLabel => 'Durata';

  @override
  String get trimEndLabel => 'Fine';

  @override
  String get playSelection => 'Ascolta la selezione';

  @override
  String get volume => 'Volume';

  @override
  String get normalize => 'Normalizza';

  @override
  String get clippingWarning => 'Le parti più forti satureranno';

  @override
  String get fadeIn => 'Dissolvenza in entrata';

  @override
  String get fadeOut => 'Dissolvenza in uscita';

  @override
  String get trimStartHandle => 'Inizio del taglio';

  @override
  String get trimEndHandle => 'Fine del taglio';

  @override
  String get playbackPosition => 'Posizione di riproduzione';

  @override
  String get importTitle => 'Aggiungere le registrazioni della cartella?';

  @override
  String importMessage(String folder, int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file audio',
      one: '1 file audio',
    );
    return '«$folder» contiene $_temp0 ($size) che non sono nell\'app. Se li aggiungi, compariranno nell\'elenco e verranno copiati nell\'app.';
  }

  @override
  String get add => 'Aggiungi';

  @override
  String get dontAdd => 'Non aggiungere';

  @override
  String get folderFailed => 'Impossibile usare quella cartella';

  @override
  String get copiesKept =>
      'Le copie già presenti nella cartella vengono mantenute';

  @override
  String get driveConnectFailed => 'Impossibile connettersi a Google Drive';

  @override
  String get disconnectDriveTitle => 'Disconnettere Google Drive?';

  @override
  String get disconnectDriveMessage =>
      'Non verranno più salvate copie su Drive. Quelle già presenti vengono mantenute.';

  @override
  String get disconnect => 'Disconnetti';

  @override
  String get format => 'Formato';

  @override
  String get aacDescription =>
      'Compresso: occupa poco spazio e si riproduce su qualsiasi dispositivo';

  @override
  String get wavDescription =>
      'Non compresso: massima fedeltà, ma occupa molto più spazio';

  @override
  String get quality => 'Qualità';

  @override
  String get qualityLow => 'Bassa';

  @override
  String get qualityMedium => 'Media';

  @override
  String get qualityHigh => 'Alta';

  @override
  String get countdown => 'Conto alla rovescia';

  @override
  String secondsCount(int seconds) {
    return '$seconds secondi';
  }

  @override
  String countdownSubtitle(int seconds) {
    return '$seconds secondi prima di iniziare a registrare con il pulsante del conto alla rovescia';
  }

  @override
  String get recordingSection => 'Registrazione';

  @override
  String get formatNote =>
      'Si applica alle nuove registrazioni. Durante la modifica, ogni registrazione mantiene il suo formato.';

  @override
  String get storageSection => 'Dove vengono salvate le registrazioni';

  @override
  String get storageDescription =>
      'Le registrazioni vengono sempre salvate all\'interno dell\'app. Puoi anche conservarne una copia in una cartella del dispositivo e su Google Drive, con il nome che le hai dato e nella sua sottocartella. Le copie si aggiornano quando rinomini o modifichi una registrazione, ma non vengono eliminate quando la elimini.';

  @override
  String get deviceFolder => 'Cartella del dispositivo';

  @override
  String get noFolder => 'Non salvato in nessuna cartella';

  @override
  String get stopSavingToFolder => 'Smetti di salvare nella cartella';

  @override
  String get chooseAnotherFolder => 'Scegli un\'altra cartella';

  @override
  String get showFolderRecordings => 'Mostra le registrazioni della cartella';

  @override
  String get showFolderRecordingsSubtitle =>
      'Aggiunge all\'app i file audio (.m4a e .wav) della cartella e delle sue sottocartelle';

  @override
  String driveAccount(String email, String folder) {
    return '$email · cartella «$folder»';
  }

  @override
  String get driveSaveCopy => 'Salva una copia sul tuo Google Drive';

  @override
  String get driveUnavailable =>
      'Non disponibile: questa versione dell\'app non è configurata per accedere a Google';

  @override
  String get copyNow => 'Copia ora';

  @override
  String get copyNowSubtitle => 'Viene copiato solo ciò che manca o è cambiato';

  @override
  String copyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossibile copiare $count registrazioni',
      one: 'Impossibile copiare 1 registrazione',
    );
    return '$_temp0';
  }

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossibile aggiungere $count registrazioni dalla cartella',
      one: 'Impossibile aggiungere 1 registrazione dalla cartella',
    );
    return '$_temp0';
  }

  @override
  String get readFolderFailed => 'Impossibile leggere la cartella';

  @override
  String get readRecordingsFailed => 'Impossibile leggere le registrazioni';

  @override
  String get driveReconnect => 'Ricollega il tuo account Google Drive';

  @override
  String get offline => 'Nessuna connessione';

  @override
  String get noFolderPermission =>
      'Non c\'è più il permesso per la cartella. Sceglila di nuovo.';

  @override
  String errorWithDetail(String message, String detail) {
    return '$message: $detail';
  }
}
