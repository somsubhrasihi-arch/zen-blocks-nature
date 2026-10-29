# T-BLOCK

T-BLOCK is an offline falling-block puzzle game for Android.

## v1.6.0: Sprint, Daily Challenge and rewards

- Classic keeps the original endless game and personal best.
- Journey adds 30 stages in three worlds: First Light, Prism Peaks and Cosmic Heights.
- Stages challenge players to clear lines, reach a score or excavate marked rows.
- Earn 1–3 stars based on blocks used. World two requires 12 stars; world three requires 28, plus the preceding stage.
- Sprint races to 40 lines, tracks active-play time and saves a personal best. Pausing, returning home and app backgrounding stop the timer. Resume keeps the accumulated time.
- Daily Challenge rotates line, score and excavation goals at 00:00 UTC. A date-seeded bag gives everyone the same sequence, including after saving and resuming. Past saved daily challenges remain playable as practice.
- Classic pays 5 coins per cleared line, up to 1,000 per finished run. Dropping blocks without clearing lines no longer awards coins or advances the ten-run achievement.
- First Journey victories pay 70 + 10 per star. Replays pay 12 plus 10 per improved star. Failed Journey runs can earn up to 20 for cleared lines.
- First Sprint finish pays 60 plus a speed bonus: 40 within 3 minutes, 25 within 5, or 10 within 8. Later finishes use the shared replay pool. Improving a previous record by at least one second earns 15 extra coins.
- Journey replays, Journey consolation payouts and repeat Sprint payouts share a 100-coin UTC-day pool. First victories, improved stars, Sprint record bonuses, Daily rewards and achievements do not use that pool.
- Daily rewards pay 120 once per UTC day, plus 10 per consecutive completed day up to a 60-coin bonus. Missing a day resets the active streak; previously earned coins remain. Daily achievements reward a first completion, seven distinct days and a seven-day streak.
- The daily claim date and replay-pool date move forward only. Reopening the app, replaying with another run receipt, or moving the device date backward does not reissue those rewards. This is an offline economy using the device UTC clock; trusted server time and verified accounts are required before money or competitive online rewards are introduced.
- End-of-run summaries show the coin breakdown and the reason when a run is practice-only.
- Twelve achievements add automatic, one-time coin bonuses.
- The shop offers Pixel Pop, Jelly Gems and Chrome Club skins, plus Nova Bloom and Prism Storm clear effects. Neon Glass and Stardust remain free.
- Purchases require confirmation; ownership, balance and reward receipts are stored together. Owned items can be equipped at no extra charge.
- Original themes, soundtracks, settings and saves remain available. Journey sessions resume in the correct stage.

Progress is stored on the device; uninstalling or clearing app data removes it. This release uses earned coins only. There are no ads, real-money payments or cloud accounts.

## Android builds

The existing **Build Zen Blocks Android APK** workflow creates `app-debug.apk`. Download the `ZenBlocks-Nature-Android-APK` artifact from the latest successful Actions run and unzip it on your phone. The app display name is T-BLOCK; its Android application ID is unchanged.

The **Check Play Store bundle** workflow creates an unsigned preview on pushes. See [PLAY_STORE_RELEASE.md](PLAY_STORE_RELEASE.md) for signing and release setup.

## Future payments

Catalog IDs such as `skin:pixel` are stable ownership IDs, separate from display names and coin prices. A future Play product can grant the same entitlement without replacing existing earned ownership. Before introducing purchases, add Play Billing, backend purchase verification and an account-backed entitlement ledger; the current local earned-coin wallet is not a paid-currency ledger. Restore non-consumable ownership and handle cancellations, pending purchases and refunds before shipping billing.

## Validation

`flutter test` covers gameplay, saves, audio, device layouts, stage objectives and restoration, Sprint timing and records, deterministic Daily bags, UTC rollover and streaks, duplicate Daily claims, replay limits, legacy wallet migration, reward receipts, world gates, achievement bonuses, concurrent shop debits and equipped ownership. UI screenshots are published as the `T-BLOCK-UI-Previews` Actions artifact.
