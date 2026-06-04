# Job Site Records (jobsiterecords.com) — Mobile App

Flutter app for Android and iOS. Local-only MVP. See repo root [`README.md`](../README.md) and [`docs/high-level-design.md`](../docs/high-level-design.md) for the full design.

---

## Running on your Android phone over USB

### One-time setup

1. **Enable Developer Options on the phone**
   Open `Settings → About phone → Build number` and tap "Build number" 7 times. You'll see *"You are now a developer."*
2. **Enable USB debugging**
   `Settings → System → Developer options → USB debugging` → ON.
3. **Plug the phone into your computer with a USB cable.**
   On the phone, when prompted *"Allow USB debugging?"*, tick *"Always allow from this computer"* and tap **Allow**.

### Verify the device is visible

```bash
adb devices
```

You should see one line with your device serial and the word `device`. If you see `unauthorized`, accept the prompt on the phone. If you see nothing, switch the USB connection mode on the phone from *"Charging only"* to *"File transfer / MTP"*.

### Flutter SDK location (this machine)

The Flutter SDK lives next to this repo at **`~/projects/flutter/`** (from the official Linux tarball, contents moved to the top level of that directory). The CLI is **`~/projects/flutter/bin/flutter`**.

### Add Flutter to your PATH (once per shell, or add to `~/.bashrc`)

```bash
export FLUTTER_HOME="$HOME/projects/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
```

If Gradle complains that `javac` is missing, install a full JDK (not only the JRE), for example `sudo apt install openjdk-17-jdk`, and set `JAVA_HOME` to that JDK (often `/usr/lib/jvm/java-17-openjdk-amd64`).

### Google Places (address autocomplete)

Copy `.env.example` to **`app/.env`** (or symlink: `ln -s ../.env app/.env`) and set `GOOGLE_MAPS` to your restricted API key. Without a key, the address field is a plain text box.

In Google Cloud Console:

1. **Enable APIs** (APIs & Services → Library):
   - **Places API (New)** — required; the app uses the new Places SDK autocomplete.
   - **Places API** (legacy) — optional backup.
   - **Maps SDK for Android** — often required alongside Places on Android.

2. **API key restrictions** (Credentials → your key):
   - Application: Android apps → `com.jobsiterecords.app` + your SHA-1.
   - API restrictions: allow at least **Places API (New)** and **Maps SDK for Android**.

Billing must be enabled on the project. Without **Places API (New)**, autocomplete returns error 9011 (“requests are blocked”) and you can still type an address manually.

### Google Sign-In (Android sync)

In **`app/.env`** (or repo root `.env` via symlink), set:

- `GOOGLE_WEB_CLIENT_ID` — **Web application** OAuth client ID (same as dashboard web sign-in).
- `API_BASE_URL` — LAN IP the phone can reach, e.g. `http://192.168.1.113:8080` (not `localhost`).

In **Google Cloud Console → Credentials**:

1. **Web client** — used as `serverClientId` in the app (via `GOOGLE_WEB_CLIENT_ID`).
2. **Android client** — package `com.jobsiterecords.app` + **SHA-1** fingerprint for the keystore you build with.

Debug SHA-1 (default Flutter debug keystore):

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

Add that SHA-1 to the **Android** OAuth client. Without it, Google opens the account picker then fails silently or with `ApiException: 10`.

The API’s `GOOGLE_CLIENT_ID` env can list multiple client IDs (comma-separated); the app must **not** pass that whole string — only the Web client ID.

### Run

From `app/`:

```bash
flutter pub get      # fetch dependencies (only needed first time)
flutter run          # builds, installs, and launches on the connected phone
```

This launches the app on the phone with hot-reload. Press `r` in the terminal for hot reload, `R` for full restart, `q` to quit. The first build downloads Gradle dependencies and the Android NDK — expect 5–15 minutes the first time. Subsequent builds take seconds.

### Just install (no hot reload)

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

The app appears in your launcher as **Job Site Records**.

### Build a release APK

```bash
flutter build apk --release
```

The signed-with-debug-keys APK lands at `build/app/outputs/flutter-apk/app-release.apk`. For Play Store, you'll need to add a real signing config — out of scope for the MVP test.

---

## Project layout

```
lib/
├── main.dart            entry point
├── app/                 bootstrap, theme, router, shell, providers
├── core/                ids, format, clock helpers
├── data/
│   ├── db/              SQLite schema + migrations + default tags seed
│   ├── repositories/    JobsRepository, ItemsRepository, TagsRepository
│   └── storage/         media file IO (photos, voice notes)
├── domain/
│   ├── models/          Job, Item, Tag, MediaFile, TimelineItem
│   └── services/        ExportService (zip + index.html + media folders)
└── features/
    ├── jobs/            list, form (create/edit), detail
    ├── capture/         photo, voice, note + shared tag chip widget
    ├── item_detail/     view/edit single item, audio playback
    ├── export/          item selection + zip export + share sheet
    └── settings/        storage, tags, waitlist, feedback, about
```

## Toolchain

- Flutter 3.41+ stable
- Dart 3.11+
- Minimum OS: Android 8.0 (API 26), iOS 14+
- Android target SDK: 34

## Testing

```bash
flutter test
```

## Where the data lives on the phone

Everything is in the app's private storage:

- SQLite DB: `<app docs>/jobsiterecords.db`
- Photos / voice notes: `<app docs>/media/<job_id>/<item_id>/`
- Exports: `<app cache>/exports/JobSiteRecords_<JobName>_<date>.zip`

Uninstalling the app deletes everything. There is no cloud copy — that's the MVP promise.
