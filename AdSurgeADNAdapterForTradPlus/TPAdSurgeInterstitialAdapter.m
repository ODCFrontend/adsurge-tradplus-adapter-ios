//
//  TPAdSurgeInterstitialAdapter.m
//

#import "TPAdSurgeInterstitialAdapter.h"

#import "TPAdSurgeAdapterHelper.h"

#import <TradPlusAds/TradPlusAdWaterfallItem.h>

#import <AdSurgeSDK/AdSurgeSDK.h> 

@interface TPAdSurgeInterstitialAdapter () <AdSurgeInterstitialAdDelegate>

@property (nonatomic, strong, nullable) AdSurgeInterstitialAd *interstitialAd;

@end

@implementation TPAdSurgeInterstitialAdapter

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
        strongSelf.interstitialAd = [[AdSurgeInterstitialAd alloc] initWithAdUnitIdentifier:unitId];
        strongSelf.interstitialAd.delegate = strongSelf;

        AdSurgeAdConfig *config = [strongSelf adConfigWithFormat:AdSurgeAdFormat.interstitial];
        [strongSelf.interstitialAd loadAd:config];
    }];
}

#pragma mark - 展示

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    UIViewController *viewController = rootViewController ?: [TPAdSurgeAdapterHelper topViewController];
    if (self.interstitialAd.isValid && viewController != nil)
    {
        [self.interstitialAd showAdFromRootViewController:viewController];
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
    return self.interstitialAd != nil && self.interstitialAd.isValid;
}

- (id)getCustomObject
{
    return self.interstitialAd;
}

- (AdSurgePlacementType)adSurgePlacementType
{
    return AdSurgePlacementTypeInterstitial;
}

#pragma mark - AdSurgeInterstitialAdDelegate

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

- (void)didPayRevenueForAd:(AdSurgeAd *)ad
{
    [TPAdSurgeAdapterHelper log:@"插屏收益回调 unitId:%@ revenue:%f creativeId:%@",
                                      self.unitId, ad.revenue, ad.creativeId];
}

@end
