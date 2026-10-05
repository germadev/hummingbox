# Google Drive setup

To connect Google Drive the app has to be registered in Google Cloud once.
Without this setup the app works the same, but the Google Drive option is
disabled.

1. In the [Google Cloud Console](https://console.cloud.google.com/), create a
   project and enable the **Google Drive API**.
2. Configure the **OAuth consent screen** (*External*) and add the
   `https://www.googleapis.com/auth/drive.file` scope, which only gives access
   to the files the app creates. While it is in testing mode, add your
   account as a test user.
3. In *Credentials*, create three **OAuth client IDs**:
   - **Android**: package `es.germade.voicerecorder` and the SHA-1
     fingerprint of the key the APK is signed with
     (`keytool -list -v -keystore upload-keystore.jks -alias upload`).
     Without the `ANDROID_*` secrets every CI build uses a different key and
     sign-in fails (see [APK signing](releases.md#apk-signing)).
   - **Web application**: nothing else to configure; Android needs it as the
     `serverClientId`.
   - **iOS**: bundle ID `es.germade.voicerecorder`.
4. In the repository, *Settings → Secrets and variables → Actions →
   Variables*, create these **variables** (client IDs are not secrets):

   | Variable                  | Value                                                  |
   |---------------------------|--------------------------------------------------------|
   | `GOOGLE_SERVER_CLIENT_ID` | **Web** client ID (`…apps.googleusercontent.com`)      |
   | `GOOGLE_IOS_CLIENT_ID`    | **iOS** client ID                                      |

`build.yml` passes them to the app with `--dart-define` and, on iOS,
generates the sign-in callback URL scheme (the reversed client ID). If they
are missing, the workflow says so with a notice.

The package and bundle IDs stay `es.germade.voicerecorder` (the app's
original name): changing them would break updates of installed copies and
Google sign-in.

## Running locally

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=…                                 # Android
flutter run --dart-define=GOOGLE_IOS_CLIENT_ID=1234-abc.apps.googleusercontent.com  # iOS
```

On iOS also create `ios/Flutter/GoogleSignIn.xcconfig` (it is in
`.gitignore`) with the reversed ID:

```
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.1234-abc
```
