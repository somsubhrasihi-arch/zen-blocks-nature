/// Debug test builds must never send requests to the publisher's live unit.
class AdsConfiguration {
  const AdsConfiguration({required this.testMode, this.productionRewardedUnit = '', this.productionCoinUnit = ''});
  final bool testMode;
  final String productionRewardedUnit, productionCoinUnit;
  static const sampleRewardedUnit = 'ca-app-pub-3940256099942544/5224354917';
  String get rewardedUnit => testMode ? sampleRewardedUnit : productionRewardedUnit;
  String get coinRewardedUnit => testMode ? sampleRewardedUnit : productionCoinUnit;
  bool get enabled => rewardedUnit.isNotEmpty;
}
