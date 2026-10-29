# T-BLOCK

T-BLOCK is an offline falling-block puzzle game for Android.

## v1.5.0: Journey and rewards

- Classic keeps the original endless game and personal best.
- Journey adds 30 stages in three worlds: First Light, Prism Peaks and Cosmic Heights.
- Stages challenge players to clear lines, reach a score or excavate marked rows.
- Earn 1–3 stars based on blocks used. World two requires 12 stars; world three requires 28, plus the preceding stage.
- Completed runs award Block Coins. First stage victories pay 70 + 10 per star; replays pay 12 plus 10 per improved star. Failed stages pay up to 20 coins for cleared lines. Classic pays 5 per line (up to 200 lines) plus up to 20 coins for blocks placed.
- Seven achievements add automatic, one-time coin bonuses.
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

`flutter test` covers gameplay, saves, audio, device layouts, stage objectives and restoration, reward receipts, world gates, achievement bonuses, concurrent shop debits and equipped ownership. UI screenshots are published as the `T-BLOCK-UI-Previews` Actions artifact.
