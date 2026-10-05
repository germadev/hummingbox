# Installing

Download the files from the
[releases page](https://github.com/germadev/voicerecorder/releases).

## Android

Install `hummingbox-x.y.z.apk` (Android 7.0 or later). Your phone may ask you
to allow installing apps from the browser or file manager you open it with.

An update only installs over the previous version if both are signed with
the same key (see [APK signing](releases.md#apk-signing)).

## iOS

The IPA is **unsigned**, because signing it needs an Apple developer account.
To install it on an iPhone it has to be signed while installing it, for
example with [Sideloadly](https://sideloadly.io/) (Mac or Windows) and an
Apple account:

1. Download `hummingbox-x.y.z.ipa` from the release.
2. Install Sideloadly. On Windows it also needs iTunes and iCloud downloaded
   from Apple's website (not the Microsoft Store versions).
3. Connect the iPhone with a cable and accept "Trust This Computer".
4. Drag the IPA onto Sideloadly, enter your Apple ID and press *Start*. If
   Google Drive is configured, do not change the bundle identifier
   (`es.germade.voicerecorder`): Google sign-in depends on it.
5. On the iPhone: *Settings → General → VPN & Device Management*, tap your
   Apple ID and trust it. On iOS 16 or later also turn on *Settings → Privacy
   & Security → Developer Mode* (it appears after installing the app) and
   restart.

With a free account the signature expires after **7 days** (the app has to
be signed again; Sideloadly can refresh it over Wi-Fi while the computer is
on) and up to 3 apps can be installed this way at a time. With an Apple
developer account (99 €/year) it lasts a year, and CI could sign the IPA and
upload it to TestFlight. AltStore works too, but it changes the bundle
identifier, so Google Drive would not work.
