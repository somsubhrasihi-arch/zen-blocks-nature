# T-BLOCK: player experience and social roadmap

## Review of the current game

The four modes, touch controls, clear objectives, previewable cosmetics and offline saves give the game a useful foundation. The AdGuard incident showed a genuine usability issue: a generic ad failure gave the player no explanation or alternative. The next engagement gap is repetition: fixed daily tasks and a small cosmetic catalog become familiar quickly. Buying coins has limited appeal after the player owns everything. Social competition can create a reason to return, but needs real identities and verified results to support meaningful rankings.

These are product hypotheses, not measured retention or revenue improvements. No telemetry has been added and no uplift is promised. Test the new experience with players before enabling real purchases or adding more ad placements.

## Implemented in 1.10.0

- Ad failures show optional Help, including connection/Private DNS guidance. The app never changes device DNS settings and does not claim to have detected an ad blocker. Failed SDK requests are backed off for 15, 30 and then 60 seconds. Ads do not retry automatically.
- Rewards has Daily and Weekly sections. A rotating focus quest adds a different bonus goal to the existing daily tasks.
- Visit collection awards 100 coins instead of 25 for every seventh collected daily gift. Missed days do not erase progress. Existing Daily Challenge completion streaks remain separate and unchanged.
- Weekly missions: 10 qualifying runs (100 coins), 75 lines (150), and five completed objectives (150). Collect all three rewards for a fixed 100-coin weekly chest. Reset is Monday at 00:00 UTC. The chest has a disclosed, fixed reward and is earned through play.
- Cosmetic collections: Pixel Party and Chrome Storm cost 20% fewer coins than their individual items. Already-owned items are excluded from the price. Ownership and wallet deductions are saved atomically.
- Three new rendered skins: Holo Prism (900 coins), Circuit Core (1,400), Crystal Crown (1,800). Their prices, previews and artwork are available before unlocking. They do not change scores, pieces or difficulty.
- After a finished run with a cleared line, an optional ad offers 25 extra coins. Maximum three per UTC day, once per eligible run. It is separate from the game's earned base payout. No automatic ad pop-up is added.
- Optional life ads are capped at five daily. Successful rewarded ads have a 60-second pause before another request. Waiting for lives, using earned coins, and other game modes remain available. A late-loaded ad is discarded if the player has left the offer screen.
- Friend challenges use date codes. Both players play the same seeded Daily puzzle separately. The device share sheet sends the code and optionally the player's best completion time. Entering a friend's code opens that puzzle; earlier puzzles are practice. Future/invalid dates are rejected.
- The fastest valid completion for each of the last 14 Daily challenges is saved on the device. These are personal records, not an online leaderboard. There is no automatic contact upload or message sending.

## Why these placements are less intrusive

The player chooses an ad when it has a clear benefit: recovering one life or adding a small coin bonus after actual play. There are no mid-game ads, launch ads, compulsory ads, fabricated scarcity, paid randomness, repeated sales pop-ups or purchases required for ranking advantages. Closing an ad early leaves the original run payout intact. Failed requests grant no ad reward and do not remove progress.

Cosmetic collections provide a clear use for coins and show the exact remaining cost. Coin packs are offered through the shop or a player-initiated collection link, rather than interruption dialogs. Real Google Play prices remain store-provided. Purchases are still disabled until the authenticated purchase/wallet backend is finished.

## Monetization activation work still required

The test APK continues to use Google's sample rewarded unit. Production life ads keep the existing publisher unit with reward 1 Life. Coin bonuses require a separate AdMob rewarded unit configured to award **25 Block Coins**; its ID goes in REWARDED_COIN_AD_UNIT_ID. That production ID is deliberately empty, so live coin ads cannot accidentally use the life unit. Account/app readiness, privacy messaging, app-ads.txt and store disclosures still need to be completed before any live activation.

