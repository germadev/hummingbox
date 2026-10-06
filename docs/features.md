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

  With a recording selected, sliding the panel up shows that recording's
  menu as icon buttons (edit, add piano, rename, move to folder, transcribe
  or view the transcript, share and delete; press and
  hold one to see its name) instead of the timer, and without the countdown
  and start-on-voice buttons.

### Format and quality

*Settings → Recording*:

| Quality   | Sample rate | AAC (`.m4a`)          | WAV (16-bit) |
|-----------|-------------|-----------------------|--------------|
| Minimum   | 8 kHz       | 16 kbps · 0.1 MB/min  | 1 MB/min     |
| Low       | 16 kHz      | 32 kbps · 0.2 MB/min  | 1.9 MB/min   |
| Medium    | 22.05 kHz   | 64 kbps · 0.5 MB/min  | 2.6 MB/min   |
| High      | 44.1 kHz    | 128 kbps · 1 MB/min   | 5.3 MB/min   |
| Very high | 48 kHz      | 192 kbps · 1.4 MB/min | 5.8 MB/min   |
| Maximum   | 48 kHz      | 256 kbps · 1.9 MB/min | 5.8 MB/min   |

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
  list scrolls to the end when the app opens and when one is added. A
  recording you have just made (with the microphone, the piano or as an
  edited copy) is shown selected, with its transcript, without playing;
  its play button plays it from the start. There is room below the last one for the
  message saying it was saved, so the message doesn't cover it.
- In the compact list, recordings with piano notes (and their `.mid`) show a
  small **piano** on the left edge of their play button, since the notes are
  only drawn when the recording is selected.
- While a recording plays (or is paused), a thin vertical line on its
  waveform marks where it is.
- **Compact or detailed view**: the list is compact by default (one line
  with the date and duration, and the waveform only on the selected
  recording). The button to the left of Settings switches it to the detailed
  view and back. The choice is remembered.
- Each one shows the date ("Today", "Yesterday"…), duration, **format and
  quality** ("AAC · 128 kbps · 44.1 kHz") and the **full waveform**
  (none if it has no audible sound, such as piano-only or silent
  recordings). **Tap the name** to rename it. The name is shown without the
  date at its start (`2026-10-05.Hello` shows as `Hello`), since the date is
  right below it.
- **Tap a recording to select it**, without playing it: it is highlighted,
  with its transcript. It plays only with its **play button** (or the one in
  the bottom panel). Selecting another one stops the one playing. If the
  selected recording is cut off at the bottom or the top of the list (for
  example because it grows with its waveform), the list scrolls just enough
  to show it whole.
