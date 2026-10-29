enum StageGoal { lines, score, excavation }

class JourneyStage {
  const JourneyStage(this.id, this.name, this.goal, this.target, this.goldPieces);
  final int id, target, goldPieces;
  final String name;
  final StageGoal goal;
  int get world => (id - 1) ~/ 10;
  int get startLevel => 1 + world * 2;
  int get requiredStars => [0, 12, 28][world];
  int get obstacleCount => goal == StageGoal.excavation ? target : 0;
  String get objective => switch (goal) {
    StageGoal.lines => 'Clear $target lines',
    StageGoal.score => 'Reach $target points',
    StageGoal.excavation => 'Clear $target marked rows',
  };
  String get starHint => '3 stars: $goldPieces blocks or fewer · 2 stars: ${goldPieces * 2} or fewer';
  int starsFor(int pieces) => pieces <= goldPieces ? 3 : pieces <= goldPieces * 2 ? 2 : 1;
}

const worldNames = ['First Light', 'Prism Peaks', 'Cosmic Heights'];
const worldDescriptions = ['Find your rhythm', 'Build with purpose', 'Master the stack'];
const journeyStages = [
  JourneyStage(1, 'First Steps', StageGoal.lines, 2, 10),
  JourneyStage(2, 'Little Wins', StageGoal.score, 400, 15),
  JourneyStage(3, 'Dig In', StageGoal.excavation, 2, 8),
  JourneyStage(4, 'Line Dancer', StageGoal.lines, 4, 16),
  JourneyStage(5, 'Bright Start', StageGoal.score, 800, 22),
  JourneyStage(6, 'Clear a Path', StageGoal.excavation, 3, 12),
  JourneyStage(7, 'Finding Flow', StageGoal.lines, 6, 23),
  JourneyStage(8, 'On a Roll', StageGoal.score, 1200, 28),
  JourneyStage(9, 'Fresh Ground', StageGoal.excavation, 4, 16),
  JourneyStage(10, 'First Summit', StageGoal.lines, 8, 30),
  JourneyStage(11, 'New Heights', StageGoal.lines, 6, 23),
  JourneyStage(12, 'Prism Spark', StageGoal.score, 1800, 22),
  JourneyStage(13, 'Deep Cut', StageGoal.excavation, 4, 16),
  JourneyStage(14, 'Steady Hands', StageGoal.lines, 8, 30),
  JourneyStage(15, 'Brilliance', StageGoal.score, 2600, 28),
  JourneyStage(16, 'Tunnel Vision', StageGoal.excavation, 5, 20),
  JourneyStage(17, 'Skyline', StageGoal.lines, 10, 36),
  JourneyStage(18, 'Crystal Rush', StageGoal.score, 3600, 34),
  JourneyStage(19, 'Breakthrough', StageGoal.excavation, 6, 24),
  JourneyStage(20, 'Prism Crown', StageGoal.lines, 12, 42),
  JourneyStage(21, 'Into Orbit', StageGoal.lines, 10, 36),
  JourneyStage(22, 'Starlight', StageGoal.score, 4000, 28),
  JourneyStage(23, 'Moon Quarry', StageGoal.excavation, 5, 20),
  JourneyStage(24, 'Gravity Well', StageGoal.lines, 12, 42),
  JourneyStage(25, 'Supernova', StageGoal.score, 5500, 34),
  JourneyStage(26, 'Core Sample', StageGoal.excavation, 6, 24),
  JourneyStage(27, 'Constellation', StageGoal.lines, 14, 48),
  JourneyStage(28, 'Event Horizon', StageGoal.score, 7500, 42),
  JourneyStage(29, 'Final Frontier', StageGoal.excavation, 7, 28),
  JourneyStage(30, 'Cosmic Champion', StageGoal.lines, 16, 54),
];
JourneyStage? stageForId(int? id) => id != null && id >= 1 && id <= journeyStages.length ? journeyStages[id - 1] : null;

enum CosmeticKind { skin, effect }
class ShopItem {
  const ShopItem(this.id, this.name, this.description, this.kind, this.price);
  final String id, name, description;
  final CosmeticKind kind;
  final int price;
  // Stable catalog IDs can later map to Play products without changing ownership.
}
const shopItems = [
  ShopItem('skin:glass', 'Neon Glass', 'Luminous blocks with a glossy finish.', CosmeticKind.skin, 0),
  ShopItem('skin:pixel', 'Pixel Pop', 'Crisp corners. Pure arcade nostalgia.', CosmeticKind.skin, 120),
  ShopItem('skin:jelly', 'Jelly Gems', 'Soft curves and a candy-bright shine.', CosmeticKind.skin, 200),
  ShopItem('skin:metal', 'Chrome Club', 'Brushed-metal blocks with bright bevels.', CosmeticKind.skin, 300),
  ShopItem('effect:sparks', 'Stardust', 'A burst of colorful sparks.', CosmeticKind.effect, 0),
  ShopItem('effect:nova', 'Nova Bloom', 'Expanding rings and drifting stars.', CosmeticKind.effect, 240),
  ShopItem('effect:lightning', 'Prism Storm', 'Electric bolts in your theme colors.', CosmeticKind.effect, 320),
];
ShopItem? itemForId(String id) {
  for (final item in shopItems) { if (item.id == id) return item; }
  return null;
}

class Achievement {
  const Achievement(this.id, this.name, this.detail, this.reward, this.target);
  final String id, name, detail;
  final int reward, target;
}
const achievements = [
  Achievement('firstLine', 'The First Spark', 'Clear your first line', 25, 1),
  Achievement('tenRuns', 'Finding Your Flow', 'Finish 10 runs with at least one line cleared', 100, 10),
  Achievement('hundredLines', 'Century Club', 'Clear 100 lines across finished runs', 150, 100),
  Achievement('firstStage', 'Adventure Begins', 'Complete your first Journey stage', 30, 1),
  Achievement('tenStages', 'First Light Champion', 'Complete 10 Journey stages', 150, 10),
  Achievement('allStages', 'Cosmic Champion', 'Complete all 30 Journey stages', 500, 30),
  Achievement('sixtyStars', 'Star Collector', 'Earn 60 Journey stars', 300, 60),
  Achievement('sprintFirst', 'Across the Finish Line', 'Finish your first 40-line Sprint', 75, 1),
  Achievement('sprintSwift', 'Quick Stack', 'Finish Sprint in five minutes or less', 100, 1),
  Achievement('dailyFirst', 'Today’s Triumph', 'Claim your first Daily Challenge reward', 50, 1),
  Achievement('dailySeven', 'Daily Explorer', 'Complete Daily Challenges on seven different days', 150, 7),
  Achievement('streakSeven', 'Seven-Day Spark', 'Reach a seven-day Daily Challenge streak', 200, 7),
];