A secure account-based wallet, Google purchase verification, idempotent server delivery, refund reconciliation and recovery across reinstalls are still required before real purchases. Current device-local reward caps and dates are not anti-fraud protection for a public paid economy.

## Next phase: real friend leaderboards

The current sharing feature is a useful first step, but it does not register friends, upload scores or run matches against other devices. Implement the online phase as follows:

1. Create an owned backend project. Firebase Authentication plus Firestore and authenticated server functions is one option; verify current quotas and deployment requirements before choosing the hosting plan.
2. Add sign-in/account linking and cloud save before paid balances or friend rankings. Use public nicknames and generated friend codes. Add/accept requests by code, without requiring address-book access. Include remove/block, account deletion and data deletion.
3. Rank players only within the same challenge ID, seed and rules version. Start with daily friend rankings and personal bests. Show actual players only; never substitute bots without labeling them. Pagination and private friend filters are required.
4. Submit run inputs/replays to a server verifier. Do not trust a submitted coin balance, score or completion time. The verifier checks the seed, input order, legal moves and final objective. Decide and document the timing/pause policy before ranked play.
5. Keep wallet/purchases and competitive performance separate. Cosmetic purchases and ads must not alter the ranked game's pieces, speed, garbage or scoring.
6. Use authenticated read rules and server-only writes for ranked scores and paid balances. Add App Check/rate limits, abuse reporting, audit records and a recovery policy. Finish privacy/store disclosures before turning these on.

Suggested data model: profiles/{uid}, friendInvites/{id}, friendships/{pair}, challenges/{id}, runs/{id}, challengeResults/{challengeId}/players/{uid}, wallets/{uid}, purchaseLedger/{tokenHash}. A friendship pair has one canonical key; only participants can read private friend data. Public profile data should be minimal. This schema is a design proposal, not deployed functionality.

Owner inputs needed for this phase: backend project, sign-in choice, desired leaderboard regions/visibility, production package/signing configuration, and the account/payment setup needed for the chosen backend. No server credentials belong in the Flutter app or Git repository.

## Player versus player progression

First implement asynchronous verified duels: invite by code, same seed/rules, both players finish independently, server compares results, and both can view the result later. This works with a small player population and avoids requiring simultaneous matchmaking. The current manual challenge sharing does not yet provide that verified winner service.

Add live PvP after the online foundation and sufficient active players. Use an authoritative match service with matchmaking/private rooms, deterministic pieces, validated inputs, reconnection and disconnect rules. A short two-minute mode is a reasonable prototype. A server-controlled garbage-line system can add interaction. Keep the normal block controls and show an opponent miniature without shrinking the main board too far. Do not grant competitive advantages for purchases or ads; ad offers belong after the match.

## What to improve after testing

- Add distinct weekly seeded game events and eventually a small season of earnable cosmetics; new content needs a sustainable publishing schedule.
- Review difficulty from actual stage completion/retry rates. Avoid increasing difficulty just to sell lives.
- Add optional reminders only after the player chooses them, with a clear off switch and quiet hours.
- If analytics are later approved and disclosed, measure D1/D7 return rate, quest participation, stage retries, rewarded-ad opt-in/completion/failure, pack conversion, and player complaints. Avoid revenue-only optimization. Use player feedback alongside aggregate metrics.
- Expand the cosmetic catalog before repeatedly raising coin rewards. More free currency alone does not create long-term content or purchase value.

## Validation

The automated suite covers existing gameplay and layouts plus visit gaps/reloads, weekly rollover and duplicate claims, ad reward receipts/caps/duplicate SDK callbacks, early ad closure, navigation during ad loading, bundle ownership and concurrent debits, daily code validation, fastest-record persistence and distinct cosmetic rendering. New reward and friend screens are captured in the UI preview artifact. Phone checks are still needed for the native share sheet, AdMob creative delivery and readability across Android font sizes. Live multiplayer, rankings, paid delivery and production ad revenue are not validated by these tests.
