# Transcription

## Automatic transcription

*Settings → Transcription → Transcribe automatically* (on by default):
recordings without a transcript are transcribed in the background, one at a
time, from the newest to the oldest, without showing their progress (it is
shown for the one that is playing). New recordings are transcribed when they
are saved, and so are those that appear in the destination, edited copies and
recordings whose audio is edited.

- It starts after the destination has been read, so existing `.txt` files are
  picked up first instead of being transcribed again.
- While recording it waits: the transcription in progress stops and starts
  again when the recording is saved.
- With Google Drive as the destination, only recordings whose audio is on the
  phone are transcribed (made in the app, or already played or shared);
  nothing is downloaded just to transcribe it.
- It does not retry a recording in which no words were recognized or whose
  transcript was deleted (in the app or by deleting its `.txt` file), until
  its audio changes. If one fails or its transcription is cancelled, it is
  retried the next time the app starts.
- If transcription cannot work at all (the system recognizer is not
  available, the language is not supported or not downloaded, a permission is
  missing, Whisper is not installed), automatic transcription stops and the
  app says so once, with *View* to see why and how to fix it. It tries again
  when the transcription settings change, after leaving Settings and when
  returning to the app.
- Choosing *Transcribe* in a recording's menu moves it ahead of the automatic
  ones and shows its progress.

## Engines

*Settings → Transcription → Transcribe with*:

- **System speech recognition** (default): nothing to download.
  - **Android 13 or later**, with the on-device recognizer
    (`SpeechRecognizer.createOnDeviceSpeechRecognizer`): the audio is fed
    through a pipe instead of the microphone (`EXTRA_AUDIO_SOURCE`), in a
    segmented session so long recordings work, with capitalization and
    punctuation. If the language is not downloaded, the app offers to
    download it (the system shows its own prompt). On Android 12 or earlier,
    or without an on-device recognizer, the app suggests installing Whisper.
  - **iOS**: `SFSpeechRecognizer` with the file, on the device if the
    language supports it. Otherwise Apple recognizes it on its servers (this
    needs a connection and the audio leaves the phone), with a one-minute
    limit per request, so the app splits it into 55 s chunks.
- **Whisper**, with [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
  (the `whisper_cpp_flutter_plus` package): on the device and offline. A
  model has to be downloaded once from Settings: **Tiny** (78 MB, faster) or
  **Base** (148 MB, more accurate). They are downloaded from Hugging Face at
  a pinned revision and their SHA-256 checksum is verified; the Silero voice
  activity detector (under 1 MB) is downloaded with the model so Whisper does
  not make up text during silences. The download can be cancelled (it
  resumes where it stopped) and the model can be deleted.

*Language*: the app's language (default), one of the app's eight languages
or, with Whisper only, automatic detection.

### A recording's language

Each recording can have its own language: *Transcribe in another language*,
in the recording's menu or in its transcript's menu, asks for it (*As in
Settings*, automatic detection with Whisper, or one of the eight languages)
and transcribes the recording again in it. The choice is kept with the
recording, so *Transcribe again* and automatic transcription (for example
after editing the audio) use it too. *As in Settings* goes back to the
language chosen in Settings.

If the system recognizer does not support a recording's own language, or it
is not downloaded, automatic transcription only skips that recording; the
others go on.

## How it works

Before transcribing, the audio is converted to 16 kHz mono (what the
recognizers use), in blocks and in a separate isolate. Long recordings are
split at the silence closest to the limit: with Whisper, into chunks of at
most 10 minutes, so no more than about 40 MB of samples are held in memory.
One recording is transcribed at a time; when it was requested from the
menu (or it is the one playing), the card shows the progress and the
transcription can be cancelled. With Google Drive as the destination,
transcribing from the menu downloads the audio (as playing it does).

The text is stored in the app's index together with the engine, the language
and the audio revision: if the recording is edited or changed afterwards, the
transcript warns that it may no longer match.

## `.txt` files

The transcript is also saved as a text file (UTF-8) next to the audio, with
the same name (`Classes/Lesson 1.txt` next to `Classes/Lesson 1.m4a`), in the
device folder or in Drive (and in the Drive copy, if there is one). It is
kept in sync both ways:

- Transcribing again overwrites it, renaming the recording renames it, and
  deleting the transcript or the recording deletes it.
- If the `.txt` file is **edited outside the app** (with any editor), the app
  picks up the new text; if it is deleted outside the app, the transcript
  disappears from the app. Changes are detected like audio changes (size and
  MD5 checksum).
- Existing `.txt` files next to an audio file are read as its transcript:
  after **reinstalling the app** or from another device, transcripts come
  back. With Drive, that means downloading those `.txt` files (they are
  small).
- If the text changed in the app before being saved and also outside it, the
  most recent change wins. A `.txt` file without an audio file of the same
  name is ignored.
