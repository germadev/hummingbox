# CI and releases

## `build.yml`: tests and builds

Runs on every push to any branch, manually from the *Actions* tab and from
`release.yml`:

1. **Tests**: `flutter analyze` and `flutter test`.
2. **Android (APK)** on Ubuntu and **iOS (IPA)** on macOS, in parallel, only
   if the tests pass.

The APK and the IPA are kept as downloadable artifacts of the run
(`android-apk` and `ios-ipa`). A new push to the same branch cancels the run
in progress.

## `release.yml`: publishing a version

*Actions → Release → Run workflow*, choose the branch (usually `main`) and
which part of the version to bump:

| Bump    | Example, from `1.4.2+7` |
|---------|-------------------------|
| `patch` | `1.4.3+8`               |
| `minor` | `1.5.0+8`               |
| `major` | `2.0.0+8`               |

The workflow computes the new version from `pubspec.yaml` and builds with
`build.yml`. Only if the build succeeds, it:

- commits "Versión x.y.z" to the branch with the updated `pubspec.yaml`,
- creates the `vx.y.z` tag,
- publishes the GitHub release "HummingBox x.y.z" with
  `hummingbox-x.y.z.apk` and `hummingbox-x.y.z.ipa` attached and notes
  generated from the changes.

If anything fails before that, nothing is pushed or tagged. If the branch is
protected, allow GitHub Actions to push to it; otherwise the last step fails.

## APK signing

Android only installs an update if it is signed with the same key as the
installed version. For every release to install over the previous one,
create a key once and store it in the repository secrets (*Settings →
Secrets and variables → Actions*):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
base64 -w0 upload-keystore.jks   # value of ANDROID_KEYSTORE_BASE64
```

| Secret                      | Value                                    |
|-----------------------------|------------------------------------------|
| `ANDROID_KEYSTORE_BASE64`   | The keystore, base64-encoded             |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password                        |
| `ANDROID_KEY_ALIAS`         | Key alias (`upload` in the example)      |
| `ANDROID_KEY_PASSWORD`      | Key password                             |

Keep a copy of the keystore somewhere safe: if it is lost, new versions will
not install over the old ones.

Without these secrets the APK is signed with a different debug key on every
run and the workflow shows a warning. To sign locally, create
`android/key.properties` (it is in `.gitignore`):

```properties
storeFile=/path/to/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

The IPA is built unsigned: see [Installing](install.md#ios).
