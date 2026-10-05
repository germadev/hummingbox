import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';
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
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('pt'),
    Locale('zh'),
  ];

  /// Nombre de la app (también el de su carpeta en Google Drive)
  ///
  /// In en, this message translates to:
  /// **'Recorder'**
  String get appTitle;

  /// Botón para cancelar
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Botón para guardar
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Eliminar una grabación
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Descartar lo grabado o los cambios
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Crear una carpeta
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Etiqueta del campo de nombre
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// Nombre de las grabaciones nuevas, seguido de un número («Grabación 3»)
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get defaultRecordingName;

  /// Nombre de la copia de una grabación editada
  ///
  /// In en, this message translates to:
  /// **'{name} (edited)'**
  String editedCopyName(String name);

  /// No description provided for @loadRecordingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the recordings'**
  String get loadRecordingsFailed;

  /// Grabaciones añadidas desde la carpeta del dispositivo
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recording added from the folder} other{{count} recordings added from the folder}}'**
  String importedFromFolder(int count);

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @invalidFolderName.
  ///
  /// In en, this message translates to:
  /// **'That name can\'t be used for a folder'**
  String get invalidFolderName;

  /// No description provided for @microphonePermission.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access in settings to record'**
  String get microphonePermission;

  /// No description provided for @startRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start recording'**
  String get startRecordingFailed;

  /// No description provided for @saveRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the recording'**
  String get saveRecordingFailed;

  /// No description provided for @savedAs.
  ///
  /// In en, this message translates to:
  /// **'Saved as “{name}”'**
  String savedAs(String name);

  /// No description provided for @discardRecordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard the recording?'**
  String get discardRecordingTitle;

  /// No description provided for @discardRecordingMessage.
  ///
  /// In en, this message translates to:
  /// **'The audio recorded so far will be lost.'**
  String get discardRecordingMessage;

  /// No description provided for @stopToPlay.
  ///
  /// In en, this message translates to:
  /// **'Stop recording to play'**
  String get stopToPlay;

  /// No description provided for @stopToEdit.
  ///
  /// In en, this message translates to:
  /// **'Stop recording to edit'**
  String get stopToEdit;

  /// No description provided for @stopToLeave.
  ///
  /// In en, this message translates to:
  /// **'Stop recording before leaving'**
  String get stopToLeave;

  /// No description provided for @changesSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get changesSaved;

  /// No description provided for @renameFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename the recording'**
  String get renameFailed;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share the recording'**
  String get shareFailed;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteTitle(String name);

  /// No description provided for @deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get deleteMessage;

  /// No description provided for @recordingDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recording deleted'**
  String get recordingDeleted;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the recording'**
  String get deleteFailed;

  /// Pantalla de opciones
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Carpeta principal en el menú lateral, si no hay carpeta del dispositivo
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get rootFolder;

  /// No description provided for @savingCopies.
  ///
  /// In en, this message translates to:
  /// **'Saving copies…'**
  String get savingCopies;

  /// No description provided for @copiesFailed.
  ///
  /// In en, this message translates to:
  /// **'Some copies couldn\'t be saved'**
  String get copiesFailed;

  /// No description provided for @emptyFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get emptyFolderTitle;

  /// No description provided for @emptyFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the red button to record in it.'**
  String get emptyFolderHint;

  /// No description provided for @noRecordingsTitle.
  ///
  /// In en, this message translates to:
  /// **'No recordings yet'**
  String get noRecordingsTitle;

  /// No description provided for @noRecordingsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the red button to start recording.'**
  String get noRecordingsHint;

  /// Título del menú lateral
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Fecha de una grabación de hoy
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String dateToday(String time);

  /// Fecha de una grabación de ayer
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String dateYesterday(String time);

  /// Fecha de una grabación anterior
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String dateOther(String date, String time);

  /// No description provided for @stereo.
  ///
  /// In en, this message translates to:
  /// **'stereo'**
  String get stereo;

  /// Número de canales de audio (más de dos)
  ///
  /// In en, this message translates to:
  /// **'{count} channels'**
  String channels(int count);

  /// Bits por muestra de un WAV
  ///
  /// In en, this message translates to:
  /// **'{bits}-bit'**
  String bitDepth(int bits);

  /// Lo que ocupa un minuto de grabación
  ///
  /// In en, this message translates to:
  /// **'{size} per minute'**
  String perMinute(String size);

  /// Título del diálogo de renombrar
  ///
  /// In en, this message translates to:
  /// **'Rename recording'**
  String get renameRecording;

  /// No description provided for @hideRecordPanel.
  ///
  /// In en, this message translates to:
  /// **'Hide the recording panel'**
  String get hideRecordPanel;

  /// No description provided for @showRecordPanel.
  ///
  /// In en, this message translates to:
  /// **'Show the recording panel'**
  String get showRecordPanel;

  /// Encima del número de la cuenta atrás
  ///
  /// In en, this message translates to:
  /// **'Recording starts in…'**
  String get countdownStatus;

  /// No description provided for @waitingForVoice.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you to speak…'**
  String get waitingForVoice;

  /// No description provided for @readyToRecord.
  ///
  /// In en, this message translates to:
  /// **'Ready to record'**
  String get readyToRecord;

  /// No description provided for @recordingStatus.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordingStatus;

  /// No description provided for @pausedStatus.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get pausedStatus;

  /// No description provided for @countdownButton.
  ///
  /// In en, this message translates to:
  /// **'Record after a {seconds}-second countdown'**
  String countdownButton(int seconds);

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @voiceButton.
  ///
  /// In en, this message translates to:
  /// **'Record when you start speaking'**
  String get voiceButton;

  /// No description provided for @stopAndSave.
  ///
  /// In en, this message translates to:
  /// **'Stop and save'**
  String get stopAndSave;

  /// No description provided for @startNow.
  ///
  /// In en, this message translates to:
  /// **'Start now'**
  String get startNow;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @previewFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t prepare the preview'**
  String get previewFailed;

  /// No description provided for @editSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the edit'**
  String get editSaveFailed;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Changes you haven\'t saved will be lost.'**
  String get discardChangesMessage;

  /// No description provided for @editRecording.
  ///
  /// In en, this message translates to:
  /// **'Edit recording'**
  String get editRecording;

  /// Deshacer todos los cambios del editor
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @saveCopy.
  ///
  /// In en, this message translates to:
  /// **'Save copy'**
  String get saveCopy;

  /// No description provided for @openAudioFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the audio to edit it.'**
  String get openAudioFailed;

  /// No description provided for @preparingAudio.
  ///
  /// In en, this message translates to:
  /// **'Preparing audio…'**
  String get preparingAudio;

  /// Inicio de la selección
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get trimStartLabel;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// Fin de la selección
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get trimEndLabel;

  /// No description provided for @playSelection.
  ///
  /// In en, this message translates to:
  /// **'Play selection'**
  String get playSelection;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @normalize.
  ///
  /// In en, this message translates to:
  /// **'Normalize'**
  String get normalize;

  /// No description provided for @clippingWarning.
  ///
  /// In en, this message translates to:
  /// **'The loudest parts will clip'**
  String get clippingWarning;

  /// No description provided for @fadeIn.
  ///
  /// In en, this message translates to:
  /// **'Fade in'**
  String get fadeIn;

  /// No description provided for @fadeOut.
  ///
  /// In en, this message translates to:
  /// **'Fade out'**
  String get fadeOut;

  /// Asa del inicio del recorte (accesibilidad)
  ///
  /// In en, this message translates to:
  /// **'Trim start'**
  String get trimStartHandle;

  /// Asa del fin del recorte (accesibilidad)
  ///
  /// In en, this message translates to:
  /// **'Trim end'**
  String get trimEndHandle;

  /// Onda como barra de progreso (accesibilidad)
  ///
  /// In en, this message translates to:
  /// **'Playback position'**
  String get playbackPosition;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Add the folder\'s recordings?'**
  String get importTitle;

  /// Al elegir una carpeta con audios que la app no tiene
  ///
  /// In en, this message translates to:
  /// **'“{folder}” has {count, plural, =1{1 audio file} other{{count} audio files}} ({size}) that aren\'t in the app. If you add them, they\'ll appear in the list and be copied into the app.'**
  String importMessage(String folder, int count, String size);

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @dontAdd.
  ///
  /// In en, this message translates to:
  /// **'Don\'t add'**
  String get dontAdd;

  /// No description provided for @folderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t use that folder'**
  String get folderFailed;

  /// No description provided for @copiesKept.
  ///
  /// In en, this message translates to:
  /// **'The copies already in the folder are kept'**
  String get copiesKept;

  /// No description provided for @driveConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to Google Drive'**
  String get driveConnectFailed;

  /// No description provided for @disconnectDriveTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Google Drive?'**
  String get disconnectDriveTitle;

  /// No description provided for @disconnectDriveMessage.
  ///
  /// In en, this message translates to:
  /// **'Copies will no longer be saved to Drive. The ones already there are kept.'**
  String get disconnectDriveMessage;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// Formato de archivo
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @aacDescription.
  ///
  /// In en, this message translates to:
  /// **'Compressed: small files that play on any device'**
  String get aacDescription;

  /// No description provided for @wavDescription.
  ///
  /// In en, this message translates to:
  /// **'Uncompressed: the highest fidelity, but much larger files'**
  String get wavDescription;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @qualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get qualityLow;

  /// No description provided for @qualityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get qualityMedium;

  /// No description provided for @qualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get qualityHigh;

  /// No description provided for @countdown.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get countdown;

  /// No description provided for @secondsCount.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds'**
  String secondsCount(int seconds);

  /// No description provided for @countdownSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds before recording with the ⏱ button'**
  String countdownSubtitle(int seconds);

  /// Sección de las opciones
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordingSection;

  /// No description provided for @formatNote.
  ///
  /// In en, this message translates to:
  /// **'Applies to new recordings. When editing, each recording keeps its format.'**
  String get formatNote;

  /// Sección de las opciones
  ///
  /// In en, this message translates to:
  /// **'Where recordings are saved'**
  String get storageSection;

  /// No description provided for @storageDescription.
  ///
  /// In en, this message translates to:
  /// **'Recordings are always saved inside the app. You can also keep a copy of each one in a device folder and in Google Drive, with the name you gave it and in its subfolder. Copies are updated when you rename or edit a recording, but aren\'t deleted when you delete it.'**
  String get storageDescription;

  /// No description provided for @deviceFolder.
  ///
  /// In en, this message translates to:
  /// **'Device folder'**
  String get deviceFolder;

  /// No description provided for @noFolder.
  ///
  /// In en, this message translates to:
  /// **'Not saved to any folder'**
  String get noFolder;

  /// No description provided for @stopSavingToFolder.
  ///
  /// In en, this message translates to:
  /// **'Stop saving to the folder'**
  String get stopSavingToFolder;

  /// No description provided for @chooseAnotherFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose another folder'**
  String get chooseAnotherFolder;

  /// No description provided for @showFolderRecordings.
  ///
  /// In en, this message translates to:
  /// **'Show the folder\'s recordings'**
  String get showFolderRecordings;

  /// No description provided for @showFolderRecordingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adds the audio files (.m4a and .wav) in the folder and its subfolders to the app'**
  String get showFolderRecordingsSubtitle;

  /// Cuenta y carpeta de Google Drive conectadas
  ///
  /// In en, this message translates to:
  /// **'{email} · folder “{folder}”'**
  String driveAccount(String email, String folder);

  /// No description provided for @driveSaveCopy.
  ///
  /// In en, this message translates to:
  /// **'Save a copy to your Google Drive'**
  String get driveSaveCopy;

  /// No description provided for @driveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available: this version of the app isn\'t set up to access Google'**
  String get driveUnavailable;

  /// No description provided for @copyNow.
  ///
  /// In en, this message translates to:
  /// **'Copy now'**
  String get copyNow;

  /// No description provided for @copyNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only what\'s missing or changed is copied'**
  String get copyNowSubtitle;

  /// No description provided for @copyFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Couldn\'t copy 1 recording} other{Couldn\'t copy {count} recordings}}'**
  String copyFailed(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Couldn\'t add 1 recording from the folder} other{Couldn\'t add {count} recordings from the folder}}'**
  String importFailed(int count);

  /// No description provided for @readFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the folder'**
  String get readFolderFailed;

  /// No description provided for @readRecordingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the recordings'**
  String get readRecordingsFailed;

  /// No description provided for @driveReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect your Google Drive account'**
  String get driveReconnect;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get offline;

  /// No description provided for @noFolderPermission.
  ///
  /// In en, this message translates to:
  /// **'No permission for the folder anymore. Choose it again.'**
  String get noFolderPermission;

  /// Un error y su causa
  ///
  /// In en, this message translates to:
  /// **'{message}: {detail}'**
  String errorWithDetail(String message, String detail);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'ja',
    'pt',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
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
