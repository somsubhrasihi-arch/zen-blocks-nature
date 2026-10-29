import 'package:flutter/material.dart';
import 'arcade_ui.dart';
import 'campaign.dart';
import 'cosmetic_paint.dart';
import 'customization.dart';
import 'progress_store.dart';

class AdventureHub extends StatefulWidget {
  const AdventureHub({super.key, required this.palette, required this.progress, required this.onStage, this.initialTab = 0});
  final GamePalette palette;
  final ProgressStore progress;
  final ValueChanged<JourneyStage> onStage;
  final int initialTab;
  @override
  State<AdventureHub> createState() => _AdventureHubState();
}

class _AdventureHubState extends State<AdventureHub> {
  late int tab = widget.initialTab;
  bool busy = false;
  GamePalette get p => widget.palette;
  PlayerProgress get data => widget.progress.data;
  Widget button(String text, IconData icon, VoidCallback? action) => ArcadeButton(label: text, icon: icon,
    onPressed: action, accent: p.accent, surface: p.control, primary: true, height: 48);
  Widget card(Widget child) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: p.accent.withValues(alpha: .22))), child: child);
  void message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  Future<void> buy(ShopItem item) async {
    if (busy) return;
    setState(() => busy = true);
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('Unlock ${item.name}?'), content: Text('${item.price} Block Coins\nBalance after purchase: ${data.coins - item.price}'),
      actions: [Row(children: [Expanded(child: button('Cancel', Icons.close_rounded, () => Navigator.pop(context, false))),
        const SizedBox(width: 10), Expanded(child: button('Unlock', Icons.check_rounded, () => Navigator.pop(context, true)))])]));
    if (confirmed != true || !mounted) { if (mounted) setState(() => busy = false); return; }
    try {
      final result = await widget.progress.buy(item.id);
      message(switch (result) { PurchaseResult.purchased => '${item.name} unlocked!',
        PurchaseResult.owned => 'Already in your collection', PurchaseResult.insufficient => 'Earn more coins in Classic or Journey',
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: widget.progress, builder: (context, _) => Scaffold(
    backgroundColor: p.background.first,
    appBar: AppBar(backgroundColor: p.panel, leading: Padding(padding: const EdgeInsets.all(6),
      child: ArcadeIconButton(tooltip: 'Back', icon: Icons.arrow_back_rounded, onPressed: () => Navigator.pop(context), palette: p)), title: Text(['Journey', 'Block Shop', 'Achievements'][tab]),
      actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Row(children: [
        Icon(Icons.monetization_on_rounded, color: p.blocks[1], size: 22), const SizedBox(width: 5),
        Text('${data.coins}', style: const TextStyle(fontWeight: FontWeight.w800)),
      ])))]),
    bottomNavigationBar: NavigationBar(backgroundColor: p.panel, indicatorColor: p.accent.withValues(alpha: .25),
      selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.route_rounded), label: 'Journey'),
        NavigationDestination(icon: Icon(Icons.shopping_bag_rounded), label: 'Shop'),
        NavigationDestination(icon: Icon(Icons.emoji_events_rounded), label: 'Achievements'),
      ]),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: tab == 0 ? journey() : tab == 1 ? shop() : trophies())),
  ));

  List<Widget> journey() => [
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Your next adventure', style: TextStyle(color: p.accent, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text('${data.stars.length}/30 stages complete  •  ${data.totalStars}/90 stars'),
      const SizedBox(height: 12), LinearProgressIndicator(value: data.totalStars/90, color: p.blocks[1], backgroundColor: p.control),
      const SizedBox(height: 12), Text('Complete objectives to earn coins. Use fewer blocks for more stars.', style: TextStyle(color: p.muted, height: 1.4)),
    ])),
    for (var world = 0; world < 3; world++) ...[
      Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WORLD ${world + 1} · ${worldNames[world]}', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, letterSpacing: .8)),
        const SizedBox(height: 4), Text('${worldDescriptions[world]}${world == 0 ? '' : ' · ${[0,12,28][world]} stars to enter'}', style: TextStyle(color: p.muted, fontSize: 12)),
      ])),
      for (final stage in journeyStages.where((s) => s.world == world)) stageCard(stage),
    ],
  ];
  Widget stageCard(JourneyStage stage) {
    final unlocked = data.unlocked(stage), stars = data.stars[stage.id] ?? 0;
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 38, height: 38, alignment: Alignment.center,
        decoration: BoxDecoration(color: p.accent.withValues(alpha: unlocked ? .2 : .07), borderRadius: BorderRadius.circular(12)),
        child: unlocked ? Text('${stage.id}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)) : Icon(Icons.lock_rounded, color: p.muted, size: 20)),
        const SizedBox(width: 12), Expanded(child: Text(stage.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
        for (var i = 0; i < 3; i++) Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, color: i < stars ? p.blocks[1] : p.muted, size: 19),
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
      const SizedBox(height: 8), Text('Earn Block Coins in Classic, Journey, Sprint, Daily Challenge and achievements. Unlock a look, then equip it.', style: TextStyle(color: p.muted, height: 1.4)),
    ])),
    for (final kind in CosmeticKind.values) ...[
      Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 12), child: Text(kind == CosmeticKind.skin ? 'BLOCK SKINS' : 'CLEAR EFFECTS', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, letterSpacing: 1))),
      for (final item in shopItems.where((i) => i.kind == kind)) shopCard(item),
    ],
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('REWARD GUIDE', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 8), Text('Classic: 5 coins per cleared line. Journey: first clears and better stars. Sprint: completion, speed and personal bests. Daily Challenge: 120–180 coins once per UTC day.', style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
      const SizedBox(height: 8), Text('Journey replay and repeat Sprint payouts share a 100-coin daily limit. First clears, star improvements, records and achievements are extra.', style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
    ])),
    Center(child: Text('Progress and coins are saved on this device.', style: TextStyle(color: p.muted, fontSize: 11))),
    const SizedBox(height: 12),
  ];
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
      SizedBox(width: double.infinity, child: button(equipped ? 'Equipped' : owned ? 'Equip' : '${item.price} coins · Unlock',
        equipped ? Icons.check_circle_rounded : owned ? Icons.check_rounded : Icons.monetization_on_rounded,
        busy || equipped ? null : owned ? () => equip(item) : data.coins >= item.price ? () => buy(item) : null)),
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
      Row(children: [Icon(data.earned.contains(a.id) ? Icons.emoji_events_rounded : Icons.workspace_premium_outlined, color: data.earned.contains(a.id) ? p.blocks[1] : p.muted),
        const SizedBox(width: 10), Expanded(child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800))),
        Text('+${a.reward}', style: TextStyle(color: p.blocks[1], fontWeight: FontWeight.w800))]),
      const SizedBox(height: 10), Text(a.detail, style: TextStyle(color: p.muted)), const SizedBox(height: 12),
      LinearProgressIndicator(value: (data.achievementValue(a.id)/a.target).clamp(0, 1).toDouble(), color: p.accent, backgroundColor: p.control),
      const SizedBox(height: 8), Text(data.earned.contains(a.id) ? 'Unlocked · Coins awarded' : '${data.achievementValue(a.id).clamp(0, a.target)}/${a.target}',
        style: TextStyle(color: p.muted, fontSize: 11)),
    ])),
  ];
}
