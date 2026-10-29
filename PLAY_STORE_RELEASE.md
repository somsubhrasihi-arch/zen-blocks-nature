# T-Block Aurora release preparation

Version 1.3.0 retains resumable local games, a landing preview, home and game-over
flows, gravity-safe controls, adjustable joystick speed, and audio volume sliders.

## Two independent build workflows

- **Build Zen Blocks Android APK** is unchanged and continues producing the
  installable test APK for your phone.
- **Check Play Store bundle** uses pinned Flutter 3.47.8 and target API 36. Every
  push checks an optimized release AAB without signing credentials. Its artifact
  is clearly labelled **UNSIGNED-Release-Preview**; it cannot be uploaded as a
  finished Play release.

## Signing preparation

To produce an upload-signed bundle, create and securely back up an Android upload
keystore and add these repository Actions secrets:

| Secret | Value |
| --- | --- |
| `ZEN_UPLOAD_KEYSTORE_BASE64` | Base64-encoded keystore file |
| `ZEN_UPLOAD_STORE_PASSWORD` | Keystore password |
| `ZEN_UPLOAD_KEY_ALIAS` | Upload-key alias |
| `ZEN_UPLOAD_KEY_PASSWORD` | Key password |

Keep the key and passwords outside the source repository. Do not paste them in
chat. Run **Check Play Store bundle** manually with **sign_release** enabled.
The result will be named **ZenBlocks-PlayStore-AAB**. Missing secrets fail the
build before an upload artifact is produced; no debug-signing fallback is used.
The temporary keystore is removed at the end of the job. No Play submission or
automatic store publishing is configured.

The existing application ID is `com.zenblocks.nature.zen_blocks`. Confirm this
permanent identity before creating the Play Console app. The release script
refuses to change it silently.

## Before closed testing

1. Create and verify your Play Console developer account.
2. Review the included original T-piece launcher icon and app name, then prepare store artwork.
3. Prepare the listing, screenshots, support contact, content rating, target
   audience and ads declarations.
4. Publish an accurate app-specific privacy policy and link it inside the app;
   complete Data safety after reviewing the final build and its dependencies.
5. Upload the signed AAB to internal testing, verify native-library 16 KB page
   compatibility, and test real phones, audio interruptions and process recovery.
6. Run the closed test required for your account and address feedback before
   applying for production access. For personal accounts created after
   13 November 2023, the currently documented minimum is 12 opted-in testers
   continuously for 14 days.

Automated tests and a successful bundle build are preparation, not Google Play
approval. Signed-key configuration, physical-device checks, store assets and
privacy disclosures remain required before submission.

Official references checked 29 October 2026:
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://support.google.com/googleplay/android-developer/answer/9842756
- https://support.google.com/googleplay/android-developer/answer/14151465
- https://support.google.com/googleplay/android-developer/answer/9859455
- https://developer.android.com/guide/practices/page-sizes
