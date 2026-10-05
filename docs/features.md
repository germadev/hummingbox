# Features

## First run

When the app is installed you choose where recordings are stored: a
**folder on the device** or **Google Drive** (see [Storage](storage.md)).
Recording is disabled until you pick one, and the choice comes back if you
later stop using that destination.

## Recording

- **One tap** to record, with **pause/resume** and a timer.
- **Live waveform** with the microphone level. Only the part from the moment
  the recording starts is coloured; while paused, the recorded part is
  dimmed.
- **Discard** a recording in progress (with confirmation).
- **Keep the screen on** while recording (or waiting to start), so the
  system does not stop the app when the screen turns off. It can be turned
  off in *Settings → Recording*.
- **Slide-up panel**: sliding the record button's panel up shows the timer
  and the waveform (in grey) **without recording**; recording starts when
  you press the button. Sliding it down folds it again. When it is open,
  next to the button:
  - ⏱ **Countdown** (left): starts recording after 3, 5 or 10 s
    (*Settings → Recording → Countdown*), vibrating every second.
  - 🗣 **Start on voice** (right): starts recording when you speak and keeps
    the **second before**, so the start is not cut off.

  While waiting, the X cancels and the red button starts right away.

### Format and quality

*Settings → Recording*:

| Quality | Sample rate | AAC (`.m4a`)         | WAV (16-bit) |
|---------|-------------|----------------------|--------------|
| Low     | 16 kHz      | 32 kbps · 0.2 MB/min | 1.9 MB/min   |
| Medium  | 22.05 kHz   | 64 kbps · 0.5 MB/min | 2.6 MB/min   |
| High    | 44.1 kHz    | 128 kbps · 1 MB/min  | 5.3 MB/min   |

Always mono. The default is high-quality AAC. If the microphone or the codec
does not support those exact values, `record` uses the closest ones; the list
shows the real values, read from the file header.

The setting only affects new recordings. When editing, each recording keeps
its format: a WAV is saved as WAV and an AAC file is re-encoded at its own
bit rate.

### Start on voice

When 🗣 is pressed the microphone starts recording without showing it, so
the audio from before you speak is available. Voice is detected from the
microphone level: when it is 12 dB above the background noise (estimated on
the fly) and at least −45 dBFS for 200 ms. When the recording stops, the
beginning is trimmed, leaving 1 s before the voice: an `.m4a` file is trimmed
without re-encoding (`MediaMuxer` on Android, `AVAssetExportSession` on iOS)
and a WAV file in Dart. If trimming fails, the whole recording is kept.

## Recordings list

- Sorted from newest to oldest, with the date ("Today", "Yesterday"…),
  duration, **format and quality** ("AAC · 128 kbps · 44.1 kHz") and the
  **full waveform** of each one. **Tap the name** to rename it.
- **Built-in player**: the waveform is the progress bar; tap or drag it to
  seek (also on recordings that are not playing).
- **Rename**, **share** (with the name you gave it) and **delete**.

## Folders

The folder button (top left), or swiping right anywhere on the list, opens a
menu with the main folder and its **subfolders**, the number of recordings in
each one and *New folder*. Dragging on a recording's waveform still seeks.
In a subfolder its name is shown in the top bar, next to the folder button
(the main folder has no title), the list shows its recordings and **new recordings go there**. Back
returns to the main folder.

## Search

The magnifier (in the middle of the top bar), or **pulling the list down**
when it is already at the top, opens a search field that spans the top bar,
from the folder button to ⚙, with the magnifier on the left and an X on the
right. While pulling, the list moves down and the bar's magnifier comes down
with it, inside a circle; past a certain point the circle changes colour and
the phone gives a short vibration, and **releasing** there opens the search
(going back up before releasing cancels it). If the search field already has
the focus, pulling shows the keyboard again (for example after hiding it with
Back on Android).

It searches **names and transcripts** in every folder, ignoring case and
accents ("reunion" finds "Reunión"), and each word can match either of them.
Results highlight what was found, show the part of the transcript where it
appears and each recording's subfolder. The X or Back closes the search.

## Editing

From a recording's menu → *Edit*:

- **Trim** with two handles on the waveform.
- **Raise or lower the volume** (−20 to +20 dB) and **normalize** (brings the
  selection's peak to −1 dBFS). It warns if the chosen volume clips.
- **Fade in and fade out** (up to 5 s).
- Listen to the selection before saving, **with the volume and fades
  applied**.
- **Save** (replaces the original) or **Save copy** (creates a new recording,
  "… (edited)", and leaves the original untouched).

## Transcription

Recordings are **transcribed automatically in the background** (it can be
turned off in Settings), with the system speech recognizer or with
**Whisper** on the device; a recording can also be transcribed from its menu
→ *Transcribe*. A recording's card shows its transcript **while it is
playing** (or paused) or when it **matches the search**; tapping it, or
*View transcript* in the menu, opens the whole text to read, copy, share,
transcribe again or delete it. The text is also saved as a `.txt` file next
to the audio. See [Transcription](transcription.md).

## Settings

The ⚙ button (top right):

- **Recording**: format, quality, countdown length and keeping the screen on.
- **Device folder**: where recordings are stored (internal storage, SD card,
  iCloud Drive…). The app shows every audio file in it and in its
  subfolders.
- **Google Drive**: with a device folder, it also keeps a copy of each
  recording in the app's folder in your Drive ("HummingBox"); without one,
  recordings are stored in Drive. It needs some setup first (see
  [Google Drive setup](google-drive.md)).
- **Transcription**: automatic transcription, engine, Whisper model
  (download or delete it) and language.
- **Appearance**: theme — system (default), light or dark — with the icon's
  colours (purple `#5C2BD6` and, for recording, red `#FF4D4D`).

## Languages

English, Spanish, Italian, Portuguese, French, German, Chinese and Japanese.
The app follows the system language and falls back to English. To add a
language, see [Development](development.md#localization).

## Known limitations

- Recording is meant to happen with the app in the foreground (that is why
  the screen is kept on). Recording with the screen off would need a
  foreground service on Android and the background audio mode on iOS.
- Voice detection only uses the microphone level: a loud noise (a knock, a
  door) can also start the recording.
- Only `.m4a` (AAC) and `.wav` files are shown, and only from the folder and
  the first level of subfolders. In a device folder, a change that keeps the
  same size is only detected if the modification date changes (almost every
  system updates it when writing).
- With Google Drive as the destination, the waveform and duration of files
  added from Drive are not shown until they are played for the first time.
- Transcription: the system recognizer needs Android 13 or later; on iOS,
  languages that are not supported on the device are recognized on Apple's
  servers. Whisper is slower with long recordings and on older phones (Base
  more than Tiny) and does not run on x86 emulators. A transcript's `.txt`
  file is matched to the audio by name: if the system adds a suffix when
  creating the audio file ("Idea (1).m4a" because there was already one),
  the `.txt` file is named after the recording, not the file.
- Recordings cannot be moved to another subfolder from the app.
- Saving to and reading from the destination happens while the app is open;
  there is no background upload.
