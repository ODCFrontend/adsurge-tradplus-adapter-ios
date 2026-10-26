//
//  TPAdSurgeSplashAdapter.m
//

#import "TPAdSurgeSplashAdapter.h"

#import "TPAdSurgeAdapterHelper.h"

#import <TradPlusAds/TradPlusAdWaterfallItem.h>

#import <AdSurgeSDK/AdSurgeSDK.h>

@interface TPAdSurgeSplashAdapter () <AdSurgeAppOpenAdDelegate>

@property (nonatomic, strong, nullable) AdSurgeAppOpenAd *appOpenAd;

@end

@implementation TPAdSurgeSplashAdapter

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
        strongSelf.appOpenAd = [[AdSurgeAppOpenAd alloc] initWithAdUnitIdentifier:unitId];
        strongSelf.appOpenAd.delegate = strongSelf;

        //开屏广告由 AdSurge SDK 默认静音
        AdSurgeAdConfig *config = [strongSelf adConfigWithFormat:AdSurgeAdFormat.appOpen];
        [strongSelf.appOpenAd loadAd:config];
    }];
}

#pragma mark - 展示

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    if (bottomView != nil)
    {
        [TPAdSurgeAdapterHelper log:@"AdSurge 开屏不支持 bottomView，已忽略"];
    }

    UIViewController *rootViewController = window.rootViewController ?: [TPAdSurgeAdapterHelper topViewController];
    if (self.appOpenAd.isValid && rootViewController != nil)
    {
        [self.appOpenAd showAdFromRootViewController:rootViewController];
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
    return self.appOpenAd != nil && self.appOpenAd.isValid;
}

- (id)getCustomObject
{
    return self.appOpenAd;
}

- (AdSurgePlacementType)adSurgePlacementType
{
    return AdSurgePlacementTypeAppOpen;
}

#pragma mark - AdSurgeAppOpenAdDelegate

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
    [TPAdSurgeAdapterHelper log:@"开屏收益回调 unitId:%@ revenue:%f creativeId:%@",
                                      self.unitId, ad.revenue, ad.creativeId];
}

@end
