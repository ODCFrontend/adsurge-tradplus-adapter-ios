//
//  TPAdSurgeBannerAdapter.m
//

#import "TPAdSurgeBannerAdapter.h"

#import "TPAdSurgeAdapterHelper.h"

#import <TradPlusAds/TradPlusAdWaterfallItem.h>

#import <AdSurgeSDK/AdSurgeSDK.h>

@interface TPAdSurgeBannerAdapter () <AdSurgeBannerAdDelegate>

@property (nonatomic, strong, nullable) AdSurgeBannerAdView *bannerAdView;
@property (nonatomic, assign) BOOL adLoaded;

@end

@implementation TPAdSurgeBannerAdapter

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

        // AdSurge 当前版本 banner 尺寸由 SDK 自行决定，这里用 TP 下发的尺寸作为初始 frame
        CGSize bannerSize = item.bannerSize;
        if (bannerSize.width <= 0 || bannerSize.height <= 0)
        {
            bannerSize = CGSizeMake(320, 50);
        }

        AdSurgeBannerAdView *bannerAdView = [[AdSurgeBannerAdView alloc] initWithAdUnitIdentifier:unitId];
        bannerAdView.frame = CGRectMake(0, 0, bannerSize.width, bannerSize.height);
        // viewController 必须先于 loadAd 设置，否则加载会失败
        bannerAdView.viewController = item.bannerRootViewController ?: [TPAdSurgeAdapterHelper topViewController];
        bannerAdView.delegate = strongSelf;
        strongSelf.bannerAdView = bannerAdView;

        AdSurgeAdConfig *config = [strongSelf adConfigWithFormat:AdSurgeAdFormat.banner];
        [bannerAdView loadAd:config];
    }];
}

#pragma mark - 状态

- (BOOL)isReady
{
    return self.bannerAdView != nil && self.adLoaded;
}

/// TP 通过该方法拿到横幅视图并添加到宿主视图上
- (id)getCustomObject
{
    return self.bannerAdView;
}

- (AdSurgePlacementType)adSurgePlacementType
{
    return AdSurgePlacementTypeBanner;
}

/// 横幅被添加到屏幕上时：对齐容器宽度并上报展示
- (void)bannerDidAddSubView:(UIView *)subView
{
    if (subView.bounds.size.width > 0 && self.bannerAdView != nil)
    {
        CGRect frame = self.bannerAdView.frame;
        frame.size.width = subView.bounds.size.width;
        self.bannerAdView.frame = frame;
        [self setBannerCenterWithBanner:self.bannerAdView subView:subView];
    }
    //AdSurge banner 无独立曝光回调，以真正添加到屏幕作为展示时机
    [self AdShow];
}

- (void)adViewWillDestroy
{
    self.bannerAdView.delegate = nil;
    [self.bannerAdView removeFromSuperview];
    self.bannerAdView = nil;
    self.adLoaded = NO;
}

#pragma mark - AdSurgeBannerAdDelegate

- (void)didLoadAd:(AdSurgeAd *)ad
{
    self.adLoaded = YES;
    //加载成功（C2S 取价阶段会在基类里转为回传 ecpm）
    [self handleAdSurgeDidLoadAd:ad];
}

- (void)didFailToLoadAdForAdUnitIdentifier:(NSString *)adUnitIdentifier withError:(AdSurgeError *)error
{
    self.adLoaded = NO;
    //加载失败
    [self handleAdSurgeLoadFailure:error];
}

- (void)didClickAd:(AdSurgeAd *)ad
{
    //广告点击
    [self AdClick];
}

- (void)didHideAd:(AdSurgeAd *)ad
{
    //广告关闭
    [self AdClose];
}

- (void)didPayRevenueForAd:(AdSurgeAd *)ad
{
    [TPAdSurgeAdapterHelper log:@"横幅收益回调 unitId:%@ revenue:%f creativeId:%@",
                                      self.unitId, ad.revenue, ad.creativeId];
}

@end
