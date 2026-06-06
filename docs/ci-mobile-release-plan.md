# Mobile release CI — Android (then iOS) — implementation plan

**Status:** Proposed (not started)
**Created:** 2026-06-05
**Scope:** Build + release the Flutter app (`app/`) from GitHub Actions on tag push. Android first; iOS added later.
**Related docs:** [`high-level-design.md`](high-level-design.md) §0 (Implementation status), §11.3 (Testing), §4 (Platform & tech stack)

---

## 0. Goal

When a release tag is pushed, GitHub Actions builds a **signed Android artifact** and attaches it to a **GitHub Release** automatically. No local builds, no manual signing. The same workflow is later extended with an iOS job on a macOS runner.

**Success looks like:**

```
git tag app-v0.2.0
git push origin app-v0.2.0
# → CI builds signed AAB + APK → attaches to GitHub Release "app-v0.2.0"
```

---

## 1. Current state (what CI must reproduce)

From the repo today:

| Thing | Current value | CI implication |
| --- | --- | --- |
| Framework | Flutter (`sdk ^3.9.0`, `flutter >=3.41.0`) | Pin Flutter version in workflow |
| App ID | `com.jobsiterecords.app` | Used for Play Store later |
| Min / target SDK | `minSdk = 26`, `targetSdk = flutter.targetSdkVersion` | No change |
| Java | 17 (`build.gradle.kts`) | Set up JDK 17 in CI |
| Gradle plugins | AGP `8.11.1`, Kotlin `2.2.20` | Provided by Gradle wrapper; CI just needs JDK + SDK |
| **Release signing** | **Debug keys** (`signingConfigs.getByName("debug")`) | **Must switch to a real upload keystore** |
| Version | `version: 0.1.0+1` in `pubspec.yaml` | Override from the tag |
| Bundled `.env` asset | Required (`flutter:` assets list); holds `GOOGLE_MAPS`, `GOOGLE_WEB_CLIENT_ID`, `API_BASE_URL` | **Generate from GitHub Secrets at build time** |
| Local package | `packages/flutter_google_places_sdk` (path dep) | In-repo, works in CI |
| Git override | `record_linux` from GitHub `master` | CI needs network for `pub get` (fine) |

The two real blockers are **signing** (debug keys today) and the **`.env` asset** (secrets, not committed). Everything else is standard Flutter CI.

---

## 2. Trigger design

Use a dedicated tag namespace so app releases are independent from backend/web tags.

```yaml
on:
  push:
    tags:
      - 'app-v*'        # e.g. app-v0.2.0, app-v0.2.0+5
```

**Version derivation from tag** (avoids editing `pubspec.yaml` per release):

- Tag `app-v0.2.0` → `--build-name=0.2.0`
- Build number: use the monotonic `github.run_number` (or `+N` suffix in the tag if present) → `--build-number=<n>`

```bash
flutter build appbundle --release \
  --build-name="$VERSION_NAME" \
  --build-number="$BUILD_NUMBER"
```

> Decision: keep `pubspec.yaml` at a dev default; the tag is the source of truth for released version. Document this in the release runbook (§8).

---

## 3. Signing (the critical setup)

Release builds currently sign with the **debug** keystore. For distributable artifacts we need a stable **upload keystore**.

### 3.1 One-time local steps (done by maintainer, not in CI)

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks > upload-keystore.jks.base64
```

Store as **GitHub repository secrets** (never commit the keystore):

| Secret | Contents |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 of `upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | store password |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_KEY_ALIAS` | `upload` |

### 3.2 Gradle change (committed)

Edit `app/android/app/build.gradle.kts` to read a `key.properties` file when present, falling back to debug for local dev:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")  // local dev fallback
        }
    }
}
```

`key.properties` and `*.jks` are **gitignored**; CI materializes them from secrets (§5). This keeps local `flutter run --release` working without the real keystore.

---

## 4. The `.env` asset

`pubspec.yaml` lists `.env` as a bundled asset and the app loads it via `flutter_dotenv`. It is **not committed** (only `.env.example` is). The build fails without it.

**CI approach:** write `app/.env` from secrets before `flutter build`.

| Secret | Maps to `.env` key |
| --- | --- |
| `APP_GOOGLE_MAPS` | `GOOGLE_MAPS` |
| `APP_GOOGLE_WEB_CLIENT_ID` | `GOOGLE_WEB_CLIENT_ID` |
| `APP_API_BASE_URL` | `API_BASE_URL` (production URL for released builds) |

```bash
cat > app/.env <<EOF
GOOGLE_MAPS=${{ secrets.APP_GOOGLE_MAPS }}
GOOGLE_WEB_CLIENT_ID=${{ secrets.APP_GOOGLE_WEB_CLIENT_ID }}
API_BASE_URL=${{ secrets.APP_API_BASE_URL }}
EOF
```

> Note: `GOOGLE_MAPS` is embedded in the shipped app. Restrict that key (Android app + SHA-1 of the upload cert) in Google Cloud Console so a leaked key from the APK is not abusable.

---

## 5. Android workflow (proposed `.github/workflows/android-release.yml`)

