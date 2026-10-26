//
//  TPAdSurgeRewardedAdapter.m
//

#import "TPAdSurgeRewardedAdapter.h"

#import "TPAdSurgeAdapterHelper.h"

#import <TradPlusAds/TradPlusAdWaterfallItem.h>

#import <AdSurgeSDK/AdSurgeSDK.h>

@interface TPAdSurgeRewardedAdapter () <AdSurgeRewardedAdDelegate>

@property (nonatomic, strong, nullable) AdSurgeRewardedAd *rewardedAd;

@end

@implementation TPAdSurgeRewardedAdapter

#pragma mark - 加载

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    __weak typeof(self) weakSelf = self;
    [self prepareForLoadWithItem:item
                      loadBlock:^(NSString *unitId) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil)
        {
            return;
        }
        strongSelf.rewardedAd = [[AdSurgeRewardedAd alloc] initWithAdUnitIdentifier:unitId];
        strongSelf.rewardedAd.delegate = strongSelf;

        AdSurgeAdConfig *config = [strongSelf adConfigWithFormat:AdSurgeAdFormat.rewarded];
        [strongSelf.rewardedAd loadAd:config];
    }];
}

#pragma mark - 展示

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    UIViewController *viewController = rootViewController ?: [TPAdSurgeAdapterHelper topViewController];
    if (self.rewardedAd.isValid && viewController != nil)
    {
        [self.rewardedAd showAdFromRootViewController:viewController];
    }
    else
    {
        //展示失败
        [self handleAdNotReadyForShow];
    }
}

#pragma mark - 状态

- (BOOL)isReady
{
    return self.rewardedAd != nil && self.rewardedAd.isValid;
}

- (id)getCustomObject
{
    return self.rewardedAd;
}

- (AdSurgePlacementType)adSurgePlacementType
{
    return AdSurgePlacementTypeRewardedVideo;
}

#pragma mark - AdSurgeRewardedAdDelegate

- (void)didLoadAd:(AdSurgeAd *)ad
{
    //加载成功（C2S 取价阶段会在基类里转为回传 ecpm）
    [self handleAdSurgeDidLoadAd:ad];
}

- (void)didFailToLoadAdForAdUnitIdentifier:(NSString *)adUnitIdentifier withError:(AdSurgeError *)error
{
    //加载失败
    [self handleAdSurgeLoadFailure:error];
}

- (void)didDisplayAd:(AdSurgeAd *)ad withError:(AdSurgeError *)error
{
    if (error != nil)
    {
        //展示失败
        [self handleAdSurgeShowFailure:error];
        return;
    }
    //广告展示
    [self AdShow];
}

- (void)didHideAd:(AdSurgeAd *)ad
{
    //广告关闭
    [self AdClose];
}

- (void)didClickAd:(AdSurgeAd *)ad
{
    //广告点击
    [self AdClick];
}

- (void)didRewardUserForAd:(AdSurgeAd *)ad withReward:(AdSurgeReward *)reward
{
    //下发激励
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (reward.label.length > 0)
    {
        info[@"rewardName"] = reward.label;
    }
    info[@"rewardNumber"] = @(reward.amount);
    [self AdRewardedWithInfo:info];
}

- (void)didPayRevenueForAd:(AdSurgeAd *)ad
{
    [TPAdSurgeAdapterHelper log:@"激励视频收益回调 unitId:%@ revenue:%f creativeId:%@",
                                      self.unitId, ad.revenue, ad.creativeId];
}

@end
