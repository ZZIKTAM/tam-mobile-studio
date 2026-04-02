# tam-mobile-studio Project Rules

BPSR 모바일 컴패니언 앱. PC 앱(tam-bpsr-studio)에서 Firebase를 통해 데이터를 수신하여 표시.

## Project Structure

Repository: `tam-mobile-studio` (GitHub: ZZIKTAM/tam-mobile-studio, private)

```
tam-mobile-studio/
├── lib/
│   └── main.dart             <- 전체 앱 코드 (단일 파일)
├── android/
│   ├── app/
│   │   ├── build.gradle.kts
│   │   ├── google-services.json  <- Firebase config (committed)
│   │   └── src/main/AndroidManifest.xml
│   └── build.gradle.kts
├── pubspec.yaml              <- Flutter 의존성
├── CLAUDE.md                 <- This file
└── README.md
```

## Tech Stack

| Item | Version |
|------|---------|
| Flutter | 3.29.3 (C:\flutter\flutter\) |
| Dart | 3.7.2 |
| Android SDK | API 34 (C:\android-sdk\) |
| JDK | Microsoft OpenJDK 17 (C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot\) |
| Firebase | Realtime Database |
| Target | Android only (iOS planned) |

## Firebase

- **Project:** tam-studio (Google Cloud)
- **Realtime DB URL:** `https://tam-studio-3df21-default-rtdb.asia-southeast1.firebasedatabase.app/`
- **Data structure:**
  ```
  /users/{userKey}/buffs    <- PC writes, mobile reads
  /users/{userKey}/drops    <- PC writes, mobile reads
  /app_version              <- latest version info for auto-update
  ```
- `google-services.json` is committed (not sensitive for Realtime DB)
- Security rules: test mode (open read/write) — tighten before public release

## Authentication (Google Sign-In)

- Both PC and mobile use **Google OAuth** → same Google account → same Firebase UID
- Firebase path: `users/{firebase_uid}/...`
- **First login:** account picker always shown (signOut before signIn)
- **Subsequent launches:** auto sign-in via `FirebaseAuth.instance.currentUser`
- **Logout:** Google signOut + Firebase signOut → requires re-login
- **Web client ID (serverClientId):** `178808646003-tfd34jpt7ps4c6neaa0j22mrukdkjqb7.apps.googleusercontent.com`

## App Pages

| Page | Description |
|------|-------------|
| KeyGatePage | Google Sign-In login screen |
| BuffMonitorPage | Real-time buff list with countdown timers (100ms refresh) |
| DropTrackerPage | Drop accumulation with real-time elapsed time |
| SettingsPage | Google account info, disconnect, app version |

## Build & Deploy

**Release Signing (required on every build machine):**

APK must be signed with the same release key across all machines. Without this, users get "패키지가 기존 패키지와 충돌" error and must uninstall first.

1. Copy `upload-keystore.jks` to `android/app/upload-keystore.jks` (NOT committed to git — transfer manually)
2. Create `android/key.properties`:
   ```
   storePassword=tamstudio2026
   keyPassword=tamstudio2026
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
3. `build.gradle.kts` already configured to read `key.properties` (committed)

**Key files (NOT in git, must be copied manually between machines):**
- `android/key.properties` — signing passwords
- `android/app/upload-keystore.jks` — release keystore (2048-bit RSA, valid 10000 days)

**If keystore is lost:** all users must uninstall and reinstall. NEVER lose the keystore.

**Build APK:**
```bash
export ANDROID_HOME="C:/android-sdk"
export JAVA_HOME="C:/Program Files/Microsoft/jdk-17.0.18.8-hotspot"
cd tam-mobile-studio
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

**Deploy (version update):**
1. Update `appVersion` in `lib/main.dart`
2. Build APK: `flutter build apk --release`
3. **Rename APK** before upload: `cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/tam-studio.apk`
4. Upload to GitHub Releases: `gh release create vX.Y.Z build/app/outputs/flutter-apk/tam-studio.apk --title "vX.Y.Z"`
5. Update Firebase version:
   ```bash
   curl -X PUT "https://tam-studio-3df21-default-rtdb.asia-southeast1.firebasedatabase.app/app_version.json" \
     -H "Content-Type: application/json" \
     -d '{"latest":"X.Y.Z","apk_url":"https://github.com/ZZIKTAM/tam-mobile-studio/releases/download/vX.Y.Z/tam-studio.apk"}'
   ```
6. Commit + push

**Rules:**
- APK is NOT copied to desktop — uploaded to GitHub Releases only
- `appVersion` in main.dart MUST match GitHub release tag
- Firebase `app_version.latest` MUST match the release tag
- First install is manual (share APK link), subsequent updates are automatic

**Critical — past mistakes, DO NOT repeat:**
- **APK filename MUST be `tam-studio.apk`** — Flutter outputs `app-release.apk`, but Firebase `apk_url` expects `tam-studio.apk`. MUST rename before uploading to GitHub Releases. `gh release create ... app-release.apk#tam-studio.apk` does NOT rename the file — it only sets a label. The actual download URL uses the original filename.
- **Correct upload flow:** rename file first (`cp app-release.apk tam-studio.apk`), then `gh release create vX.Y.Z tam-studio.apk`
- **Verify after upload:** run `gh release view vX.Y.Z` and confirm `asset: tam-studio.apk` (not `app-release.apk`)
- **Version bump BEFORE build** — update `appVersion` in `main.dart` first, then build. If you build first and bump after, the APK contains the old version string.

## Auto-Update System

- App checks Firebase `/app_version` on startup
- If `latest` != `appVersion` → show update dialog
- "업데이트" button → download APK from `apk_url` → open installer
- User taps "설치" (Android requirement) → update complete
- `open_filex` package handles APK installation with correct mime type

## Related Repositories

- `tam-bpsr-studio` — PC app (WPF, C#) that captures game data and sends to Firebase
- `tam-autodesk-studio` — Autodesk plugins (separate project)

## Language

- User communicates in Korean
- Code comments and commit messages in English
- CLAUDE.md in English
