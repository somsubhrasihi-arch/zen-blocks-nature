# T-BLOCK launch preparation

Current candidate: **1.8.0+11**. Android identity: `com.zenblocks.nature.zen_blocks`.

The game has Classic, 30-stage Journey, Sprint, Daily Challenge, earned coins, cosmetics, guided practice, local recovery copies, privacy information and open-source licences. It has no account system, advertising, analytics or real-money purchases.

## Build artifacts

- **Build Zen Blocks Android APK** preserves the installable test APK and the `ZenBlocks-Nature-Android-APK` artifact. Flutter is pinned to 3.47.8 to match the release job.
- **Check Play Store bundle** builds an optimized AAB using target API 36 and verifies signing state. Push builds produce `ZenBlocks-UNSIGNED-Release-Preview`, which is not a signed Play upload.
- The release job checks 64-bit ELF PT_LOAD segments for at least 16 KB alignment and uploads `T-BLOCK-Release-Checks`. This does not replace APK zip-alignment checks or testing on a 16 KB Android device/emulator through Play.

## Signed upload bundle

Create and securely retain an upload keystore. Add these GitHub Actions secrets outside the repository:

| Secret | Value |
| --- | --- |
| `ZEN_UPLOAD_KEYSTORE_BASE64` | Base64-encoded upload keystore |
| `ZEN_UPLOAD_STORE_PASSWORD` | Keystore password |
| `ZEN_UPLOAD_KEY_ALIAS` | Upload alias |
| `ZEN_UPLOAD_KEY_PASSWORD` | Key password |

Run **Check Play Store bundle** manually with `sign_release` enabled. It produces `ZenBlocks-PlayStore-AAB`. The job fails if credentials are missing; it does not fall back to debug signing. It removes its temporary keystore. The signed flow still needs validation with your real upload key. No store publication is automatic.

## Play Console setup

1. Create/verify the developer account and confirm the permanent package ID.
2. Set the store title, developer/support details, target audience, content rating and ads declaration accurately. Review the listing copy in `PLAY_STORE_LISTING.md`.
3. Use the public app-specific policy at https://github.com/somsubhrasihi-arch/zen-blocks-nature/blob/main/PRIVACY_POLICY.md. It is also available offline inside **Settings > About & privacy**. Confirm the developer/support mechanism matches the Play listing before submission.
4. Complete Data safety based on the final release and every included SDK. No developer-side data collection is implemented in this candidate; browser visits and Android system backups are explained in the policy. Apps exclusively in internal testing are exempt from the Data safety form; closed, open and production tracks are not.
5. Upload a signed AAB to internal testing. Review the Play pre-launch report and install the Play-delivered build on real devices. Verify 16 KB compatibility, audio interruptions, gestures, large text, process-kill recovery, offline mode, Daily reset and upgrades.
6. If this is a personal developer account created after 13 November 2023, run a closed test with at least 12 opted-in testers continuously for 14 days, then apply for production access. Meeting that minimum is not automatic production approval.
7. Review actual tester feedback and release only after the required Play Console checks are complete.

Debug APKs and Play-distributed builds use different signing identities. Testers moving from a debug install may need a clean installation; local recovery copies are not cross-install migration or cloud sync. Protect the production signing setup before promising upgrade continuity.

Official requirements rechecked **8 November 2026**:
- Target API 36: https://support.google.com/googleplay/android-developer/answer/11926878
- Privacy policy: https://support.google.com/googleplay/android-developer/answer/10144311
- Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Testing: https://support.google.com/googleplay/android-developer/answer/14151465
- Native page sizes: https://developer.android.com/guide/practices/page-sizes
