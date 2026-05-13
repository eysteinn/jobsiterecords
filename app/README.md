# SiteLog — Mobile App

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

The app appears in your launcher as **SiteLog**.

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
│   └── services/        ExportService (zip + index.html + job.json builder)
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

- SQLite DB: `<app docs>/sitelog.db`
- Photos / voice notes: `<app docs>/media/<job_id>/<item_id>/`
- Exports: `<app cache>/exports/SiteLog_<JobName>_<date>.zip`

Uninstalling the app deletes everything. There is no cloud copy — that's the MVP promise.
