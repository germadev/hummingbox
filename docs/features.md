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

- Sorted from oldest to newest: new recordings appear at the bottom, and the
  list scrolls to the end when the app opens and when one is added.
- Each one shows the date ("Today", "Yesterday"…), duration, **format and
  quality** ("AAC · 128 kbps · 44.1 kHz") and the **full waveform**. **Tap the name** to rename it.
- **Names**: a new recording is called after its date and time
  (`2026-10-05 14.32`) and, when it is transcribed for the first time, after
  its date and the first words of the transcript
  (`2026-10-05.Hello, how are you`, up to 40 characters, without characters
  that aren't allowed in file names). Recordings with no words keep the date
  and time. If the name is already taken in the same folder, a number is
  added (`… (2)`). Its file in the folder or in Drive is renamed with it.
  Recordings you have renamed are never renamed automatically. When you
  transcribe one again or in another language, the app asks whether to rename
  it after the new transcript.
- **Built-in player**: the waveform is the progress bar; tap or drag it to
  seek (also on recordings that are not playing).
- **Loop and playlist**: while a recording plays (or is paused), the bottom
  panel shows a button to stop it in the middle, *Play one after another* on
  the left (when it ends, the next one in the list plays) and *Repeat* on the
  right (it starts again; with *Play one after another*, the whole list
  repeats). Both stay on until you turn them off, while the app is open.
- **Rename**, **share** (with the name you gave it) and **delete**.

## Folders

The folder button (top left), or swiping right anywhere on the list, opens a
menu with the main folder and its **subfolders**, the number of recordings in
each one and *New folder*. Dragging on a recording's waveform still seeks.
In a subfolder its name is shown in the top bar, next to the folder button
(the main folder has no title), the list shows its recordings and **new recordings go there**.

## Back button

Back goes from the most specific to the most general: it closes the piano;
it removes the focus from the search field and then the selection of a
recording; it closes the search; in a subfolder it returns to the main
folder, and in the main folder it opens the folders menu. With that menu
open in the main folder, Back leaves the app. While recording it doesn't
leave.

## Piano

The piano button (top bar), or swiping left anywhere on the list, opens a
piano across the whole screen to find the notes of what you hummed. It is
always shown in **landscape**: the screen rotates when it opens and goes back
to the system's orientation when it closes.

- The keyboard shows an octave and a half (11 white keys), starting at C3.
  Play several keys at once or slide your finger across them. Each key shows
  its note (solfège or letters, depending on the language) and the last one
  played is shown at the top with its frequency.
- Below it, all 88 keys (A0 to C8) are shown small across the whole width,
  with the enlarged part highlighted. Tap or swipe on them to move it. The
  position is kept when the piano is closed.
- The sound is synthesized in the app (no samples). The piano can't be
  opened while recording from the main screen.

### Recording from the piano

At the top of the piano choose what to record, **piano only** or **piano and
voice**, and press *Record*; the button shows the time and stops the
recording. Closing the piano (or Back) while recording stops and saves it.
The recording goes to the open folder, like any other.

- The app keeps when each key was pressed and released, so the recording
  keeps the rhythm you played.
- **Piano only**: no microphone. When you stop, the audio is generated from
  the notes (in the format and quality of the settings) and lasts until the
  last note fades out. If no key was played, nothing is saved.
- **Piano and voice**: the microphone records as usual and, when you stop,
  the notes are mixed on top, timed with the recorder so they match the
  voice. With headphones the piano isn't picked up by the microphone; with
  the speaker it is also heard faintly in the voice.
- In the list, the notes are drawn like in a MIDI editor (piano roll): each
  one at the height of its key, from when it was pressed until it was
  released, over the voice's waveform (or alone, for piano only), on the
  same timeline. They work as the progress bar too.
- Trimming in the editor keeps the notes in place. Piano-only recordings
  aren't transcribed.

## Search

The magnifier (in the middle of the top bar), or **pulling the list down**
when it is already at the top, opens a search field that spans the top bar,
from the folder button to ⚙, with the magnifier on the left and an X on the
right. While pulling, the list moves down, a light grey circle appears behind
the bar's magnifier and "Pull to search" shows in the gap above the list;
past a certain point the circle turns purple, the text changes to "Release
to search" and the phone gives a short vibration, and **releasing** there
opens the search (going back up before releasing cancels it). If the search
field already has the focus, pulling shows the keyboard again (for example
after hiding it with Back on Android). Tapping the list's background (outside
the recordings) takes the focus away from the field and hides the keyboard
(with nothing typed, the search closes), and deselects the recording unless
it is playing.

It searches **names and transcripts** in every folder, ignoring case and
accents ("reunion" finds "Reunión"), and each word can match either of them.
It also finds **similar words** (it can be turned off in Settings → Search):
with a typo or a different ending, "reunon" or "reuniones" find "reunión" —
one change for words of 4 to 6 letters, two for longer ones (a letter more,
less or different, or two letters swapped), and up to 3 extra letters at the
end. Words of 3 letters or less, words with digits and Chinese or Japanese
text are only searched as typed. Recordings that have the words as typed come
first. Results highlight what was found (similar words too), show the part
of the transcript where it appears and each recording's subfolder. The X
closes the search; Back first removes the focus from the field and then
closes it.

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
→ *Transcribe*, and in **another language** (*Transcribe in another
language*: each recording keeps the language chosen for it). A recording's
card shows its transcript **while it is playing** (or paused) or when it
**matches the search**; tapping it, or *View transcript* in the menu, opens
the whole text to read, copy, share, transcribe again (also in another
language) or delete it. The text is also saved as a `.txt` file next
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
- **Search**: include similar words (on by default).
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
