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
  String get folderFailed => 'Impossibile usare quella cartella';

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
  String get deviceFolder => 'Cartella del dispositivo';

  @override
  String get noFolder => 'Nessuna';

  @override
  String get chooseAnotherFolder => 'Scegli un\'altra cartella';

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
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossibile aggiungere $count registrazioni',
      one: 'Impossibile aggiungere 1 registrazione',
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

  @override
  String newRecordingsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuove registrazioni',
      one: '1 nuova registrazione',
    );
    return '$_temp0';
  }

  @override
  String get playFailed => 'Impossibile riprodurre la registrazione';

  @override
  String deleteFromFolderMessage(String folder) {
    return 'Verrà eliminata anche da «$folder». Questa azione non può essere annullata.';
  }

  @override
  String get deleteFromDriveMessage =>
      'Verrà spostata nel cestino del tuo Google Drive.';

  @override
  String get syncing => 'Sincronizzazione…';

  @override
  String get syncFailed => 'Non è stato possibile sincronizzare tutto';

  @override
  String get setupTitle => 'Dove vuoi salvare le registrazioni?';

  @override
  String get setupMessage => 'Potrai cambiarlo in seguito nelle impostazioni.';

  @override
  String get setupFolder => 'In una cartella del dispositivo';

  @override
  String get setupFolderDescription =>
      'Nella memoria interna, una scheda SD, iCloud Drive… Le registrazioni già presenti appariranno nell\'app.';

  @override
  String get setupDrive => 'Su Google Drive';

  @override
  String get setupDriveDescription =>
      'In una cartella del tuo Drive. Quelle che non è ancora possibile caricare restano nell\'app.';

  @override
  String get storageFolderDescription =>
      'Le registrazioni vengono salvate nella cartella scelta, con il nome che dai loro e nella loro sottocartella, e l\'app mostra tutti i file audio (.m4a e .wav) che contiene. Ciò che elimini, rinomini o modifichi nell\'app cambia anche nella cartella.';

  @override
  String storageDriveDescription(String folder) {
    return 'Le registrazioni vengono salvate nella cartella «$folder» del tuo Google Drive e scaricate per ascoltarle o modificarle. Quelle che non è ancora stato possibile caricare (ad esempio, senza connessione) restano nell\'app. Se scegli una cartella del dispositivo, verranno salvate lì e su Drive resterà una copia.';
  }

  @override
  String get stopUsingFolder => 'Smetti di usare la cartella';

  @override
  String stopUsingFolderTitle(String folder) {
    return 'Smettere di usare «$folder»?';
  }

  @override
  String get stopUsingFolderMessage =>
      'Le registrazioni resteranno nella cartella, ma non saranno più visibili nell\'app. Poi dovrai scegliere dove salvare quelle nuove.';

  @override
  String get stopUsingFolderDriveMessage =>
      'Le registrazioni resteranno nella cartella e l\'app passerà a usare quelle del tuo Google Drive, dove verranno salvate le nuove.';

  @override
  String get stopUsing => 'Smetti di usarla';

  @override
  String get disconnectDriveStorageMessage =>
      'Le registrazioni resteranno nel tuo Drive, ma non saranno più visibili nell\'app. Poi dovrai scegliere dove salvare quelle nuove.';

  @override
  String folderInUse(String folder) {
    return 'Ora le registrazioni vengono salvate in «$folder»';
  }

  @override
  String saveFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossibile salvare $count registrazioni',
      one: 'Impossibile salvare 1 registrazione',
    );
    return '$_temp0';
  }

  @override
  String get readDriveFailed => 'Impossibile leggere Google Drive';

  @override
  String get syncNow => 'Sincronizza ora';

  @override
  String get syncNowSubtitle =>
      'Salva ciò che è in sospeso e cerca modifiche dove sono salvate le registrazioni';
}