```yaml
name: Android Release

on:
  push:
    tags:
      - 'app-v*'

jobs:
  build-android:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.0'   # pin to match pubspec
          channel: stable
          cache: true

      - name: Derive version from tag
        run: |
          TAG="${GITHUB_REF_NAME#app-v}"
          echo "VERSION_NAME=${TAG%%+*}" >> "$GITHUB_ENV"
          echo "BUILD_NUMBER=${GITHUB_RUN_NUMBER}" >> "$GITHUB_ENV"

      - name: Write .env
        run: |
          cat > .env <<EOF
          GOOGLE_MAPS=${{ secrets.APP_GOOGLE_MAPS }}
          GOOGLE_WEB_CLIENT_ID=${{ secrets.APP_GOOGLE_WEB_CLIENT_ID }}
          API_BASE_URL=${{ secrets.APP_API_BASE_URL }}
          EOF

      - name: Restore keystore
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/app/upload-keystore.jks
          cat > android/key.properties <<EOF
          storeFile=app/upload-keystore.jks
          storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
          keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
          EOF

      - run: flutter pub get
      - run: flutter analyze        # optional gate
      - run: flutter test           # optional gate (see §7)

      - name: Build AAB + APK
        run: |
          flutter build appbundle --release \
            --build-name="$VERSION_NAME" --build-number="$BUILD_NUMBER"
          flutter build apk --release \
            --build-name="$VERSION_NAME" --build-number="$BUILD_NUMBER"

      - name: Publish GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            app/build/app/outputs/bundle/release/app-release.aab
            app/build/app/outputs/flutter-apk/app-release.apk
          generate_release_notes: true
```

`storeFile` is resolved relative to the `android/` module root, hence `app/upload-keystore.jks` while the file is written to `android/app/upload-keystore.jks`.

---

## 6. Distribution options (pick per maturity)

| Target | Artifact | When | Extra setup |
| --- | --- | --- | --- |
| **GitHub Release (sideload)** | APK | Now — testers install directly | None beyond §5 |
| **Firebase App Distribution** | APK / AAB | Closed testing groups | `wzieba/Firebase-Distribution-Github-Action` + service account |
| **Google Play (internal track)** | AAB | Beta/prod | `r0adkll/upload-google-play` + Play service-account JSON; app must exist in Play Console |

Recommended path: **start with APK on GitHub Releases** (zero external accounts), add **Play internal track** once a Play Console listing exists.

---

## 7. Tests in the release path

`docs/high-level-design.md` notes tests are **minimal** (`note_markdown_test.dart`, `photo_annotation_test.dart`). Options:

- Keep `flutter analyze` + `flutter test` as **non-blocking** at first (warn only), or
- Make them **blocking** so a broken tag never ships. Preferred once the suite is trusted.

Consider a separate **CI-on-PR** workflow (`on: pull_request`) that runs `analyze` + `test` + a debug build, so the tag workflow is the only one that signs/releases. This split keeps secrets out of PR builds from forks.

---

## 8. Release runbook (for humans)

1. Land changes on `main`, green CI.
2. Decide version, e.g. `0.2.0`.
3. `git tag app-v0.2.0 && git push origin app-v0.2.0`.
4. Watch the **Android Release** workflow; on success the GitHub Release has the AAB + APK.
5. (Later) promote AAB through Play tracks.

---

## 9. iOS (later — same trigger, separate job)

Add a second job to the same workflow, gated to the same tag. iOS needs a **macOS runner** and Apple signing material.

```yaml
  build-ios:
    runs-on: macos-14
    # ... checkout, flutter-action, write .env ...
```

Required pieces (more involved than Android):

| Need | How |
| --- | --- |
| Apple Developer Program | Paid membership (App Store Connect) |
| Signing certs + provisioning | `fastlane match` (recommended) or manual `.p12` + profile imported into a temp keychain |
| Build | `flutter build ipa --release --export-options-plist=ExportOptions.plist` |
| Upload | TestFlight / App Store via `fastlane pilot`/`deliver` or `xcrun altool`/`notarytool` |
| Secrets | `APPSTORE_*` API key (issuer id, key id, `.p8`), match repo + passphrase |

Keep iOS in the **same workflow file** so one tag fans out to both platforms; the jobs run independently and each attaches its artifact to the release.

---

## 10. Open decisions

1. **Tag scheme:** `app-v*` (proposed) vs reuse plain `v*`. `app-` prefix avoids clashing if backend/web later get their own release tags.
2. **Build number source:** `github.run_number` (simple, monotonic) vs encode `+N` in the tag. Run number recommended.
3. **Tests blocking or not** in the release job (§7).
4. **First distribution channel:** GitHub Release APK only, or wire Play internal track immediately.
5. **Keep `pubspec` version static** and drive from tag (proposed) vs bump `pubspec` per release.

---

## 11. Checklist (implementation order)

- [ ] Add `key.properties` + `*.jks` to `.gitignore` (and `app/.env` already ignored — verify).
- [ ] Update `app/android/app/build.gradle.kts` release signing (§3.2).
- [ ] Generate upload keystore; add 4 keystore secrets + 3 `.env` secrets (§3.1, §4).
- [ ] Add `.github/workflows/android-release.yml` (§5).
- [ ] (Optional) Add PR CI workflow: `analyze` + `test` + debug build.
- [ ] Restrict the Maps API key to the Android app + upload cert SHA-1.
- [ ] Dry-run with a throwaway tag (`app-v0.0.1-rc1`); verify signed artifacts.
- [ ] Document the runbook (§8) in the repo README or `deploy/`.
- [ ] Later: add `build-ios` job + Apple signing (§9).
```
