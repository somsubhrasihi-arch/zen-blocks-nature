/// Debug test builds must never send requests to the publisher's live unit.
class AdsConfiguration {
  const AdsConfiguration({required this.testMode, this.productionRewardedUnit = ''});
  final bool testMode;
  final String productionRewardedUnit;
  static const sampleRewardedUnit = 'ca-app-pub-3940256099942544/5224354917';
  String get rewardedUnit => testMode ? sampleRewardedUnit : productionRewardedUnit;
  bool get enabled => rewardedUnit.isNotEmpty;
}
