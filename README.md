# Zen Blocks — Neon Aurora

An original falling-block puzzle for Android, built with Flutter and a Neon Aurora visual theme.

## Features
- Home screen, how-to-play guide, game-over summary and restart confirmation
- Automatic local game saves with Continue, plus a ghost-piece landing preview
- Independent music/effects volume sliders and adjustable joystick repeat speed
- Larger board with the next-piece preview above it, plus optional touch joystick controls
- Seven classic geometric tetromino shapes with a randomized 7-piece bag
- 10 × 20 board, line clears, combos, scoring and a next-piece preview
- Difficulty increases every 10 cleared lines (fall speed accelerates)
- Left, right, rotate, soft drop and hard drop touch controls
- Tap board to rotate, swipe horizontally to move, swipe down to hard drop
- Pause/resume and automatic pause when leaving the app
- Persistent personal best, music, sound-effect and vibration settings
- Works offline, no account, ads or tracking
- Glowing gradient blocks, an animated aurora sky and stars
- Five aurora palettes that change every 10 levels, line-clear sparkles and a persistent Spectacular effects toggle

## Prerequisites
Install Flutter SDK (stable) and Android Studio / Android SDK, accept Android SDK licenses, and configure a device or emulator. Check with:

```bash
flutter doctor
flutter doctor --android-licenses
```

## Generate Android platform files
The ZIP includes all authored game source code, assets configuration and tests. Flutter-generated Android platform scaffolding and Gradle wrapper binaries are deliberately not included, because they are version-specific generated files. Run the following **inside the unzipped zen_blocks_nature folder**:

```bash
flutter create --platforms=android --org com.zenblocks.nature .
flutter pub get
rm -f test/widget_test.dart
flutter test
```

`flutter create` generates `android/` and platform build files while retaining the supplied `lib/`, `test/` and `pubspec.yaml` source. If prompted about overwriting existing authored files, choose **No**.

## Build APK for your Android phone

```bash
flutter build apk --debug
```

APK output:

`build/app/outputs/flutter-apk/app-debug.apk`

Transfer the APK to your Android phone and open it. Android may ask you to allow installs from the app you used to open the APK. Alternatively connect your phone with USB debugging and run:

```bash
flutter devices
flutter install
```

For a smaller optimized local test build:

```bash
flutter build apk --release
```

Release APK output:

`build/app/outputs/flutter-apk/app-release.apk`

Note: `flutter build apk --release` without production signing configuration uses the generated Android project's default signing behavior, which is **not suitable for publishing**.

## Play Store release (later)

1. Choose a unique permanent Android application ID before publishing.
2. Set the app name, launcher icon, version and release branding.
3. Configure your own upload signing key and Android Gradle signing configuration. Never commit signing secrets.
4. Run `flutter build appbundle --release` and upload the generated AAB to Google Play Console.
5. Complete required app content declarations, store listing, testing and target API requirements in Play Console.
6. Ensure the name and visual assets are original and do not imply affiliation with Tetris.

## Sound notes
Original ambient music and six distinct game cues are bundled for offline play: start, rotate, block lock, row clear, level up, and game over. Background music and game effects have separate persistent switches in Settings. Music and ongoing effects pause when the game is paused or the app is backgrounded. Audio is composed with `tools/generate_audio.py`; see `assets/audio/README.md` for details.

## Code layout
- `lib/main.dart`: app UI, painter, touch gestures, settings, persistence and timer
- `lib/game.dart`: pure game rules, movement, rotation, scoring, line clearing and level logic
- `test/game_test.dart`: basic gameplay unit tests

## Troubleshooting
- `flutter` not found: add the Flutter SDK `bin` directory to PATH.
- Android SDK not found: install Android Studio and its Android SDK, then run `flutter doctor`.
- No devices: build the APK and copy it to the phone, or enable USB debugging.
- Package dependency resolution fails: ensure network access to pub.dev and rerun `flutter pub get`.

## Limitations
This is a playable prototype. It has no online leaderboard, cloud sync or production signing. Scores are saved on the device only.

## Android APK workflow
The existing `.github/workflows/build-apk.yml` is preserved. A push to `main` or a manual run of **Build Zen Blocks Android APK** generates Android scaffolding, removes the generated default widget test, runs the project tests and builds a debug APK. Download the **ZenBlocks-Nature-Android-APK** artifact and extract `app-debug.apk`. The artifact name and Android organization (`com.zenblocks.nature`) remain unchanged. See [MOBILE_GITHUB_BUILD.md](MOBILE_GITHUB_BUILD.md) for phone instructions.

## Play Store preparation
See [PLAY_STORE_RELEASE.md](PLAY_STORE_RELEASE.md) for the unsigned release-preview workflow, upload signing setup, and remaining store requirements.
