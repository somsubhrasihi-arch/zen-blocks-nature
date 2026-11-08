import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'monetization.dart';
import 'engagement.dart';
import 'ad_help.dart';
import 'play_modes.dart';
import 'arcade_ui.dart';
import 'campaign.dart';
import 'cosmetic_paint.dart';
import 'customization.dart';
import 'playful_style.dart';
import 'progress_store.dart';
import 'cosmetic_preview.dart';

class AdventureHub extends StatefulWidget {
  const AdventureHub({super.key, required this.palette, required this.progress, required this.onStage, this.monetization, this.initialTab = 0, this.reduceMotion = false});
  final GamePalette palette;
  final ProgressStore progress;
  final ValueChanged<JourneyStage> onStage;
  final Monetization? monetization;
  final int initialTab;
  final bool reduceMotion;
  @override
  State<AdventureHub> createState() => _AdventureHubState();
}

class _AdventureHubState extends State<AdventureHub> {
  late int tab = widget.initialTab;
  bool busy = false;
  String rewardPeriod = 'Daily';
  Timer? clock;
  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted && tab == 3) setState(() {}); });
    widget.monetization?.addListener(changed);
  }
  void changed() { if (mounted) setState(() {}); }
  @override
  void dispose() { clock?.cancel(); widget.monetization?.removeListener(changed); super.dispose(); }
  Future<void> perform(Future<Object?> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try { await action(); } catch (_) { message('Could not save. Please try again.'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  late int selectedWorld = widget.progress.data.recommendedStage?.world ?? 0;
  String shopFilter = 'All';
  GamePalette get p => widget.palette.playful;
  PlayerProgress get data => widget.progress.data;
  Widget button(String text, IconData icon, VoidCallback? action) => ArcadeButton(label: text, icon: icon,
    onPressed: action, accent: p.accent, surface: p.control, primary: true, height: 48);
  Widget card(Widget child) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFE8DEEF)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .10), offset: const Offset(0, 4))]), child: child);
  void message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  void preview(ShopItem item) => showModalBottomSheet<void>(context: context, useSafeArea: true,
    isScrollControlled: true, backgroundColor: p.panel, showDragHandle: true,
    builder: (context) => SafeArea(child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 12),
        CosmeticLivePreview(item: item, palette: p, skin: data.skin, reduceMotion: widget.reduceMotion),
        const SizedBox(height: 12), Text(item.description, style: TextStyle(color: p.muted, height: 1.5)),
        const SizedBox(height: 16), SizedBox(width: double.infinity, child: button('Close preview', Icons.check_rounded, () => Navigator.pop(context))),
      ])))));

  Future<void> buy(ShopItem item) async {
    if (busy) return;
    setState(() => busy = true);
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('Unlock ${item.name}?'), scrollable: true,
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        CosmeticLivePreview(item: item, palette: p, skin: data.skin, reduceMotion: widget.reduceMotion),
        const SizedBox(height: 12), Text('${item.price} Block Coins\nBalance after purchase: ${data.coins-item.price}'),
      ]),
      actions: [Row(children: [Expanded(child: button('Cancel', Icons.close_rounded, () => Navigator.pop(context, false))),
        const SizedBox(width: 10), Expanded(child: button('Unlock & equip', Icons.check_rounded, () => Navigator.pop(context, true)))])]));
    if (confirmed != true || !mounted) { if (mounted) setState(() => busy = false); return; }
    try {
      final result = await widget.progress.buy(item.id, equip: true);
      message(switch (result) { PurchaseResult.purchased => '${item.name} equipped',
        PurchaseResult.owned => 'Already in your collection', PurchaseResult.insufficient => 'Earn more coins by finishing games and challenges',
        PurchaseResult.unavailable => 'This item is unavailable' });
    } catch (_) { message('Could not save your purchase. Please try again.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> equip(ShopItem item) async {
    setState(() => busy = true);
    try { await widget.progress.equip(item.id); }
    catch (_) { message('Could not save your selection. Please try again.'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> buyBundle(ShopBundle bundle) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final cost = bundle.priceFor(data.owned);
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: Text('Unlock ${bundle.name}?'), scrollable: true,
        content: Text('${bundle.items.where((id) => !data.owned.contains(id)).map((id) => itemForId(id)!.name).join(' + ')}\n\n$cost Block Coins\nBalance after purchase: ${data.coins - cost}'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unlock bundle'))]));
      if (confirmed != true || !mounted) return;
      final result = await widget.progress.buyBundle(bundle.id);
      message(result == PurchaseResult.purchased ? 'Bundle added! Equip your new looks from your collection.' : result == PurchaseResult.owned ? 'Already in your collection' : 'Not enough coins for this bundle.');
    } catch (_) { message('Could not save your bundle. Please try again.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  void coinPacks() => showModalBottomSheet<void>(context: context, backgroundColor: p.panel,
    useSafeArea: true, isScrollControlled: true, showDragHandle: true,
    builder: (context) => AnimatedBuilder(animation: widget.monetization ?? widget.progress,
      builder: (_, child) => SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, children: storeCards()))));
  List<Widget> bundles() => [
    Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('STYLE COLLECTIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
    for (final bundle in shopBundles.where((b) => shopFilter == 'Owned' ? b.priceFor(data.owned) == 0 : shopFilter == 'Affordable' ? b.priceFor(data.owned) > 0 && b.priceFor(data.owned) <= data.coins : true)) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(bundle.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text(bundle.items.map((id) => itemForId(id)!.name).join(' + '), style: TextStyle(color: p.muted)),
      const SizedBox(height: 10), Text(bundle.priceFor(data.owned) == 0 ? 'Collection complete' : '${bundle.priceFor(data.owned)} coins together · ${bundle.individualPrice(data.owned)} individually', style: TextStyle(color: buddyGold)),
      const SizedBox(height: 8), Text('20% less than the individual coin prices. You only pay for items you do not own.', style: TextStyle(color: p.muted, fontSize: 12)),
      const SizedBox(height: 12), button(bundle.priceFor(data.owned) == 0 ? 'Owned' : 'Unlock collection', Icons.collections_rounded,
        busy || bundle.priceFor(data.owned) == 0 || data.coins < bundle.priceFor(data.owned) ? null : () => buyBundle(bundle)),
      if (data.coins < bundle.priceFor(data.owned)) TextButton(onPressed: coinPacks, child: const Text('View coin packs')),
    ])),
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: widget.progress, builder: (context, _) => Theme(data: buddyTheme(p), child: Scaffold(
    backgroundColor: p.background.first,
    appBar: AppBar(backgroundColor: p.panel, leading: Padding(padding: const EdgeInsets.all(6),
      child: ArcadeIconButton(tooltip: 'Back', icon: Icons.arrow_back_rounded, onPressed: () => Navigator.pop(context), palette: p)), title: Text(['Journey', 'Block Shop', 'Achievements', 'Daily rewards & lives'][tab]),
      actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Row(children: [
        Icon(Icons.monetization_on_rounded, color: buddyGold, size: 22), const SizedBox(width: 5),
        Text('${data.coins}', style: const TextStyle(fontWeight: FontWeight.w800)),
      ])))]),
    bottomNavigationBar: NavigationBar(backgroundColor: p.panel, indicatorColor: p.accent.withValues(alpha: .25),
      selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.route_rounded), label: 'Journey'),
        NavigationDestination(icon: Icon(Icons.shopping_bag_rounded), label: 'Shop'),
        NavigationDestination(icon: Icon(Icons.emoji_events_rounded), label: 'Achievements'),
        NavigationDestination(icon: Icon(Icons.card_giftcard_rounded), label: 'Rewards'),
      ]),
    body: SafeArea(child: ListView(key: ValueKey('hub-$tab-$selectedWorld'), padding: const EdgeInsets.all(16), children: tab == 0 ? journey() : tab == 1 ? shop() : tab == 2 ? trophies() : rewards())),
  )));

  List<Widget> journey() => [
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Your next adventure', style: TextStyle(color: p.accent, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text('${data.stars.length} stages complete  •  ${data.totalStars} stars'),
      const SizedBox(height: 12), LinearProgressIndicator(value: (data.stars.keys.where((id) => (id - 1) ~/ 10 == selectedWorld).length / 10).clamp(0, 1), color: buddyGold, backgroundColor: p.control),
      const SizedBox(height: 12), Text('Complete objectives to earn coins. Use fewer blocks for more stars.', style: TextStyle(color: p.muted, height: 1.4)),
      if (data.recommendedStage != null) ...[const SizedBox(height: 12),
        Text('Up next: Stage ${data.recommendedStage!.id} · ${data.recommendedStage!.name}', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10), SizedBox(width: double.infinity, child: button('Continue Journey', Icons.play_arrow_rounded, () {
          final stage = data.recommendedStage!; Navigator.pop(context); widget.onStage(stage);
        })),
      ],
    ])),
    Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Wrap(spacing: 6, runSpacing: 6, children: [
      for (final i in ({0, 1, 2, if (selectedWorld > 0) selectedWorld - 1, selectedWorld, selectedWorld + 1, data.recommendedStage?.world ?? 0}.toList()..sort())) ChoiceChip(label: Text(worldName(i)), selected: selectedWorld == i,
        selectedColor: p.accent.withValues(alpha: .25), onSelected: (_) => setState(() => selectedWorld=i)),
    ])),
    for (final world in [selectedWorld]) ...[
      Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WORLD ${world + 1} · ${worldName(world)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: .8)),
        const SizedBox(height: 4), Text('${world < 3 ? worldDescriptions[world] : 'The adventure continues'}${world == 0 ? '' : ' · ${world < 3 ? [0,12,28][world] : 28} stars to enter'}', style: TextStyle(color: Colors.white, fontSize: 12)),
      ])),
      for (final stage in stagesInWorld(world)) stageCard(stage),
    ],
  ];
  Widget stageCard(JourneyStage stage) {
    final unlocked = data.unlocked(stage), stars = data.stars[stage.id] ?? 0;
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 38, height: 38, alignment: Alignment.center,
        decoration: BoxDecoration(color: p.accent.withValues(alpha: unlocked ? .2 : .07), borderRadius: BorderRadius.circular(12)),
        child: unlocked ? Text('${stage.id}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)) : Icon(Icons.lock_rounded, color: p.muted, size: 20)),
        const SizedBox(width: 12), Expanded(child: Text(stage.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
        for (var i = 0; i < 3; i++) Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, color: i < stars ? buddyGold : p.muted, size: 19),
      ]),
      const SizedBox(height: 12), Text(stage.objective, style: TextStyle(color: p.accent, fontWeight: FontWeight.w600)),
      const SizedBox(height: 5), Text(stage.starHint, style: TextStyle(color: p.muted, fontSize: 11, height: 1.4)),
      const SizedBox(height: 12),
      if (unlocked) SizedBox(width: double.infinity, child: button(stars == 0 ? 'Play stage ${stage.id}' : 'Replay stage ${stage.id}', Icons.play_arrow_rounded, () {
        Navigator.pop(context); widget.onStage(stage);
      })) else Text(data.totalStars < stage.requiredStars ? 'Earn ${stage.requiredStars - data.totalStars} more stars to enter this world' : 'Complete stage ${stage.id - 1} to unlock',
        style: TextStyle(color: p.muted, fontSize: 12)),
    ]));
  }
  List<Widget> shop() => [
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Make it yours', style: TextStyle(color: p.accent, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text('Preview a look. Unlock it with Block Coins and wear it straight away.', style: TextStyle(color: p.muted, height: 1.4)),
      const SizedBox(height: 12), Wrap(spacing: 6, runSpacing: 6, children: [
        for (final filter in ['All','Owned','Affordable']) ChoiceChip(label: Text(filter), selected: shopFilter==filter,
          selectedColor: p.accent.withValues(alpha: .25), onSelected: (_) => setState(() => shopFilter=filter)),
      ]),
    ])),
    for (final kind in CosmeticKind.values) ...[
      Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 12), child: Text(kind == CosmeticKind.skin ? 'BLOCK SKINS' : 'CLEAR EFFECTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1))),
      for (final item in shopItems.where((i) => i.kind == kind && visible(i))) shopCard(item),
    ],
    if (!shopItems.any(visible)) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('A little more play, a new look', style: TextStyle(color: p.accent, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text('No new items fit this filter yet. Finish a game or Daily Challenge to earn coins, or browse All to preview your next unlock.', style: TextStyle(color:p.muted,height:1.5)),
    ])),
    ...bundles(),
    ...storeCards(),
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('REWARD GUIDE', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 8), Text('Classic: 5 coins per cleared line. Journey: first clears and better stars. Sprint: completion, speed and personal bests. Daily Challenge: 120–180 coins once per UTC day.', style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
      const SizedBox(height: 8), Text('Journey replay and repeat Sprint payouts share a 100-coin daily limit. First clears, star improvements, records and achievements are extra.', style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
    ])),
    Center(child: Text('Progress and coins are saved on this device.', style: TextStyle(color: Colors.white, fontSize: 11))),
    const SizedBox(height: 12),
  ];
  List<Widget> storeCards() {
    final service = widget.monetization;
    return [card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Coin packs', style: TextStyle(color: p.accent, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text('Use coins for new looks or a Journey life refill. All purchases are optional.', style: TextStyle(color: p.muted)),
      const SizedBox(height: 12),
      for (final entry in (const {'tblock_coins_500': 500, 'tblock_coins_1500': 1500}).entries) ...[
        button('${entry.value} coins · ${service?.products[entry.key]?.price ?? 'Unavailable'}', Icons.shopping_bag_rounded,
          service == null || service.busy || !service.products.containsKey(entry.key) ? null : () => perform(() => service.buy(service.products[entry.key]!))),
        const SizedBox(height: 8),
      ],
      Text(service?.status ?? 'Purchases are not available in this build.', style: TextStyle(color: p.muted, fontSize: 12)),
      if (service?.billingConfigured == true) ...[const SizedBox(height: 8), button('Recover pending purchase', Icons.restore_rounded,
        busy || service!.busy ? null : () => perform(service.recover))],
    ]))];
  }
  List<Widget> rewards() {
    final now = widget.progress.now;
    final lives = data.livesAt(now), remaining = data.nextLifeIn(now);
    final today = utcDay(now), current = data.activityDay == today;
    final service = widget.monetization;
    final retry = service?.retryIn.inSeconds ?? 0;
    final lifeCap = data.adCount(today) >= 5;
    final stamps = data.giftDays == 0 ? 0 : data.giftDays % 7 == 0 ? 7 : data.giftDays % 7;
    return [
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Journey lives · $lives / 5', style: TextStyle(color: p.accent, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10), Row(children: [for (var i = 0; i < 5; i++) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(i < lives ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: p.blocks[4], size: 30))]),
        const SizedBox(height: 10), Text(lives == 5 ? 'Lives full. Your next adventure is ready.' : 'Next free life in ${remaining.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}', style: TextStyle(color: p.muted)),
        const SizedBox(height: 8), Text('A life is reserved when a stage starts and returned when you win. Resume for free; a restart uses another life. Free lives refill every 30 minutes. Other modes need no lives.', style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
        const SizedBox(height: 12), button('Refill to 5 · 150 coins', Icons.favorite_rounded, busy || lives == 5 || data.coins < 150 ? null : () => perform(() => widget.progress.refillWithCoins())),
        const SizedBox(height: 8), button(lifeCap ? 'Today’s ad lives collected' : retry > 0 ? 'Retry ad in ${retry + 1}s' : service?.hasAdFailure == true ? 'Retry ad · +1 life' : service?.usingTestAds == true ? 'Watch test ad · +1 life' : 'Watch an ad · +1 life', Icons.ondemand_video_rounded,
          busy || lives == 5 || lifeCap || service == null || !service.adsConfigured || !service.canRequestAd ? null : () => perform(() => service.watchForLife(canShow: () => mounted && tab == 3 && ModalRoute.of(context)?.isCurrent == true))),
        const SizedBox(height: 8), Text(service?.adsConfigured == true ? service!.adStatus : 'Rewarded ads are not available in this build.', style: TextStyle(color: p.muted, fontSize: 12)),
        const SizedBox(height: 6), Text('${data.adCount(today)}/5 optional ad lives collected today', style: TextStyle(color: p.muted, fontSize: 11)),
        if (service?.hasAdFailure == true) TextButton(onPressed: () => showAdHelp(context), child: const Text('Help with ads')),
        if (kDebugMode && service?.adDiagnostic != null) ExpansionTile(title: const Text('Ad test details'), childrenPadding: const EdgeInsets.all(12),
          children: [SelectableText(service!.adDiagnostic!, style: TextStyle(color: p.muted, fontSize: 12))]),
        if (service?.privacyOptionsRequired == true) TextButton(onPressed: service!.privacyOptions, child: const Text('Ad privacy choices')),
        TextButton(onPressed: coinPacks, child: const Text('Get coin packs')),
      ])),
      Wrap(spacing: 10, children: [for (final period in ['Daily', 'Weekly']) ChoiceChip(label: Text(period), selected: rewardPeriod == period,
        selectedColor: p.accent.withValues(alpha: .25), onSelected: (_) => setState(() => rewardPeriod = period))]),
      const SizedBox(height: 12),
      if (rewardPeriod == 'Daily') ...[
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Visit collection', style: TextStyle(color: p.accent, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12), Row(children: [for (var i = 1; i <= 7; i++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
            child: CircleAvatar(radius: 16, backgroundColor: i <= stamps ? p.accent : p.control,
              child: Text('$i', style: TextStyle(color: i <= stamps ? Colors.white : p.muted, fontWeight: FontWeight.w800)))))]),
          const SizedBox(height: 12), Text('Every 7th visit gift is 100 coins. Missed days keep your collection progress. Claim once per UTC day.', style: TextStyle(color: p.muted, height: 1.4)),
        ])),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Daily activities', style: TextStyle(color: p.accent, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8), Text('New rewards and a rotating focus quest at 00:00 UTC. Practice lessons do not count.', style: TextStyle(color: p.muted, height: 1.4)),
        ])),
        for (final task in dailyActivitiesFor(today)) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8), Text('+${task.id == 'visit' ? visitReward(data.giftDays - (current && data.activityClaims.contains('visit') ? 1 : 0)) : task.coins} coins${task.target == 0 ? '' : ' · ${(current ? data.activityValue(task.counter) : 0).clamp(0, task.target)}/${task.target}'}', style: TextStyle(color: buddyGold)),
          const SizedBox(height: 12), button(current && data.activityClaims.contains(task.id) ? 'Claimed' : 'Claim reward', Icons.card_giftcard_rounded,
            busy || (current && data.activityClaims.contains(task.id)) || (current ? data.activityValue(task.counter) : 0) < task.target ? null : () => perform(() => widget.progress.claimActivity(task.id))),
        ])),
      ] else ...weeklyCards(),
    ];
  }
  List<Widget> weeklyCards() {
    final week = utcWeek(widget.progress.now), current = data.week == utcWeek(widget.progress.now);
    final completed = current ? weeklyMissions.where((m) => data.weeklyClaims.contains(m.id)).length : 0;
    return [
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('This week’s quest', style: TextStyle(color: p.accent, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), Text('Week of $week · Resets Monday at 00:00 UTC. Play any mode and collect all three rewards to open a 100-coin chest.', style: TextStyle(color: p.muted, height: 1.4)),
      ])),
      for (final mission in weeklyMissions) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(mission.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10), LinearProgressIndicator(value: ((current ? data.weeklyValue(mission.id) : 0) / mission.target).clamp(0, 1), color: p.accent, backgroundColor: p.control),
        const SizedBox(height: 8), Text('${(current ? data.weeklyValue(mission.id) : 0).clamp(0, mission.target)}/${mission.target} · +${mission.coins} coins'),
        const SizedBox(height: 12), button(current && data.weeklyClaims.contains(mission.id) ? 'Collected' : 'Claim weekly reward', Icons.card_giftcard_rounded,
          busy || !current || data.weeklyClaims.contains(mission.id) || data.weeklyValue(mission.id) < mission.target ? null : () => perform(() => widget.progress.claimWeekly(mission.id))),
      ])),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Weekly chest · +100 coins', style: TextStyle(color: buddyGold, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), Text('$completed/3 mission rewards collected'), const SizedBox(height: 12),
        button(current && data.weeklyClaims.contains('chest') ? 'Chest collected' : 'Open weekly chest', Icons.inventory_2_rounded,
          busy || completed < 3 || data.weeklyClaims.contains('chest') ? null : () => perform(() => widget.progress.claimWeekly('chest'))),
      ])),
    ];
  }
  bool visible(ShopItem item) => switch (shopFilter) {
    'Owned' => data.owned.contains(item.id),
    'Affordable' => !data.owned.contains(item.id) && item.price <= data.coins,
    _ => true,
  };
  Widget shopCard(ShopItem item) {
    final owned = data.owned.contains(item.id);
    final equipped = item.id == 'skin:${data.skin}' || item.id == 'effect:${data.effect}';
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 84, height: 72, decoration: BoxDecoration(color: p.board, borderRadius: BorderRadius.circular(16)),
        child: CustomPaint(painter: CosmeticPreviewPainter(item.id, p.blocks))), const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 6),
          Text(item.description, style: TextStyle(color: p.muted, fontSize: 12, height: 1.4)),
        ])),
      ]), const SizedBox(height: 14),
      Row(children: [SizedBox(width: 100, child: button('Preview', Icons.visibility_rounded, () => preview(item))), const SizedBox(width: 10),
        Expanded(child: equipped ? Container(height: 43, alignment: Alignment.center,
          decoration: BoxDecoration(color:p.accent.withValues(alpha:.12),borderRadius:BorderRadius.circular(16),border:Border.all(color:p.accent.withValues(alpha:.4))),
          child: Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.check_circle_rounded,color:p.accent,size:18),const SizedBox(width:6),
            Text('Equipped',style:TextStyle(color:p.accent,fontWeight:FontWeight.w700))]))
          : button(owned ? 'Equip' : '${item.price} coins · Unlock', owned ? Icons.check_rounded : Icons.monetization_on_rounded,
            busy ? null : owned ? () => equip(item) : data.coins >= item.price ? () => buy(item) : null)),
      ]),
      if (!owned && data.coins < item.price) Center(child: Padding(padding: const EdgeInsets.only(top: 6),
        child: Text('${item.price-data.coins} more coins needed', style: TextStyle(color: p.muted, fontSize: 11)))),
    ]));
  }
  List<Widget> trophies() => [
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Small wins. Big milestones.', style: TextStyle(color: p.accent, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text('${data.earned.length}/${achievements.length} unlocked · Rewards arrive automatically after a finished run.', style: TextStyle(color: p.muted, height: 1.4)),
    ])),
    for (final a in achievements) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(data.earned.contains(a.id) ? Icons.emoji_events_rounded : Icons.workspace_premium_outlined, color: data.earned.contains(a.id) ? buddyGold : p.muted),
        const SizedBox(width: 10), Expanded(child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800))),
        Text('+${a.reward}', style: TextStyle(color: buddyGold, fontWeight: FontWeight.w800))]),
      const SizedBox(height: 10), Text(a.detail, style: TextStyle(color: p.muted)), const SizedBox(height: 12),
      LinearProgressIndicator(value: (data.achievementValue(a.id)/a.target).clamp(0, 1).toDouble(), color: p.accent, backgroundColor: p.control),
      const SizedBox(height: 8), Text(data.earned.contains(a.id) ? 'Unlocked · Coins awarded' : '${data.achievementValue(a.id).clamp(0, a.target)}/${a.target}',
        style: TextStyle(color: p.muted, fontSize: 11)),
    ])),
  ];
}
