# Storage

Recordings **live in the chosen destination**: a folder on the device or, if
none is chosen, Google Drive. Files are named after the recording and stored
in its subfolder (`Classes/Lesson 1.m4a`).

The app keeps an index, `recordings.json`, in its private folder, with each
recording's name, date, duration, waveform, format, subfolder, transcript
and file in the destination. The audio itself is in the destination, not in
the app.

## How it works

- **No copies**: what is in the destination (`.m4a` and `.wav` files in the
  folder and in the first level of subfolders) shows up in the app as it is,
  without copying it. It is read again when the folder is chosen, when the
  app comes back to the foreground, when the side menu opens and with
  *Sync now*.
- **Both ways**: renaming, editing or deleting a recording in the app does
  the same to its file (in Drive, deleting moves it to the trash). Files
  deleted from the destination outside the app disappear from the app,
  changed files are read again and renamed files keep their waveform (they
  are recognized by subfolder, size and, when known, MD5 checksum).
- **Changes made outside the app** are detected by each file's **size and MD5
  checksum**. Google Drive provides the checksum when listing, so nothing has
  to be downloaded. A device folder does not: the app also stores the
  modification date and only reads the file to compute the checksum when the
  date changes (if only the date changed, the file is not treated as changed
  and what was read stays in the cache).
- **Pending work**: the recorder needs a local file, so recording happens
  inside the app and the recording is saved to the destination when it
  stops. The same goes for edits. While saving is not possible (offline, no
  permission, SD card removed…) the recording stays in the app and is retried
  when the app comes back or with *Sync now*. Errors are shown in Settings
  and with an icon in the top bar.
- **Cache**: to play, edit, share or compute the waveform, the audio is read
  from the destination (downloaded from Drive) and kept in the app's cache,
  which is limited to 100 MB: when it is full, the least recently used files
  are removed, and the system can also clear it. New and edited recordings
  go to the cache when they are saved to the destination.
- **Changing the destination**: recordings that were only in the app are
  saved to the new one; those in the previous destination **stay there** and
  are no longer shown (if you pick it again they come back, and the app
  recognizes their files by name and size, without duplicates). If you stop
  using the folder while Drive is connected, the app switches to Drive (which
  already has a copy of every recording); from Drive to a folder, recordings
  are downloaded from Drive and saved to the folder.
- **Copy in Drive**: with a device folder as the destination, Drive keeps a
  copy of each recording. Copies are updated when a recording is renamed or
  edited, but not deleted when it is deleted.
- **Google Drive as the destination**: with the `drive.file` scope the app
  only sees the files it created (also from another device), not files
  uploaded by hand to its folder. **Nothing is downloaded to show the list**:
  the waveform, duration and format of files that come from Drive are
  computed the first time they are played or shared (which is when they are
  downloaded and cached). Playing a recording requires downloading it
  (unless it is cached).
- **Drive folder**: when Drive is connected, the app creates (or reuses) a
  folder with the app's name, "HummingBox". Connections made with earlier
  versions keep the folder they were using.

Transcripts are also saved in the destination, as `.txt` files next to the
audio: see [Transcription](transcription.md#txt-files).

On Android the folder is chosen with the system picker and the permission is
kept across restarts. On iOS the document picker is used (On My iPhone,
iCloud Drive…) together with a security-scoped bookmark.
