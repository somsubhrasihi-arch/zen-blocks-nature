import 'package:flutter_test/flutter_test.dart';
import 'package:zen_blocks/ads_config.dart';

void main() {
  test('test mode overrides a supplied live unit to prevent live traffic', () {
    const config = AdsConfiguration(testMode: true,
      productionRewardedUnit: 'ca-app-pub-8974435266836182/9497612764');
    expect(config.enabled, true);
    expect(config.rewardedUnit, AdsConfiguration.sampleRewardedUnit);
    expect(config.rewardedUnit, isNot(config.productionRewardedUnit));
  });
  test('unconfigured release stays disabled and configured release uses its unit', () {
    expect(const AdsConfiguration(testMode: false).enabled, false);
    const config = AdsConfiguration(testMode: false,
      productionRewardedUnit: 'ca-app-pub-8974435266836182/9497612764');
    expect(config.enabled, true);
    expect(config.rewardedUnit, config.productionRewardedUnit);
  });
}
