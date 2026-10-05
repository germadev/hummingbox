// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Recorder';

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
  String importedFromFolder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings added from the folder',
      one: '1 recording added from the folder',
    );
    return '$_temp0';
  }

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
  String get savingCopies => 'Saving copies…';

  @override
  String get copiesFailed => 'Some copies couldn\'t be saved';

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
  String get importTitle => 'Add the folder\'s recordings?';

  @override
  String importMessage(String folder, int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio files',
      one: '1 audio file',
    );
    return '“$folder” has $_temp0 ($size) that aren\'t in the app. If you add them, they\'ll appear in the list and be copied into the app.';
  }

  @override
  String get add => 'Add';

  @override
  String get dontAdd => 'Don\'t add';

  @override
  String get folderFailed => 'Couldn\'t use that folder';

  @override
  String get copiesKept => 'The copies already in the folder are kept';

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
  String get recordingSection => 'Recording';

  @override
  String get formatNote =>
      'Applies to new recordings. When editing, each recording keeps its format.';

  @override
  String get storageSection => 'Where recordings are saved';

  @override
  String get storageDescription =>
      'Recordings are always saved inside the app. You can also keep a copy of each one in a device folder and in Google Drive, with the name you gave it and in its subfolder. Copies are updated when you rename or edit a recording, but aren\'t deleted when you delete it.';

  @override
  String get deviceFolder => 'Device folder';

  @override
  String get noFolder => 'Not saved to any folder';

  @override
  String get stopSavingToFolder => 'Stop saving to the folder';

  @override
  String get chooseAnotherFolder => 'Choose another folder';

  @override
  String get showFolderRecordings => 'Show the folder\'s recordings';

  @override
  String get showFolderRecordingsSubtitle =>
      'Adds the audio files (.m4a and .wav) in the folder and its subfolders to the app';

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
  String get copyNow => 'Copy now';

  @override
  String get copyNowSubtitle => 'Only what\'s missing or changed is copied';

  @override
  String copyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn\'t copy $count recordings',
      one: 'Couldn\'t copy 1 recording',
    );
    return '$_temp0';
  }

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn\'t add $count recordings from the folder',
      one: 'Couldn\'t add 1 recording from the folder',
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
}
