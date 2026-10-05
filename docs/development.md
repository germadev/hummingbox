# Development

## Requirements

- Flutter 3.47 or later (Dart 3.13).
- Android 7.0 (API 24) or later.
- iOS 15 or later.

## Running and building

```bash
flutter pub get
flutter run                   # on a connected device or emulator
flutter build apk --release   # Android
flutter build ipa             # iOS (needs macOS and Xcode)
```

Without a signing key, the `release` APK is signed with the debug key (see
[APK signing](releases.md#apk-signing)). Google Drive needs client IDs
passed with `--dart-define` (see [Google Drive setup](google-drive.md)).

## Tests

```bash
flutter analyze
flutter test
```

There are unit tests for audio processing (WAV, trimming, volume, fades,
peaks, 16 kHz conversion and chunking), WAV and MP4 header parsing, the voice
detector, the editor, storage and the cache, syncing with a folder and with
Drive (as destination and as copy, including change detection by MD5
checksum and `.txt` transcripts; the Drive API is tested with a fake HTTP
client), transcription (with fake recognizers), the controllers (including
the countdown and voice start with its trimming), search, formats and
automatic recording names, the piano's notes, synthesized sound and mixing
with the voice,
translations, and widget tests of the main flows (first run, recording,
opening the panel without recording, countdown, voice start, seeking on the
waveform, editing and previewing with the volume, the folders menu, search
(including pulling the list down), keeping the screen on, transcribing (also
automatically, in the background) and reading the transcript, settings,
downloading Whisper, theme, renaming (also after transcribing again), the
piano (playing, sliding across keys, moving along the keyboard and landscape),
the list order, deleting and language). Widget tests
run in Spanish.

Audio services, storage, the folder and Drive are behind interfaces, so
tests use fakes and do not need a device.

## Project structure

```
lib/
├── main.dart                     Entry point
├── app.dart                      MaterialApp, theme and localization
├── l10n/                         Translations (app_xx.arb) and generated code
├── models/
│   ├── recording.dart            Recording (name, duration, waveform, files in the destination…)
│   ├── recording_options.dart    Recording format and quality
│   └── transcription.dart        Transcript, engine, Whisper models and settings
├── audio/
│   ├── levels.dart               Waveform levels (dBFS → 0–1) and resampling
│   ├── wav.dart                  Block-wise WAV reading and writing
│   ├── audio_edit.dart           Trimming, volume, fades and peaks
│   ├── audio_info.dart           Format and duration of an .m4a or .wav file
│   ├── speech_audio.dart         16 kHz mono audio and splitting at silences
│   └── voice_detector.dart       Voice detection from the microphone level
├── controllers/
│   ├── recorder_controller.dart  Recording state (timer, waveform…)
│   ├── player_controller.dart    Playback state
│   ├── transcription_controller.dart  Transcription queue, progress and cancelling
│   └── whisper_controller.dart   Whisper model download
├── services/
│   ├── audio_recorder_service.dart  Microphone (`record` package)
│   ├── audio_player_service.dart    Playback (`audioplayers` package)
│   ├── audio_codec.dart             m4a ↔ WAV and m4a trimming (system codecs)
│   ├── recording_editor.dart        Editing and waveforms (in an isolate)
│   ├── recordings_repository.dart   Recordings index and pending audio
│   ├── settings_store.dart          App settings
│   ├── folder_access.dart           User-chosen folder
│   ├── google_drive.dart            Google Sign-In and the Drive REST API
│   ├── storage_sync.dart            Saving to and reading from the destination, Drive copy
│   ├── audio_cache.dart             Cache of audio read from the destination
│   ├── transcriber.dart             Transcribing: preparing, splitting and recognizing audio
│   ├── speech_recognition.dart      System speech recognition
│   ├── whisper_service.dart         Whisper models and whisper.cpp
│   ├── screen_awake.dart            Keeping the screen on
│   └── share_service.dart           Sharing (`share_plus` package)
├── screens/                      Home, first run, editor, transcript and settings
├── widgets/                      Record panel, waveforms, list, folders menu, piano and dialogs
└── utils/                        Duration and date formats, files, languages and search

packages/voicerecorder_native/    The app's own plugin with the native code
├── android/…/AudioCodecHandler.kt   MediaExtractor + MediaCodec + MediaMuxer
├── android/…/FolderAccess.kt        Storage Access Framework (read, write, rename, delete)
├── android/…/SpeechTranscriber.kt   SpeechRecognizer with a file (Android 13+)
├── android/…/ScreenAwake.kt         FLAG_KEEP_SCREEN_ON
├── ios/…/AudioCodecHandler.swift    AVAudioFile + AVAssetExportSession
├── ios/…/FolderAccessHandler.swift  UIDocumentPicker + security-scoped bookmarks
└── ios/…/SpeechHandler.swift        SFSpeechRecognizer with a file

tool/icons.cjs                    Renders the app icons from docs/icon.svg
```

Code comments, test names and commit messages are in Spanish.

### Editing pipeline

The `.m4a` file is decoded to WAV with the system codec (a 16-bit WAV is
used as is); trimming, volume and fades are applied in Dart (block by block
and in a separate isolate, so the whole audio is never loaded into memory and
the UI does not block) and the result is re-encoded to AAC at the original's
bit rate (or saved as WAV). The preview uses the same processing on the
selection. While editing, the audio takes about 5 MB per minute in the
temporary folder.

## Permissions

- **Android**: `RECORD_AUDIO` and `INTERNET` (for Google Drive), declared in
  `android/app/src/main/AndroidManifest.xml`. The recordings folder needs no
  storage permission: the user picks it with the system picker. The plugin
  also declares a query (`<queries>`) for the
  `android.speech.RecognitionService` service, to find the speech
  recognizer.
- **iOS**: `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` (to transcribe with the system
  recognizer), in `ios/Runner/Info.plist`.

The microphone permission is requested the first time the record button is
pressed, and the speech recognition permission on iOS the first time it is
used to transcribe. If they are denied, the app explains that they have to be
enabled in the system settings.

## Localization

Texts are in `lib/l10n/app_xx.arb`; `app_en.arb` is the template (with a
description of each text) and English is the fallback language. The code in
`lib/l10n/app_localizations*.dart` is generated by `flutter gen-l10n` (also
by `flutter pub get`, `run`, `build` and `test`, thanks to `generate: true`):
after changing an ARB file, regenerate it and commit it.

The app name, HummingBox, is a brand and is not translated: it is `appTitle`
in the ARB files, `app_name` in `android/app/src/main/res/values/strings.xml`
and `CFBundleDisplayName` in `ios/Runner/Info.plist`.

To add a language: copy `app_en.arb` to `app_xx.arb`, translate it (without
the `@…` entries), run `flutter gen-l10n` and also add:

- Android: the language in `android/app/src/main/res/xml/locales_config.xml`.
- iOS: `ios/Runner/xx.lproj/InfoPlist.strings` (permission prompts), added
  to the `InfoPlist.strings` group of the Xcode project, and the language in
  `CFBundleLocalizations` in `Info.plist`.

`test/l10n_test.dart` checks that every ARB file has the same texts and
placeholders.

## App icon

The source is [`docs/icon.svg`](icon.svg) (1024 × 1024): the `#tile`
(rounded purple gradient) and the `#artwork` (microphone, notes, waves and
dots). `tool/icons.cjs` renders every PNG from it with Chromium:

- **Android 8+**: adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`) with
  the gradient as background (`drawable/ic_launcher_background.xml`), the
  artwork as foreground (`mipmap-*/ic_launcher_foreground.png`, scaled to fit
  the 66 dp safe zone of the 108 dp layer, so any launcher shape works) and a
  white silhouette for Android 13+ themed icons
  (`mipmap-*/ic_launcher_monochrome.png`).
- **Android 7**: `mipmap-*/ic_launcher.png`, the rounded tile.
- **iOS**: the `AppIcon.appiconset` PNGs, square and without an alpha channel
  (iOS rounds the corners).

After changing the SVG, regenerate the PNGs (Node 22 or later and Playwright
with Chromium are needed):

```bash
npm install -g playwright && npx playwright install chromium
NODE_PATH="$(npm root -g)" node tool/icons.cjs
```

If the tile's colours change, update the gradient in
`drawable/ic_launcher_background.xml` and `brandPurple` in `lib/app.dart`.
