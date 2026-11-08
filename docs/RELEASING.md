# Releasing n8n Connect

This guide explains, step by step, how to sign the APK, keep the signing key safe, publish a version on GitHub Releases, send test builds to testers and install the app on the phone. You don't need to know anything about Android app signing: everything you need is explained here.

Run the commands from the root of the repository, unless stated otherwise.

## Contents

- [a) What the signing key is](#a-what-the-signing-key-is)
- [b) Creating the key](#b-creating-the-key)
- [c) Backup](#c-backup)
- [d) Registering the fingerprint in Firebase](#d-registering-the-fingerprint-in-firebase)
- [e) Storing the secrets in GitHub](#e-storing-the-secrets-in-github)
- [f) Publishing a release (automatic)](#f-publishing-a-release-automatic)
- [g) Publishing manually](#g-publishing-manually)
- [h) Distributing to testers (Firebase App Distribution)](#h-distributing-to-testers-firebase-app-distribution)
- [i) Installing on the phone](#i-installing-on-the-phone)
- [j) Troubleshooting](#j-troubleshooting)

## a) What the signing key is

Every Android APK is signed with a private key. The key identifies who publishes the app: Android checks that each update is signed with the same key as the version already installed.

That is why it matters:

- **Android only installs an update** if it is signed with the same key as the version already on the phone. If you sign with a different key, Android rejects the installation.
- **If you lose the key, you cannot publish updates** that install over the previous versions. The only way out is to change the app identifier, which is the same as a new app: users would have to uninstall the previous version and would lose their session and local data.
- **The key never goes into the repository.** It lives on your PC (and in a backup) and is used to sign. GitHub only stores encrypted copies, for the release workflow.

The debug key used by Android Studio and `flutter run` is not valid for publishing: it is generated on each computer (`~/.android/debug.keystore`), it changes if you change PCs or delete it, and its password is public (`android`). That is why `flutter build apk --release` uses the debug key only if `android/key.properties` does not exist.

## b) Creating the key

> The project author already has the key created. This section documents how it was done, so you can repeat it if needed on another computer or for another project.

1. Create the folder where you will keep the key (outside the repository):

   ```bash
   mkdir -p ~/.android
   ```

2. Generate a strong password with OpenSSL and save it in your password manager as soon as you see it:

   ```bash
   openssl rand -base64 32
   ```

   Do not paste it into chats, issues or screenshots.

3. Generate the key with `keytool` (it comes with the JDK used by Flutter and Android Studio). Replace `Your name` with your name:

   ```bash
   keytool -genkeypair -v \
     -storetype PKCS12 \
     -keystore ~/.android/n8n-connect-release.jks \
     -alias n8n-connect \
     -keyalg RSA -keysize 4096 -validity 10000 \
     -dname "CN=Your name"
   ```

   `keytool` asks for the keystore password: use the one from the previous step. With PKCS12, the key password is the same as the keystore password.

4. Create the file `android/key.properties` with this format. It is listed in `.gitignore`, so git never uploads it. Replace the values with yours, without quotes:

   ```properties
   storeFile=/absolute/path/to/.android/n8n-connect-release.jks
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyAlias=n8n-connect
   keyPassword=YOUR_KEY_PASSWORD
   ```

   - `storeFile` needs the **absolute** path (for example `/home/your-user/.android/n8n-connect-release.jks`); Gradle does not expand `~`.
   - With PKCS12, `keyPassword` is the same as `storePassword`.

5. Restrict the file permissions so that only your user can read it:

   ```bash
   chmod 600 android/key.properties
   ```

Check that the file exists without showing its content with `ls -l android/key.properties` (it should show `-rw-------`). **Do not run `cat android/key.properties`** in a shared terminal or in a recording.

## c) Backup

If you lose the `.jks` file or its password, you lose the ability to update the app (see [a)](#a-what-the-signing-key-is)). Keep copies in **two different places**:

- **The password**: in a password manager (Bitwarden, KeePass, 1Password or similar).
- **The file `~/.android/n8n-connect-release.jks`**: in encrypted storage (an encrypted disk or USB drive, or an encrypted container) and, if you want, in a second encrypted location.

Do not store the `.jks` file unencrypted in the cloud, send it by email, or put it in the repository.

**GitHub secrets are not a backup**: GitHub does not let you read a secret once it is saved. You can only overwrite it.

## d) Registering the fingerprint in Firebase

Firebase only allows Google sign-in from apps whose signing fingerprint is registered. Without this, Google sign-in fails with error 10 (`DEVELOPER_ERROR`).

1. Get the fingerprints of the release key:

   ```bash
   keytool -list -v -keystore ~/.android/n8n-connect-release.jks -alias n8n-connect
   ```

   Enter the keystore password. Copy the **SHA1** and **SHA256** lines (each one is a string of hexadecimal pairs separated by `:`).

2. In the [Firebase console](https://console.firebase.google.com/), open your project and go to **Project settings** (the gear icon) → **General** tab → **Your apps** section.

3. Select the Android app `me.bilibc.n8n_connect` → **Add fingerprint**. Add **both** fingerprints (SHA-1 and SHA-256), one at a time.

4. In the same app, download **google-services.json** again and replace `android/app/google-services.json` with the new file. The file contains the list of fingerprints, so you must download it again after adding them.

5. If you also build locally with the debug key (`flutter run`), its SHA-1 fingerprint must be registered too. You can see it with `cd android && ./gradlew signingReport`.

If you change `google-services.json`, also update the `GOOGLE_SERVICES_JSON_BASE64` secret ([e)](#e-storing-the-secrets-in-github)).

## e) Storing the secrets in GitHub

The release workflow (`.github/workflows/release.yml`) needs seven secrets to build and sign the APK on GitHub. They are added to the repository:

**GitHub → repository → Settings → Secrets and variables → Actions → New repository secret.** Create one for each name in the table, with the exact name.

| Secret name | What it contains | How to get it |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | The full `.jks` file, encoded in base64 | `base64 -w0 ~/.android/n8n-connect-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | `storePassword` in `android/key.properties` (or your password manager) |
| `ANDROID_KEY_ALIAS` | Key alias | `n8n-connect` |
| `ANDROID_KEY_PASSWORD` | Key password | `keyPassword` in `android/key.properties` (the same as the keystore password with PKCS12) |
| `GOOGLE_SERVICES_JSON_BASE64` | `android/app/google-services.json` in base64 | `base64 -w0 android/app/google-services.json` |
| `FIREBASE_OPTIONS_DART_BASE64` | `lib/firebase_options.dart` in base64 | `base64 -w0 lib/firebase_options.dart` |
| `FIREBASE_WEB_CLIENT_DART_BASE64` | `lib/firebase_web_client.dart` in base64 | `base64 -w0 lib/firebase_web_client.dart` |
| `FIREBASE_APP_DISTRIBUTION_SA_BASE64` (optional) | Service account key for App Distribution, in base64. Only needed to send builds to testers from GitHub (see [h)](#h-distributing-to-testers-firebase-app-distribution)) | `base64 -w0` of the service account JSON key, or `tools/release_secrets.sh` with `FIREBASE_SA_JSON` (see below) |

The easiest way is to run the repository script, which reads the local files and prints the name and value of each secret:

```bash
tools/release_secrets.sh
```

To include the optional App Distribution secret, set `FIREBASE_SA_JSON` to the absolute path of the service account JSON key (see [h)](#h-distributing-to-testers-firebase-app-distribution)):

```bash
FIREBASE_SA_JSON=/absolute/path/to/service-account.json tools/release_secrets.sh
```

If `FIREBASE_SA_JSON` is not set, or is not a file, the script prints a note and leaves out the optional secret.

> **Warning: the output of `tools/release_secrets.sh` contains secrets** (the key in base64 and the passwords). Copy them directly to GitHub, do not paste them into chats, issues or screenshots, and close the terminal when you finish. If the session is recorded or shared, do not use it.

With the [GitHub CLI](https://cli.github.com/) installed and signed in (`gh auth login`), the script can upload the secrets for you:

```bash
tools/release_secrets.sh --gh BiliBC034/n8n_connect
```

To upload the optional secret too, add `FIREBASE_SA_JSON` in the same way:

```bash
FIREBASE_SA_JSON=/absolute/path/to/service-account.json tools/release_secrets.sh --gh BiliBC034/n8n_connect
```

Always give the repository (`OWNER/REPO`): if your clone has several remotes, `gh` does not know which one to upload the secrets to (or set one first with `gh repo set-default`).

Afterwards, check that the seven names appear in the repository's list of secrets (and `FIREBASE_APP_DISTRIBUTION_SA_BASE64`, if you uploaded it). The values cannot be viewed again on GitHub, only overwritten.

## f) Publishing a release (automatic)

This is the normal path. When you push a `vX.Y.Z` tag, the **Release** workflow builds and signs the app and creates the release with the APK and its `.sha256` file.

1. **Update the version** in `pubspec.yaml`. The format is `version: X.Y.Z+N`:
   - `X.Y.Z` is the version the user sees (the one in the APK name and in the tag).
   - `N` is the build number. **Increase it for each public release**: it must never go down, because Android refuses to install a build with a lower number, and a higher number keeps each release distinguishable. (A build with the same number, such as a tester build, installs over the previous one if it is signed with the same key: see [h)](#h-distributing-to-testers-firebase-app-distribution).)

   ```yaml
   version: 1.0.1+4
   ```

2. **Add the section** to `CHANGELOG.md`, with the heading `## [X.Y.Z] - YYYY-MM-DD` and the notes in English. The release notes are the lines between that heading and the next `## [`.

3. **Commit** the changes:

   ```bash
   git add . && git commit -m "chore: publish version X.Y.Z"
   ```

4. **Tag and push** the commit and the tag:

   ```bash
   git tag vX.Y.Z
   git push origin main
   git push origin vX.Y.Z
   ```

   The tag must be exactly `vX.Y.Z` and match `version` in `pubspec.yaml`. If it does not match, the workflow fails (see [j)](#j-troubleshooting)).

5. **Follow the process** in the **Actions** tab of the repository, in the **Release** workflow. If it finishes successfully, the release appears under **Releases** with the APK `n8n-connect-vX.Y.Z.apk` and its `n8n-connect-vX.Y.Z.apk.sha256`. If it fails, the log shows the cause (for example, missing secrets). The workflow checks the secrets and the tag, runs `flutter test`, and only builds if everything passes.

## g) Publishing manually

Use this if the workflow does not work, or if you want to build and review the APK before publishing it.

1. Make sure you have `android/key.properties` and the local Firebase files (`lib/firebase_options.dart`, `lib/firebase_web_client.dart`, `android/app/google-services.json`).

2. Build the release:

   ```bash
   tools/build_release.sh
   ```

   The script requires `android/key.properties` and leaves in `dist/` (a folder ignored by git) the APK, its `.sha256` file and `RELEASE_NOTES-vX.Y.Z.md`. It then checks that the APK is not signed with the debug key. If the script ends with the error "is signed with the DEBUG key", **do not publish that APK**, because it will not be able to update to versions signed with the release key. Check `android/key.properties` (see [b)](#b-creating-the-key)) and build again.

3. On GitHub, go to **Releases → Draft a new release**:
   - **Choose a tag**: type `vX.Y.Z`. If the tag does not exist yet, GitHub creates it on the main branch, so push the commit first. Careful: if you already configured the secrets in [e)](#e-storing-the-secrets-in-github), creating the tag can also start the **Release** workflow, which would publish its own APK to that release. Use one route or the other, not both.
   - **Release title**: `n8n Connect vX.Y.Z`.
   - **Description**: paste the contents of `dist/RELEASE_NOTES-vX.Y.Z.md`.
   - **Attach binaries**: drag `dist/n8n-connect-vX.Y.Z.apk` and `dist/n8n-connect-vX.Y.Z.apk.sha256`.

4. Click **Publish release**.

## h) Distributing to testers (Firebase App Distribution)

Firebase App Distribution sends test builds of the app to a list of testers. Testers receive an email invitation, install the app and get new builds without using GitHub Releases. Use it to try a version with other people before you publish it. It is optional: the public release in section [f)](#f-publishing-a-release-automatic) does not need it.

There are three ways to send a build:

- **From GitHub**: run the **Release** workflow by hand from the **Actions** tab.
- **Automatically**: when you push a `vX.Y.Z` tag, the workflow also sends the APK to testers, if the App Distribution secret is set.
- **From your PC**: run `tools/distribute.sh`.

### One-time setup in Firebase

Do this once for your Firebase project.

1. **Turn on App Distribution.** Open the [App Distribution page](https://console.firebase.google.com/project/_/appdistribution) of the Firebase console and select your project (menu labels may vary: the path is **Release & Monitor → App Distribution**). Click **Get started** and select the Android app `me.bilibc.n8n_connect`.

2. **Create a tester group.** Go to **App Distribution → Testers & Groups**, create a group with the alias `testers` (or another name you prefer), and add the email addresses of your testers.

### One-time setup in Google Cloud (service account)

A service account is a "robot" account that lets GitHub or your PC upload builds without using your personal login. You create it once, in Google Cloud, in the same project as Firebase.

3. Open the [Google Cloud console](https://console.cloud.google.com/) and select the same project.
4. Go to **IAM & Admin → Service accounts → Create service account**. Give it any name (for example, `app-distribution`).
5. Grant it the role **Firebase App Distribution Admin**.
6. Open the service account, go to **Keys → Add key → Create new key**, and choose **JSON**. A `.json` file is downloaded.
7. **Keep that file secret.** Anyone who has it can upload builds to your Firebase project. Do not commit it to the repository, paste it into chats or send it by email.

You do not need a backup of this file: if you lose it, create a new key for the service account (or a new service account) and update the GitHub secret with it.

### GitHub secret and optional variable

8. Store the key in GitHub as the secret `FIREBASE_APP_DISTRIBUTION_SA_BASE64`. The value is the JSON file encoded in base64 on a single line. The repository script can upload it, but read the warning below first:

   ```bash
   FIREBASE_SA_JSON=/absolute/path/to/service-account.json tools/release_secrets.sh --gh BiliBC034/n8n_connect
   ```

   > **Warning:** this command needs all the local signing and Firebase files (see [g)](#g-publishing-manually)) and uploads **all seven secrets** again, not only this one. To upload only the App Distribution secret, run:

   ```bash
   base64 -w0 /absolute/path/to/service-account.json | gh secret set FIREBASE_APP_DISTRIBUTION_SA_BASE64 --repo BiliBC034/n8n_connect
   ```

   Or add it by hand in **Settings → Secrets and variables → Actions** (paste the output of `base64 -w0 /absolute/path/to/service-account.json` as the value).

9. (Optional) Create the variable `FIREBASE_TESTER_GROUPS` in **Settings → Secrets and variables → Actions → Variables → New repository variable**. Its value is the group aliases, separated by commas, for example `testers` or `testers,qa`. It is used on tag pushes, and in a manual run only if you clear the **groups** field (that field is pre-filled with `testers`, so the variable is ignored unless you clear it). If it is not set, the default is `testers`.

### Sending a build from GitHub

1. Open the **Actions** tab of the repository, choose the **Release** workflow and click **Run workflow**. The button only appears once `release.yml` (with `workflow_dispatch`) is on the default branch (`main`).
2. Fill in the fields:
   - **Branch** (the **Use workflow from** field): the branch whose code is built.
   - **groups**: the group aliases, separated by commas. The default is `testers`.
   - **release_notes**: optional text that testers see. If you leave it empty, the note is `Test build <short sha> from <ref> (vX.Y.Z)`.
3. Click **Run workflow** and wait for it to finish. The log shows a line like `Distributing n8n-connect-vX.Y.Z.apk to the groups: testers`.

A manual run does not create a GitHub release and does not check the tag or the CHANGELOG. It needs the `FIREBASE_APP_DISTRIBUTION_SA_BASE64` secret: without it, the run fails (see [j)](#j-troubleshooting)).

On tag pushes (section [f)](#f-publishing-a-release-automatic)), the release notes are the CHANGELOG section of that version, and the groups come from the `FIREBASE_TESTER_GROUPS` variable (or `testers`). If the secret is not set, the workflow skips distribution and shows this notice: `FIREBASE_APP_DISTRIBUTION_SA_BASE64 is not set: skipping Firebase App Distribution.`

### Sending a build from your PC

`tools/distribute.sh` builds the APK with `tools/build_release.sh` (so the requirements in [g)](#g-publishing-manually) apply) and uploads it to App Distribution. Do this once:

1. Install the Firebase CLI (it requires Node.js):

   ```bash
   npm install -g firebase-tools
   ```

2. Sign in with one of these options:
   - `firebase login`, with an account that has access to the project; or
   - `GOOGLE_APPLICATION_CREDENTIALS` set to the absolute path of the service account JSON file, for example `export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json`.

   If `GOOGLE_APPLICATION_CREDENTIALS` is not set, the script uses the account from `firebase login`.

Examples:

```bash
tools/distribute.sh                                       # build and send to the default group
tools/distribute.sh --groups testers,qa                   # send to two groups
tools/distribute.sh --notes "Testing the new alarm screen"
tools/distribute.sh --notes-file notes.txt --no-build     # send the APK already in dist/
```

Options:

- `--groups`: comma-separated groups. Default: `$FIREBASE_TESTER_GROUPS` (an environment variable on your PC) or `testers`.
- `--notes` or `--notes-file`: release notes for testers. Default: the CHANGELOG section of the version or, if there is none, `Test build <git short sha>`. Use one of them, not both.
- `--no-build`: do not build; use the existing `dist/n8n-connect-vX.Y.Z.apk`. The file must exist, and the script checks its signature.

In build mode (without `--no-build`), the script does not require a CHANGELOG section for the version: if there is none, the notes fall back to `Test build <git short sha>`. `tools/build_release.sh` still requires the section when you run it directly.

The script prints lines like these:

```
Sending dist/n8n-connect-vX.Y.Z.apk to Firebase App Distribution (app <app id>, groups: testers)...
Release vX.Y.Z sent to the groups: testers
```

### What testers do

1. The tester receives an **invitation email** from Firebase App Tester and accepts it.
2. The tester installs the build from the link in the email, or from the **Firebase App Tester** app. Android must allow **Install unknown apps** for that app or for the browser used to open the link (see [i)](#i-installing-on-the-phone), step 3).
3. If the tester already has a version signed with **another key** (for example, a debug build from Android Studio or `flutter run`), they must **uninstall it first**. Android does not install over an app signed with a different key. See [i)](#i-installing-on-the-phone).
4. Tester builds keep the version name and version code from `pubspec.yaml`. Android allows installing a build with the same version code over the installed one if both are signed with the same key.

## i) Installing on the phone

1. On a PC, open the [latest release](https://github.com/BiliBC034/n8n_connect/releases/latest) and download `n8n-connect-vX.Y.Z.apk` and its `.sha256` file into the same folder.

2. Check that the APK is not corrupted:

   ```bash
   sha256sum -c n8n-connect-vX.Y.Z.apk.sha256
   ```

   It should reply `n8n-connect-vX.Y.Z.apk: OK`. On Windows, PowerShell has `Get-FileHash -Algorithm SHA256`; compare the value with the one in the `.sha256` file. (If you prefer to download the APK directly on the phone, you can skip this step.)

3. Copy the APK to the phone (USB cable, cloud storage, etc.) and allow installing unknown apps for the file manager or browser you use. Menus change depending on the Android version; look for **Install unknown apps** in that app's settings, or under **Settings → Apps → Special access**.

4. Open the APK file and tap **Install**.

> **Warning:** if you had installed a version signed with **another key** (for example, a test build signed with the debug key), Android will not update it. Uninstall it first. You lose the app's session and local data (offline cache, n8n inbox and automation permissions); your server and your apps do not change.

## j) Troubleshooting

- **"App not installed", or a message about a package conflict or an invalid or incompatible package.** The installed version is signed with another key or has a higher build number. Uninstall the current app (you lose the session and local data) and install the new one. To avoid this in the future, always sign with the same key.

- **Error 10 or `DEVELOPER_ERROR` when signing in with Google.** The SHA-1 (and SHA-256) fingerprint of the key used to sign the APK is missing from the Android app in Firebase. Follow [d)](#d-registering-the-fingerprint-in-firebase), download `google-services.json` again and update the `GOOGLE_SERVICES_JSON_BASE64` secret.

- **The workflow fails because of secrets.** The check step says which secrets are missing. Add them under **Settings → Secrets and variables → Actions**, with the exact name from the table in [e)](#e-storing-the-secrets-in-github). Then run the workflow again from the **Actions** tab.

- **The workflow fails because the tag does not match `pubspec.yaml`.** The `vX.Y.Z` tag must be the same as `X.Y.Z` in `version:`. To fix it:

  1. Delete the wrong tag, locally and on GitHub:

     ```bash
     git tag -d vA.B.C
     git push origin :refs/tags/vA.B.C
     ```

  2. If the problem was `pubspec.yaml`, fix it, then commit and push. If the problem was the tag, do not change anything.
  3. Create the correct tag on the last commit and push it:

     ```bash
     git tag vX.Y.Z
     git push origin vX.Y.Z
     ```

  If a release was already published with the wrong tag, delete it on GitHub (**Releases → Edit → Delete**).

- **"Keystore was tampered with, or password was incorrect" in the workflow.** The `ANDROID_KEYSTORE_PASSWORD` secret is not the keystore password, or `ANDROID_KEYSTORE_BASE64` is incomplete (copy it whole; it is one long line). Overwrite both secrets.

- **"Cannot recover key" in the workflow.** The alias (`ANDROID_KEY_ALIAS`, which must be `n8n-connect`) or `ANDROID_KEY_PASSWORD` is wrong. With PKCS12, `ANDROID_KEY_PASSWORD` is the same password as the keystore's.

- **`key.properties not found` during the build.** You have not created `android/key.properties`, so the APK is signed with the debug key. The build prints `key.properties not found: the release is signed with the debug key`. Create the file ([b)](#b-creating-the-key)) before publishing.

- **The build fails because Firebase files are missing.** `tools/build_release.sh` prints `MISSING: <path>` for each missing file. Copy the `.example` files to their real names, or use your own `google-services.json` and Firebase options, as explained in the [README](../README.md#getting-started).

- **`HTTP Error: 403, The caller does not have permission` when sending to App Distribution.** The Firebase CLI usually prints this, often right after `failed to fetch app information`. The service account does not have the **Firebase App Distribution Admin** role in the project. In the Google Cloud console, select the same project as Firebase, go to **IAM & Admin → IAM**, find the service account and grant it that role (see the service account steps in [h)](#h-distributing-to-testers-firebase-app-distribution)). Wait a minute, then run the upload again. Also check that the `FIREBASE_APP_DISTRIBUTION_SA_BASE64` secret (or the `GOOGLE_APPLICATION_CREDENTIALS` file on your PC) holds the key of that account.

- **Group alias not found.** The group named in the **groups** field, in `--groups` or in `FIREBASE_TESTER_GROUPS` does not exist in App Distribution. Check the alias in **App Distribution → Testers & Groups** and type it exactly as it appears there. To send to several groups, separate them with commas.

- **App not found, or App Distribution not set up.** The Firebase Android app ID is read from `android/app/google-services.json`. If you see `No Firebase Android app for me.bilibc.n8n_connect found in android/app/google-services.json` (workflow) or `No Android app for me.bilibc.n8n_connect in android/app/google-services.json. Download it again from the Firebase console.` (`tools/distribute.sh`), check that App Distribution is enabled ([h)](#h-distributing-to-testers-firebase-app-distribution), step 1) and that `google-services.json` is the current file from Firebase. If the Firebase app was recreated, download the file again, replace the local copy and update the `GOOGLE_SERVICES_JSON_BASE64` secret.

- **The `FIREBASE_APP_DISTRIBUTION_SA_BASE64` secret is missing on a manual run.** The workflow stops with `Manual runs distribute the APK to testers, so the FIREBASE_APP_DISTRIBUTION_SA_BASE64 secret is required.` Add the secret as described in [h)](#h-distributing-to-testers-firebase-app-distribution) and run the workflow again from the **Actions** tab. (On a tag push, a missing secret does not fail the workflow; it only skips distribution.)