- **Names**: a new recording is called after its date and time
  (`2026-10-05 14.32`) and, when it is transcribed for the first time, after
  its date and the first words of the transcript
  (`2026-10-05.Hello, how are you`, up to 100 characters, without characters
  that aren't allowed in file names). Recordings with no words keep the date
  and time. If the name is already taken in the same folder, a number is
  added (`… (2)`). Its file in the folder or in Drive is renamed with it.
  Recordings you have renamed are never renamed automatically. When you
  transcribe one again or in another language, the app asks whether to rename
  it after the new transcript.
- **Built-in player**: the waveform is the progress bar; tap or drag it to
  seek. On a recording that isn't selected, it selects it at that point
  without playing it. While it plays, the line that marks where it is moves
  at a steady pace every frame: the player's positions arrive late and in
  steps (on Android, sometimes slightly backwards), so the line follows the
  clock and is nudged towards them, and it never goes back except when you
  seek.
- **Loop and playlist**: while a recording is selected, the bottom panel
  shows, in place of the record button, a button to stop it while it plays
  or to play it (or resume it) otherwise, *Play one after another* on
  the left (when it ends, the next one in the list plays) and *Repeat* on the
  right (it starts again; with *Play one after another*, the whole list
  repeats). Both stay on until you turn them off, while the app is open.
  Stopping it keeps it selected, ready to play again from the beginning;
  tapping outside the recordings deselects it and brings back the record
  button.
- **Rename**, **move to folder**, **share** (with the name you gave it) and
  **delete**.

## Folders

The folder button (top left), or swiping right anywhere on the list (not
from the left or right edge, where the system's Back gesture is), opens a
menu with the main folder and its **subfolders**, the number of recordings in
each one and *New folder*. Dragging on a recording's waveform still seeks.
In a subfolder its name is shown in the top bar, at the right of the search
field (the main folder has no title), the list shows its recordings and **new recordings go there**.

*Move to folder* in a recording's menu asks where it goes: the main folder,
one of the subfolders (the one it is in can't be picked) or a *New folder*.
It leaves the open folder (if it was playing, it stops) and its audio,
transcript (`.txt`) and piano notes (`.mid`) are moved to the new subfolder
in the destination, and in the Drive copy. If a recording there already has
its name, a number is added (`Interview (2)`). In Drive the files keep
their id (only their folder changes); in a device folder they are copied to
the new subfolder and then removed from the previous one. If moving is
interrupted (no connection, the app closes), it finishes on the next sync.

## Back button

Back goes from the most specific to the most general: it closes the piano;
it removes the focus from the search field (with the keyboard showing, a
single Back hides it and removes the focus) and then the selection of a
recording; it clears the search; and it opens the folders menu (in a
subfolder too, without going to the main folder). With that menu open,
Back leaves the app, also with the gesture from the right edge: touches
starting next to that edge, where the gesture is, don't reach the app (they
would close the menu, and the Back that follows would open it again).
Tapping outside the menu, away from that edge, still closes it. While
recording it doesn't leave.

## Piano

The piano button (at the bottom of the folders menu), or swiping left
anywhere on the list (not from the left or right edge, where the system's
Back gesture is), opens a piano across the whole screen to find the notes of what
you hummed. Swiping on it doesn't close it, so you can slide your finger
across all the keys: close it with its button (or Back). It is always laid
out in **landscape**, and the screen rotates as usual while it is open:

- With the phone in **portrait**, the piano is drawn sideways, already while
  it slides in. The button next to the close button turns it around if it
  shows upside down (it is remembered).
- With the phone in **landscape**, it is drawn normally.
- The keys' sounds are loaded when the piano opens, so a key sounds as soon
  as it is touched. All the notes are mixed by the app's own native code and
  come out as a single audio stream, so there are no clicks: playing a key
  again fades its previous note out in 10 ms instead of cutting it, the
  organ and the synthesizer fade out sample by sample when the key is
  released, and when several notes sound together (chords, fast notes) the
  volume of all of them is lowered smoothly, just enough for their sum not
  to clip, and comes back as they fade. A single note keeps its full volume.
  Changing the instrument doesn't make any key sound by itself.

The keyboard:

- It shows an octave and a half (11 white keys), starting at C3. Play
  several keys at once or slide your finger across them. Each key shows its
  note (solfège or letters, depending on the language) and the last one
  played is shown at the top with its frequency.
- Below it, all 88 keys (A0 to C8) are shown small across the whole width,
  with the enlarged part highlighted. Tap or swipe on them to move it,
  smoothly (the keys at the edges can be cut). **Pinch** on them to see more
  or fewer keys (from 5 to 29 white keys). The position and size are kept
  when the piano is closed.
- The piano can't be opened while recording from the main screen.

### Instruments and synthesizer

The name at the top left is the instrument: **piano**, **organ**,
**guitar**, **marimba** or **synthesizer**. All of them are synthesized in
the app (no samples): they give the note with a timbre that recalls the
instrument. The piano, guitar and marimba fade out on their own; the organ
and the synthesizer sound while the key is held and fade out when it is
released. The choice is remembered.

With the **synthesizer**, a panel in the style of a hardware groovebox is
shown above the keys (on the right of the screen with the phone in
portrait, drawn sideways like the piano): a screen, four keys with a LED
and two knobs, **X** (orange) and **Y** (black). Each key picks the pair
of parameters the knobs change, shown on the screen: **wave** (sawtooth,
square, triangle or sine) and **detune** between its two oscillators;
**attack** and **decay**; **sustain** and **release**; the filter's
**brightness** and **resonance**. Turn a knob by dragging up or right (more)
and down or left (less). While it's turned only the screen changes; the
keys sound with it when it's released. The dark key goes back to the
default sound.
The sound is remembered, and each recorded note keeps the sound it had when
it was played.

### Recording from the piano

At the top of the piano choose what to record: the piano button is always
selected (what you play is always recorded) and the microphone button adds
your **voice**. Then press *Record*; the button shows the time and stops the
recording. Closing the piano (or Back) while recording stops and saves it.
The recording goes to the open folder, like any other.

- The app keeps when each key was pressed and released, and with which
  instrument, so the recording keeps the rhythm you played. You can change
  the instrument while recording.
- **Piano only**: no microphone and **no audio file**: the recording is just
  the notes, saved as a `.mid` (`Idea.mid`), and lasts until the last note
  fades out. Its sound is generated from the notes when you play, share
  (as WAV) or edit it, and isn't stored. As when playing the piano, a key
  sounds once at a time (playing it again cuts the previous note), and when
  many notes sound together the volume is lowered smoothly instead of
  clipping, so it sounds clean (the same when the notes are mixed with the
  voice). Its format shows as *MIDI*. If no
  key was played, nothing is saved.
- **Piano and voice**: the microphone records as usual and, when you stop,
  the notes are mixed on top, timed with the recorder so they match the
  voice. With headphones the piano isn't picked up by the microphone; with
  the speaker it is also heard faintly in the voice.
- In the list, the notes are drawn like in a MIDI editor (piano roll): each
  one at the height of its key, from when it was pressed until it was
  released, over the voice's waveform (or alone, for piano only), on the
  same timeline. They work as the progress bar too.
- Trimming in the editor keeps the notes in place. Piano-only recordings
  aren't transcribed, and in the editor they can only be trimmed (there is
  no audio to change the volume of or fade).
- **Adding piano to a recording**: *Add piano* in a recording's menu opens
  the piano over it (the top shows which one). *Record* plays it from the
  beginning and records what you play in time with it; it stops when the
  recording ends, with the stop button or when closing the piano. The notes
  are mixed into its audio (on a piano-only recording, only added to its
  `.mid`) and added to the ones it already had, so you can add several
  layers. While accompanying, *Play one after another* and
  *Repeat* don't move on.
- The notes are also saved as a standard **MIDI file** (`.mid`) next to the
  audio (each instrument on its own channel, with its General MIDI program;
  reading a `.mid`, each channel gets the closest instrument), with the same name (`Idea.m4a` and `Idea.mid`), in the folder and
  in Drive. It is renamed and deleted with the recording. A `.mid` found next
  to an audio file (for example after reinstalling the app, or edited in
  another app) is read; if it is deleted outside the app, the notes are
  removed. A `.mid` with no audio file of the same name next to it is a
  piano-only recording: it shows up in the list like any other.

## Search

The **search field is always in the top bar**, next to the folders button,
with a magnifier at its left and "Search" as placeholder, dimmer while the
field doesn't have the focus (in a subfolder, its name at the right).
Tapping it, or **pulling the list down**
when it is already at the top (a drag that scrolls up to the top and keeps
pulling doesn't count), gives it the focus: it then spans the top bar,
from the folder button to ⚙, with an X where the view button was (and the
folder name). While pulling, the list moves down, a light grey circle appears behind
the bar's magnifier and "Pull to search" shows in the gap above the list;
past a certain point the circle turns purple, the text changes to "Release
to search" and the phone gives a short vibration, and **releasing** there
focuses the search: the circle disappears at once, without following the list
back up (going back up before releasing cancels it). If the search
field already has the focus, pulling shows the keyboard again (for example
a floating one hidden with Back on Android). Hiding the keyboard (with Back
on Android) also takes the focus away from the field. Tapping the list's
background (outside the recordings) takes the focus away from the field and hides the keyboard
(with nothing typed, the buttons come back), and deselects the recording unless
it is playing. Tapping the bottom panel outside its buttons works like the
list's background. Tapping anywhere else, such as on a recording to select it
or on the bottom panel, takes the focus away from the field too, when the
finger is lifted: the system's Back gesture from the edge, which starts as a
touch in the app, doesn't, so that Back takes the focus away instead of
opening the folders menu.

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
clears the search and removes the focus; Back first removes the focus from
the field and then clears it.

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
→ *Transcribe*. A recording's
card shows its transcript **while it is playing** (or paused) or when it
**matches the search**; tapping it, or *View transcript* in the menu, opens
the whole text to read, copy, share, transcribe again or delete it. Its
language is shown on a button at the top: tapping it transcribes the
recording in **another language** (each recording keeps the language chosen
for it). The text is also saved as a `.txt` file next
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
- Saving to and reading from the destination happens while the app is open;
  there is no background upload.
