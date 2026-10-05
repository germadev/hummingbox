// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HummingBox';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get discard => 'Discard';

  @override
  String get create => 'Create';

  @override
  String get nameLabel => 'Name';

  @override
  String get defaultRecordingName => 'Recording';

  @override
  String editedCopyName(String name) {
    return '$name (edited)';
  }

  @override
  String get loadRecordingsFailed => 'Couldn\'t load the recordings';

  @override
  String get newFolder => 'New folder';

  @override
  String get invalidFolderName => 'That name can\'t be used for a folder';

  @override
  String get microphonePermission =>
      'Allow microphone access in settings to record';

  @override
  String get startRecordingFailed => 'Couldn\'t start recording';

  @override
  String get saveRecordingFailed => 'Couldn\'t save the recording';

  @override
  String savedAs(String name) {
    return 'Saved as “$name”';
  }

  @override
  String get discardRecordingTitle => 'Discard the recording?';

  @override
  String get discardRecordingMessage =>
      'The audio recorded so far will be lost.';

  @override
  String get stopToPlay => 'Stop recording to play';

  @override
  String get stopToEdit => 'Stop recording to edit';

  @override
  String get stopToLeave => 'Stop recording before leaving';

  @override
  String get changesSaved => 'Changes saved';

  @override
  String get renameFailed => 'Couldn\'t rename the recording';

  @override
  String get shareFailed => 'Couldn\'t share the recording';

  @override
  String deleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteMessage => 'This can\'t be undone.';

  @override
  String get recordingDeleted => 'Recording deleted';

  @override
  String get deleteFailed => 'Couldn\'t delete the recording';

  @override
  String get settings => 'Settings';

  @override
  String get rootFolder => 'Recordings';

  @override
  String get emptyFolderTitle => 'This folder is empty';

  @override
  String get emptyFolderHint => 'Tap the red button to record in it.';

  @override
  String get noRecordingsTitle => 'No recordings yet';

  @override
  String get noRecordingsHint => 'Tap the red button to start recording.';

  @override
  String get folders => 'Folders';

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Name or transcript';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get pullToSearch => 'Pull to search';

  @override
  String get releaseToSearch => 'Release to search';

  @override
  String get noSearchResultsTitle => 'No results';

  @override
  String noSearchResultsHint(String query) {
    return 'No recording has “$query” in its name or transcript.';
  }

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get rename => 'Rename';

  @override
  String get moreOptions => 'More options';

  @override
  String get edit => 'Edit';

  @override
  String get share => 'Share';

  @override
  String dateToday(String time) {
    return 'Today, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'Yesterday, $time';
  }

  @override
  String dateOther(String date, String time) {
    return '$date, $time';
  }

  @override
  String get stereo => 'stereo';

  @override
  String channels(int count) {
    return '$count channels';
  }

  @override
  String bitDepth(int bits) {
    return '$bits-bit';
  }

  @override
  String perMinute(String size) {
    return '$size per minute';
  }

  @override
  String get renameRecording => 'Rename recording';

  @override
  String get hideRecordPanel => 'Hide the recording panel';

  @override
  String get showRecordPanel => 'Show the recording panel';

  @override
  String get countdownStatus => 'Recording starts in…';

  @override
  String get waitingForVoice => 'Waiting for you to speak…';

  @override
  String get readyToRecord => 'Ready to record';

  @override
  String get recordingStatus => 'Recording';

  @override
  String get pausedStatus => 'Paused';

  @override
  String countdownButton(int seconds) {
    return 'Record after a $seconds-second countdown';
  }

  @override
  String get resume => 'Resume';

  @override
  String get voiceButton => 'Record when you start speaking';

  @override
  String get stopAndSave => 'Stop and save';

  @override
  String get startNow => 'Start now';

  @override
  String get record => 'Record';

  @override
  String get previewFailed => 'Couldn\'t prepare the preview';

  @override
  String get editSaveFailed => 'Couldn\'t save the edit';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesMessage =>
      'Changes you haven\'t saved will be lost.';

  @override
  String get editRecording => 'Edit recording';

  @override
  String get reset => 'Reset';

  @override
  String get saving => 'Saving…';

  @override
  String get saveCopy => 'Save copy';

  @override
  String get openAudioFailed => 'Couldn\'t open the audio to edit it.';

  @override
  String get preparingAudio => 'Preparing audio…';

  @override
  String get trimStartLabel => 'Start';

  @override
  String get durationLabel => 'Duration';

  @override
  String get trimEndLabel => 'End';

  @override
  String get playSelection => 'Play selection';

  @override
  String get volume => 'Volume';

  @override
  String get normalize => 'Normalize';

  @override
  String get clippingWarning => 'The loudest parts will clip';

  @override
  String get fadeIn => 'Fade in';

  @override
  String get fadeOut => 'Fade out';

  @override
  String get trimStartHandle => 'Trim start';

  @override
  String get trimEndHandle => 'Trim end';

  @override
  String get playbackPosition => 'Playback position';

  @override
  String get folderFailed => 'Couldn\'t use that folder';

  @override
  String get driveConnectFailed => 'Couldn\'t connect to Google Drive';

  @override
  String get disconnectDriveTitle => 'Disconnect Google Drive?';

  @override
  String get disconnectDriveMessage =>
      'Copies will no longer be saved to Drive. The ones already there are kept.';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get format => 'Format';

  @override
  String get aacDescription =>
      'Compressed: small files that play on any device';

  @override
  String get wavDescription =>
      'Uncompressed: the highest fidelity, but much larger files';

  @override
  String get quality => 'Quality';

  @override
  String get qualityLow => 'Low';

  @override
  String get qualityMedium => 'Medium';

  @override
  String get qualityHigh => 'High';

  @override
  String get countdown => 'Countdown';

  @override
  String secondsCount(int seconds) {
    return '$seconds seconds';
  }

  @override
  String countdownSubtitle(int seconds) {
    return '$seconds seconds before recording with the countdown button';
  }

  @override
  String get keepScreenOn => 'Keep the screen on';

  @override
  String get keepScreenOnSubtitle =>
      'While recording or waiting to start, so the system doesn\'t stop the app';

  @override
  String get recordingSection => 'Recording';

  @override
  String get formatNote =>
      'Applies to new recordings. When editing, each recording keeps its format.';

  @override
  String get storageSection => 'Where recordings are saved';

  @override
  String get deviceFolder => 'Device folder';

  @override
  String get noFolder => 'None';

  @override
  String get chooseAnotherFolder => 'Choose another folder';

  @override
  String driveAccount(String email, String folder) {
    return '$email · folder “$folder”';
  }

  @override
  String get driveSaveCopy => 'Save a copy to your Google Drive';

  @override
  String get driveUnavailable =>
      'Not available: this version of the app isn\'t set up to access Google';

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn\'t add $count recordings',
      one: 'Couldn\'t add 1 recording',
    );
    return '$_temp0';
  }

  @override
  String get readFolderFailed => 'Couldn\'t read the folder';

  @override
  String get readRecordingsFailed => 'Couldn\'t read the recordings';

  @override
  String get driveReconnect => 'Reconnect your Google Drive account';

  @override
  String get offline => 'No connection';

  @override
  String get noFolderPermission =>
      'No permission for the folder anymore. Choose it again.';

  @override
  String errorWithDetail(String message, String detail) {
    return '$message: $detail';
  }

  @override
  String newRecordingsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new recordings',
      one: '1 new recording',
    );
    return '$_temp0';
  }

  @override
  String get playFailed => 'Couldn\'t play the recording';

  @override
  String deleteFromFolderMessage(String folder) {
    return 'It will also be deleted from “$folder”. This can\'t be undone.';
  }

  @override
  String get deleteFromDriveMessage =>
      'It will be moved to the trash in your Google Drive.';

  @override
  String get syncing => 'Syncing…';

  @override
  String get syncFailed => 'Couldn\'t sync everything';

  @override
  String get setupTitle => 'Where do you want to save your recordings?';

  @override
  String get setupMessage => 'You can change this later in the settings.';

  @override
  String get setupFolder => 'In a folder on this device';

  @override
  String get setupFolderDescription =>
      'Internal storage, an SD card, iCloud Drive… Any recordings already in it will appear in the app.';

  @override
  String get setupDrive => 'In Google Drive';

  @override
  String get setupDriveDescription =>
      'In a folder in your Drive. Any that can\'t be uploaded yet are kept inside the app.';

  @override
  String get storageFolderDescription =>
      'Recordings are saved in the chosen folder, with the name you give them and in their subfolder, and the app shows all the audio files (.m4a and .wav) in it. Whatever you delete, rename or edit in the app also changes in the folder.';

  @override
  String storageDriveDescription(String folder) {
    return 'Recordings are saved in the “$folder” folder of your Google Drive and downloaded to play or edit them. Those that couldn\'t be uploaded yet (for example, while offline) are kept inside the app. If you choose a device folder, they\'ll be saved there and Drive will keep a copy.';
  }

  @override
  String get stopUsingFolder => 'Stop using the folder';

  @override
  String stopUsingFolderTitle(String folder) {
    return 'Stop using “$folder”?';
  }

  @override
  String get stopUsingFolderMessage =>
      'The recordings will stay in the folder but will no longer appear in the app. Then you\'ll need to choose where to save new ones.';

  @override
  String get stopUsingFolderDriveMessage =>
      'The recordings will stay in the folder, and the app will switch to the ones in your Google Drive, where new ones will be saved.';

  @override
  String get stopUsing => 'Stop using';

  @override
  String get disconnectDriveStorageMessage =>
      'The recordings will stay in your Drive but will no longer appear in the app. Then you\'ll need to choose where to save new ones.';

  @override
  String folderInUse(String folder) {
    return 'Recordings are now saved in “$folder”';
  }

  @override
  String saveFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn\'t save $count recordings',
      one: 'Couldn\'t save 1 recording',
    );
    return '$_temp0';
  }

  @override
  String get readDriveFailed => 'Couldn\'t read Google Drive';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncNowSubtitle =>
      'Saves anything pending and looks for changes where recordings are saved';

  @override
  String get transcribe => 'Transcribe';

  @override
  String get viewTranscript => 'View transcript';

  @override
  String transcribingProgress(String percent) {
    return 'Transcribing… $percent';
  }

  @override
  String get preparingTranscription => 'Preparing the transcription…';

  @override
  String get waitingToTranscribe => 'Waiting to transcribe…';

  @override
  String get cancelTranscription => 'Cancel transcription';

  @override
  String get transcriptReady => 'Transcript ready';

  @override
  String get view => 'View';

  @override
  String get transcriptionFailed => 'Couldn\'t transcribe the recording';

  @override
  String get noSpeechRecognized => 'No words were recognized';

  @override
  String get stopToTranscribe => 'Stop recording to transcribe';

  @override
  String get systemSpeechUnavailableTitle =>
      'Speech recognition isn\'t available';

  @override
  String get systemSpeechUnavailableMessage =>
      'This device can\'t transcribe with the system\'s speech recognition (on Android it needs version 13 or later). You can install Whisper in the settings.';

  @override
  String unsupportedLanguageMessage(String language) {
    return 'The system\'s speech recognition doesn\'t support “$language” on this device. You can install Whisper or choose another language in the settings.';
  }

  @override
  String get openSettings => 'Open settings';

  @override
  String downloadLanguageTitle(String language) {
    return 'Download “$language”?';
  }

  @override
  String get downloadLanguageMessage =>
      'The system\'s speech recognition needs to download this language to transcribe on the device. Try again when the download finishes.';

  @override
  String get download => 'Download';

  @override
  String get languageDownloading =>
      'The language is still downloading. Try again when it finishes.';

  @override
  String get speechPermission =>
      'Allow speech recognition in settings to transcribe';

  @override
  String get whisperNotInstalledTitle => 'Whisper isn\'t installed';

  @override
  String get whisperNotInstalledMessage =>
      'To transcribe with Whisper, download a model in the settings.';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied to the clipboard';

  @override
  String get transcribeAgain => 'Transcribe again';

  @override
  String get transcribeInLanguage => 'Transcribe in another language';

  @override
  String get recordingLanguage => 'Recording language';

  @override
  String get sameAsSettings => 'As in Settings';

  @override
  String get deleteTranscript => 'Delete transcript';

  @override
  String get transcriptDeleted => 'Transcript deleted';

  @override
  String get transcriptOutdated =>
      'The recording has changed since it was transcribed.';

  @override
  String get transcriptionSection => 'Transcription';

  @override
  String get transcriptionEngine => 'Transcribe with';

  @override
  String get autoTranscribe => 'Transcribe automatically';

  @override
  String get autoTranscribeSubtitle =>
      'In the background, recordings that don\'t have a transcript yet';

  @override
  String get autoTranscriptionFailed =>
      'Recordings can\'t be transcribed automatically';

  @override
  String get systemSpeechRecognition => 'System speech recognition';

  @override
  String get systemSpeechDescription =>
      'No downloads. On Android, needs version 13 or later';

  @override
  String get whisperDescription =>
      'On the device, offline. Needs a model download';

  @override
  String get whisperModel => 'Whisper model';

  @override
  String get whisperNotInstalled => 'Not installed. Tap to download one';

  @override
  String whisperInstalled(String model, String size) {
    return 'Installed: $model ($size)';
  }

  @override
  String whisperDownloading(String model, String percent, String size) {
    return 'Downloading $model… $percent of $size';
  }

  @override
  String get whisperDownloadFailed => 'Couldn\'t download the model';

  @override
  String get chooseWhisperModel => 'Download a model';

  @override
  String whisperTinyDescription(String size) {
    return '$size · Faster, less accurate';
  }

  @override
  String whisperBaseDescription(String size) {
    return '$size · More accurate, slower';
  }

  @override
  String get deleteWhisperModel => 'Delete the model';

  @override
  String get deleteWhisperModelTitle => 'Delete the Whisper model?';

  @override
  String deleteWhisperModelMessage(String size) {
    return 'This frees $size. You can download it again later.';
  }

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get transcriptionLanguage => 'Language';

  @override
  String appLanguageOption(String language) {
    return 'The app\'s language ($language)';
  }

  @override
  String get detectLanguageOption => 'Detect automatically (Whisper only)';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'Automatic (the system\'s)';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';
}
