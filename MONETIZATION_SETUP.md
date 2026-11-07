# T-BLOCK 1.9: Journey, rewards and monetization

## Available immediately

- Original 30 stages preserved; new stages generated on demand without a final level. Ten stages per world, with lines, score and excavation objectives. Difficulty rises within bounds rather than becoming impossible at high level numbers.
- Journey starts with five lives. Entry reserves one, victory returns it, resuming is free, and restarting/abandoning spends the reserved life. One life regenerates per 30 minutes up to five, including while offline.
- Refill to five lives for 150 Block Coins. Daily gift: 25 coins; finish three qualifying runs: 40; clear twenty lines: 60; complete one objective: 50. Claim individually once per UTC day. Guided practice does not count.
- Classic, Sprint and Daily Challenge remain playable without lives.

## Live services are not activated

The default APK has disabled purchase/ad actions with an availability explanation. It makes no payment or advertising requests. Google SDKs are integrated but require the following owner configuration and testing before monetized publication.

### Google Play Billing

Create consumable one-time products `tblock_coins_500` and `tblock_coins_1500` in the app's Play Console. Set local prices there; the UI uses Google's localized prices. Coins buy cosmetics and life refills. There are no subscriptions or automatic renewals.

Provide `--dart-define=PURCHASE_VERIFY_URL=https://YOUR-SERVER/purchases/verify` only after deploying a secure verification service. Request JSON: `productId`, `source`, `verificationData` (Google purchase token). Response on successful verified delivery: `{"verified":true,"productId":"tblock_coins_500","grantId":"stable-unique-server-grant"}`. Invalid/pending purchases must not return verified=true. The grantId must be stable for retries of the same token.

The server must verify package, product, purchase status and token against Google Play Developer API using server-held credentials; prevent token reuse; authenticate the player; bind each token to its owner; enforce idempotent grants; and maintain an authoritative wallet/ledger with reconciliation and refund handling. The current app has no account/cloud-wallet system: implement authenticated requests and wallet reconciliation before turning on paid products for public users. The local wallet and durable receipt set protect normal retries on one installation, not tampering, reinstalling, refunds or cross-device delivery. Do not connect a verification endpoint that merely echoes the request or trusts client-provided product/token data.

Purchase updates are listened to at app startup. Pending/cancelled/error purchases grant nothing. Delivery is saved before explicit consumption and completion. Failed verification/delivery stays pending; use Recover pending purchase or reopen the app to retry. Consumed coin packs are not restored by Google after uninstalling; authoritative account-based wallet recovery is required for public monetization.

Test via a Play internal test track and licensed testers, including cancellation, pending payment, network loss after payment, process death before consumption, duplicate stream events and account changes.

### Optional rewarded ads

Create an Android app and rewarded unit in AdMob. Set `ADMOB_APP_ID` in the build environment before `tools/configure_branding.py` and supply `--dart-define=REWARDED_AD_UNIT_ID=YOUR-UNIT` to Flutter builds. Both identifiers must belong to the same app. Use Google's test IDs for testing only; never publish test ads. The branding script installs Google's sample application ID by default so the SDK can be linked safely while ads are disabled.

The SDK requests consent information and shows the required UMP consent form before requesting an ad. Configure privacy messages in AdMob. Rewards includes an Ad privacy choices entry point. One life is granted only from `onUserEarnedReward`; closing early, failure and no-fill grant nothing. The player explicitly chooses each ad. Consider server-side verification for fraud resistance before launch.

Update the public privacy policy, Play Data safety, ads declaration and target audience settings to match the actual configured services, and retest native alignment after SDK updates. Update the GitHub workflows with the appropriate build-time settings only when ready to activate. Never commit payment credentials or service-account keys.


## AdMob configuration added on 8 November 2026

Publisher identifiers are saved in `config/admob.production.json`. The APK workflow uses `ADS_TEST_MODE=true`, which always selects Google's sample rewarded unit and the branding script's sample App ID. The app labels the action "Watch test ad"; test impressions do not generate publisher earnings. The release bundle workflow remains ad-disabled.

For live activation, first complete account/app readiness, privacy messaging, store disclosures and app-ads.txt setup. In a release build workflow, read ADMOB_APP_ID from config/admob.production.json into the environment before configure_branding.py, and pass `--dart-define-from-file=config/admob.production.json` to flutter build. The App ID cannot be supplied only as a Dart define; it must also be written to AndroidManifest.xml. Do not change the test APK workflow to request live ads during development.

The sample-ad debug mode does not request production consent forms; it cannot select a live ad unit. Production mode updates UMP at launch, checks canRequestAds before loading, and displays the privacy options control when required. Payment activation and its secure backend remain separate unfinished work.

Phone test: enter Journey to reserve a life; open Rewards; tap Watch test ad; complete the rewarded action; confirm one life is added (up to five). Close another ad early and check no life is awarded. A real device/network test is still required; unit tests and APK compilation cannot confirm ad delivery on a phone.


Version 1.9.2 preserves SDK load/show failures and distinguishes request timeouts. Debug builds include expandable Ad test details (stage, unit, error code/domain/message) after a failed request. No error report is automatically sent anywhere. The user can share that text to diagnose device/network failures. SDK initialization and loading are bounded, late loaded ads are disposed, and failed requests release the busy state without granting lives. The sample unit and sample manifest App ID remain unchanged. Runtime ad delivery still requires a phone/network test.
