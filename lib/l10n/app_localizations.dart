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

  /// Nombre de la app, una marca que no se traduce (también el de su carpeta en Google Drive)
  ///
  /// In en, this message translates to:
  /// **'HummingBox'**
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

  /// Botón de la lupa, para buscar grabaciones
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Texto de ayuda del campo de búsqueda: dónde se busca (corto, para que quepa en la barra)
  ///
  /// In en, this message translates to:
  /// **'Name or transcript'**
  String get searchHint;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// Texto que aparece al tirar de la lista hacia abajo, antes del punto en que se busca al soltar
  ///
  /// In en, this message translates to:
  /// **'Pull to search'**
  String get pullToSearch;

  /// Texto que aparece al tirar de la lista hacia abajo, pasado el punto: al soltar se busca
  ///
  /// In en, this message translates to:
  /// **'Release to search'**
  String get releaseToSearch;

  /// No description provided for @noSearchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noSearchResultsTitle;

  /// No description provided for @noSearchResultsHint.
  ///
  /// In en, this message translates to:
  /// **'No recording has “{query}” in its name or transcript.'**
  String noSearchResultsHint(String query);

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

  /// No description provided for @folderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t use that folder'**
  String get folderFailed;

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
  /// **'{seconds} seconds before recording with the countdown button'**
  String countdownSubtitle(int seconds);

  /// Opción para que la pantalla no se apague mientras se graba
  ///
  /// In en, this message translates to:
  /// **'Keep the screen on'**
  String get keepScreenOn;

  /// No description provided for @keepScreenOnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'While recording or waiting to start, so the system doesn\'t stop the app'**
  String get keepScreenOnSubtitle;

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

  /// No description provided for @deviceFolder.
  ///
  /// In en, this message translates to:
  /// **'Device folder'**
  String get deviceFolder;

  /// No description provided for @noFolder.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noFolder;

  /// No description provided for @chooseAnotherFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose another folder'**
  String get chooseAnotherFolder;

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

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Couldn\'t add 1 recording} other{Couldn\'t add {count} recordings}}'**
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

  /// Grabaciones nuevas encontradas en el destino (la carpeta o Drive)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new recording} other{{count} new recordings}}'**
  String newRecordingsFound(int count);

  /// No description provided for @playFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play the recording'**
  String get playFailed;

  /// Al eliminar una grabación guardada en la carpeta del dispositivo
  ///
  /// In en, this message translates to:
  /// **'It will also be deleted from “{folder}”. This can\'t be undone.'**
  String deleteFromFolderMessage(String folder);

  /// Al eliminar una grabación guardada en Google Drive
  ///
  /// In en, this message translates to:
  /// **'It will be moved to the trash in your Google Drive.'**
  String get deleteFromDriveMessage;

  /// Mientras se guardan las grabaciones o se lee el destino
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync everything'**
  String get syncFailed;

  /// Menú inicial, cuando todavía no se ha elegido dónde guardar las grabaciones
  ///
  /// In en, this message translates to:
  /// **'Where do you want to save your recordings?'**
  String get setupTitle;

  /// No description provided for @setupMessage.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in the settings.'**
  String get setupMessage;

  /// No description provided for @setupFolder.
  ///
  /// In en, this message translates to:
  /// **'In a folder on this device'**
  String get setupFolder;

  /// No description provided for @setupFolderDescription.
  ///
  /// In en, this message translates to:
  /// **'Internal storage, an SD card, iCloud Drive… Any recordings already in it will appear in the app.'**
  String get setupFolderDescription;

  /// No description provided for @setupDrive.
  ///
  /// In en, this message translates to:
  /// **'In Google Drive'**
  String get setupDrive;

  /// No description provided for @setupDriveDescription.
  ///
  /// In en, this message translates to:
  /// **'In a folder in your Drive. Any that can\'t be uploaded yet are kept inside the app.'**
  String get setupDriveDescription;

  /// Opciones, si las grabaciones se guardan en la carpeta del dispositivo
  ///
  /// In en, this message translates to:
  /// **'Recordings are saved in the chosen folder, with the name you give them and in their subfolder, and the app shows all the audio files (.m4a and .wav) in it. Whatever you delete, rename or edit in the app also changes in the folder.'**
  String get storageFolderDescription;

  /// Opciones, si las grabaciones se guardan en Google Drive
  ///
  /// In en, this message translates to:
  /// **'Recordings are saved in the “{folder}” folder of your Google Drive and downloaded to play or edit them. Those that couldn\'t be uploaded yet (for example, while offline) are kept inside the app. If you choose a device folder, they\'ll be saved there and Drive will keep a copy.'**
  String storageDriveDescription(String folder);

  /// No description provided for @stopUsingFolder.
  ///
  /// In en, this message translates to:
  /// **'Stop using the folder'**
  String get stopUsingFolder;

  /// No description provided for @stopUsingFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop using “{folder}”?'**
  String stopUsingFolderTitle(String folder);

  /// Al dejar de usar la carpeta del dispositivo sin Google Drive conectado
  ///
  /// In en, this message translates to:
  /// **'The recordings will stay in the folder but will no longer appear in the app. Then you\'ll need to choose where to save new ones.'**
  String get stopUsingFolderMessage;

  /// Al dejar de usar la carpeta del dispositivo con Google Drive conectado
  ///
  /// In en, this message translates to:
  /// **'The recordings will stay in the folder, and the app will switch to the ones in your Google Drive, where new ones will be saved.'**
  String get stopUsingFolderDriveMessage;

  /// No description provided for @stopUsing.
  ///
  /// In en, this message translates to:
  /// **'Stop using'**
  String get stopUsing;

  /// Al desconectar Google Drive si las grabaciones se guardan en él
  ///
  /// In en, this message translates to:
  /// **'The recordings will stay in your Drive but will no longer appear in the app. Then you\'ll need to choose where to save new ones.'**
  String get disconnectDriveStorageMessage;

  /// Tras elegir la carpeta del dispositivo
  ///
  /// In en, this message translates to:
  /// **'Recordings are now saved in “{folder}”'**
  String folderInUse(String folder);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Couldn\'t save 1 recording} other{Couldn\'t save {count} recordings}}'**
  String saveFailed(int count);

  /// No description provided for @readDriveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read Google Drive'**
  String get readDriveFailed;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saves anything pending and looks for changes where recordings are saved'**
  String get syncNowSubtitle;

  /// Acción del menú de una grabación para pasar su audio a texto
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get transcribe;

  /// No description provided for @viewTranscript.
  ///
  /// In en, this message translates to:
  /// **'View transcript'**
  String get viewTranscript;

  /// Mientras se transcribe; percent es el porcentaje ya formateado («45 %»)
  ///
  /// In en, this message translates to:
  /// **'Transcribing… {percent}'**
  String transcribingProgress(String percent);

  /// No description provided for @preparingTranscription.
  ///
  /// In en, this message translates to:
  /// **'Preparing the transcription…'**
  String get preparingTranscription;

  /// No description provided for @waitingToTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Waiting to transcribe…'**
  String get waitingToTranscribe;

  /// No description provided for @cancelTranscription.
  ///
  /// In en, this message translates to:
  /// **'Cancel transcription'**
  String get cancelTranscription;

  /// No description provided for @transcriptReady.
  ///
  /// In en, this message translates to:
  /// **'Transcript ready'**
  String get transcriptReady;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @transcriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t transcribe the recording'**
  String get transcriptionFailed;

  /// No description provided for @noSpeechRecognized.
  ///
  /// In en, this message translates to:
  /// **'No words were recognized'**
  String get noSpeechRecognized;

  /// No description provided for @stopToTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Stop recording to transcribe'**
  String get stopToTranscribe;

  /// No description provided for @systemSpeechUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition isn\'t available'**
  String get systemSpeechUnavailableTitle;

  /// No description provided for @systemSpeechUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This device can\'t transcribe with the system\'s speech recognition (on Android it needs version 13 or later). You can install Whisper in the settings.'**
  String get systemSpeechUnavailableMessage;

  /// No description provided for @unsupportedLanguageMessage.
  ///
  /// In en, this message translates to:
  /// **'The system\'s speech recognition doesn\'t support “{language}” on this device. You can install Whisper or choose another language in the settings.'**
  String unsupportedLanguageMessage(String language);

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @downloadLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Download “{language}”?'**
  String downloadLanguageTitle(String language);

  /// No description provided for @downloadLanguageMessage.
  ///
  /// In en, this message translates to:
  /// **'The system\'s speech recognition needs to download this language to transcribe on the device. Try again when the download finishes.'**
  String get downloadLanguageMessage;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @languageDownloading.
  ///
  /// In en, this message translates to:
  /// **'The language is still downloading. Try again when it finishes.'**
  String get languageDownloading;

  /// No description provided for @speechPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow speech recognition in settings to transcribe'**
  String get speechPermission;

  /// No description provided for @whisperNotInstalledTitle.
  ///
  /// In en, this message translates to:
  /// **'Whisper isn\'t installed'**
  String get whisperNotInstalledTitle;

  /// No description provided for @whisperNotInstalledMessage.
  ///
  /// In en, this message translates to:
  /// **'To transcribe with Whisper, download a model in the settings.'**
  String get whisperNotInstalledMessage;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to the clipboard'**
  String get copied;

  /// No description provided for @transcribeAgain.
  ///
  /// In en, this message translates to:
  /// **'Transcribe again'**
  String get transcribeAgain;

  /// Acción para elegir el idioma de una grabación y volver a transcribirla en él
  ///
  /// In en, this message translates to:
  /// **'Transcribe in another language'**
  String get transcribeInLanguage;

  /// Título del diálogo para elegir el idioma en que se transcribe una grabación
  ///
  /// In en, this message translates to:
  /// **'Recording language'**
  String get recordingLanguage;

  /// Opción del idioma de una grabación: usar el idioma elegido en las opciones de la transcripción
  ///
  /// In en, this message translates to:
  /// **'As in Settings'**
  String get sameAsSettings;

  /// No description provided for @deleteTranscript.
  ///
  /// In en, this message translates to:
  /// **'Delete transcript'**
  String get deleteTranscript;

  /// No description provided for @transcriptDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transcript deleted'**
  String get transcriptDeleted;

  /// No description provided for @transcriptOutdated.
  ///
  /// In en, this message translates to:
  /// **'The recording has changed since it was transcribed.'**
  String get transcriptOutdated;

  /// Título de la sección de las opciones de la transcripción
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get transcriptionSection;

  /// No description provided for @transcriptionEngine.
  ///
  /// In en, this message translates to:
  /// **'Transcribe with'**
  String get transcriptionEngine;

  /// Opción para transcribir en segundo plano las grabaciones sin transcripción
  ///
  /// In en, this message translates to:
  /// **'Transcribe automatically'**
  String get autoTranscribe;

  /// No description provided for @autoTranscribeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In the background, recordings that don\'t have a transcript yet'**
  String get autoTranscribeSubtitle;

  /// Aviso cuando la transcripción automática no puede seguir; la acción «Ver» explica por qué
  ///
  /// In en, this message translates to:
  /// **'Recordings can\'t be transcribed automatically'**
  String get autoTranscriptionFailed;

  /// No description provided for @systemSpeechRecognition.
  ///
  /// In en, this message translates to:
  /// **'System speech recognition'**
  String get systemSpeechRecognition;

  /// No description provided for @systemSpeechDescription.
  ///
  /// In en, this message translates to:
  /// **'No downloads. On Android, needs version 13 or later'**
  String get systemSpeechDescription;

  /// No description provided for @whisperDescription.
  ///
  /// In en, this message translates to:
  /// **'On the device, offline. Needs a model download'**
  String get whisperDescription;

  /// No description provided for @whisperModel.
  ///
  /// In en, this message translates to:
  /// **'Whisper model'**
  String get whisperModel;

  /// No description provided for @whisperNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed. Tap to download one'**
  String get whisperNotInstalled;

  /// No description provided for @whisperInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed: {model} ({size})'**
  String whisperInstalled(String model, String size);

  /// No description provided for @whisperDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {model}… {percent} of {size}'**
  String whisperDownloading(String model, String percent, String size);

  /// No description provided for @whisperDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the model'**
  String get whisperDownloadFailed;

  /// No description provided for @chooseWhisperModel.
  ///
  /// In en, this message translates to:
  /// **'Download a model'**
  String get chooseWhisperModel;

  /// No description provided for @whisperTinyDescription.
  ///
  /// In en, this message translates to:
  /// **'{size} · Faster, less accurate'**
  String whisperTinyDescription(String size);

  /// No description provided for @whisperBaseDescription.
  ///
  /// In en, this message translates to:
  /// **'{size} · More accurate, slower'**
  String whisperBaseDescription(String size);

  /// No description provided for @deleteWhisperModel.
  ///
  /// In en, this message translates to:
  /// **'Delete the model'**
  String get deleteWhisperModel;

  /// No description provided for @deleteWhisperModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the Whisper model?'**
  String get deleteWhisperModelTitle;

  /// No description provided for @deleteWhisperModelMessage.
  ///
  /// In en, this message translates to:
  /// **'This frees {size}. You can download it again later.'**
  String deleteWhisperModelMessage(String size);

  /// No description provided for @cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get cancelDownload;

  /// No description provided for @transcriptionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get transcriptionLanguage;

  /// No description provided for @appLanguageOption.
  ///
  /// In en, this message translates to:
  /// **'The app\'s language ({language})'**
  String appLanguageOption(String language);

  /// No description provided for @detectLanguageOption.
  ///
  /// In en, this message translates to:
  /// **'Detect automatically (Whisper only)'**
  String get detectLanguageOption;

  /// Título de la sección de las opciones de la búsqueda
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchSection;

  /// Opción para que la búsqueda encuentre también palabras con erratas o variantes
  ///
  /// In en, this message translates to:
  /// **'Include similar words'**
  String get similarWords;

  /// Los ejemplos se han comprobado con la búsqueda (test/search_test.dart)
  ///
  /// In en, this message translates to:
  /// **'Also with typos or variants, like “meetng” or “meetings” for “meeting”'**
  String get similarWordsSubtitle;

  /// Título de la sección de las opciones del aspecto de la app
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// Opción para elegir el tema claro u oscuro
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Automatic (the system\'s)'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @renameToTranscriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename the recording?'**
  String get renameToTranscriptTitle;

  /// Al volver a transcribir una grabación, propone llamarla con su fecha y el principio de la nueva transcripción
  ///
  /// In en, this message translates to:
  /// **'With the new transcript, “{current}” would be called “{name}”.'**
  String renameToTranscriptMessage(String current, String name);

  /// No description provided for @keepName.
  ///
  /// In en, this message translates to:
  /// **'Keep name'**
  String get keepName;

  /// No description provided for @piano.
  ///
  /// In en, this message translates to:
  /// **'Piano'**
  String get piano;

  /// En el piano, antes de tocar ninguna tecla
  ///
  /// In en, this message translates to:
  /// **'Play a key to hear its note.\nSwipe over the small keyboard to move along it.'**
  String get pianoHint;

  /// Nombres de las siete notas naturales, de Do a Si, separados por espacios (solfeo o letras, según el idioma; en alemán, H para el Si)
  ///
  /// In en, this message translates to:
  /// **'C D E F G A B'**
  String get noteNames;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// En el piano: lo que se toca se graba siempre (el botón del piano, siempre marcado, junto al de grabar también la voz)
  ///
  /// In en, this message translates to:
  /// **'The piano is always recorded'**
  String get pianoAlwaysRecorded;

  /// En el piano: grabar las notas y la voz con el micrófono
  ///
  /// In en, this message translates to:
  /// **'Piano and voice'**
  String get pianoAndVoice;

  /// No description provided for @pianoNothingPlayed.
  ///
  /// In en, this message translates to:
  /// **'Nothing to save: no notes were played'**
  String get pianoNothingPlayed;

  /// En el piano, girado con la pantalla en vertical: darle media vuelta si se ve al revés
  ///
  /// In en, this message translates to:
  /// **'Turn around'**
  String get pianoTurnAround;

  /// En el piano: el menú para elegir con qué suenan las teclas
  ///
  /// In en, this message translates to:
  /// **'Instrument'**
  String get instrument;

  /// Instrumento: piano
  ///
  /// In en, this message translates to:
  /// **'Piano'**
  String get instrumentPiano;

  /// Instrumento: órgano
  ///
  /// In en, this message translates to:
  /// **'Organ'**
  String get instrumentOrgan;

  /// Instrumento: guitarra (de cuerdas de nailon)
  ///
  /// In en, this message translates to:
  /// **'Guitar'**
  String get instrumentGuitar;

  /// Instrumento: marimba
  ///
  /// In en, this message translates to:
  /// **'Marimba'**
  String get instrumentMarimba;

  /// Instrumento: sintetizador
  ///
  /// In en, this message translates to:
  /// **'Synthesizer'**
  String get instrumentSynth;

  /// En el sintetizador: la forma de la onda
  ///
  /// In en, this message translates to:
  /// **'Wave'**
  String get synthWave;

  /// Onda de sierra
  ///
  /// In en, this message translates to:
  /// **'Sawtooth'**
  String get waveSaw;

  /// Onda cuadrada
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get waveSquare;

  /// Onda triangular
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get waveTriangle;

  /// Onda senoidal
  ///
  /// In en, this message translates to:
  /// **'Sine'**
  String get waveSine;

  /// Sintetizador: lo que tarda en llegar al máximo al pulsar la tecla
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get synthAttack;

  /// Sintetizador: lo que tarda en bajar del máximo al nivel de sostenido
  ///
  /// In en, this message translates to:
  /// **'Decay'**
  String get synthDecay;

  /// Sintetizador: el nivel mientras se mantiene la tecla
  ///
  /// In en, this message translates to:
  /// **'Sustain'**
  String get synthSustain;

  /// Sintetizador: lo que tarda en apagarse al soltar la tecla
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get synthRelease;

  /// Sintetizador: lo abierto que está el filtro (más o menos brillante)
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get synthBrightness;

  /// Sintetizador: lo que resuena el filtro
  ///
  /// In en, this message translates to:
  /// **'Resonance'**
  String get synthResonance;

  /// Sintetizador: cuánto se desafinan entre sí sus dos osciladores
  ///
  /// In en, this message translates to:
  /// **'Detune'**
  String get synthDetune;

  /// Sintetizador: volver al sonido por defecto
  ///
  /// In en, this message translates to:
  /// **'Default sound'**
  String get synthReset;

  /// No description provided for @stopPlayback.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get stopPlayback;

  /// Interruptor del dock: al terminar una grabación, seguir con la siguiente de la lista
  ///
  /// In en, this message translates to:
  /// **'Play one after another'**
  String get playAll;

  /// Interruptor del dock: al terminar, volver a empezar (la grabación o, con la lista, la lista)
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// Botón de la barra: pasar a la vista compacta de la lista
  ///
  /// In en, this message translates to:
  /// **'Compact view'**
  String get compactView;

  /// Botón de la barra: pasar a la vista detallada de la lista
  ///
  /// In en, this message translates to:
  /// **'Detailed view'**
  String get detailedView;

  /// Opción del menú de una grabación: tocar el piano sobre ella mientras suena
  ///
  /// In en, this message translates to:
  /// **'Add piano'**
  String get addPiano;

  /// En el piano, la grabación que se acompaña
  ///
  /// In en, this message translates to:
  /// **'Over “{name}”'**
  String pianoOver(String name);

  /// Al terminar de acompañar una grabación al piano
  ///
  /// In en, this message translates to:
  /// **'Piano added to “{name}”'**
  String pianoAdded(String name);
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
