//
//  TPAdSurgeNativeAdapter.m
//
//  自渲染流程：
//  1. loadAdWithWaterfallItem: → 加载 AdSurgeNativeAd；
//  2. didLoadAd: → 把素材绑定到 TradPlusAdRes 并赋值给 waterfallItem.adRes，回调 AdLoadFinsh；
//  3. endRender:clickView: → 用 AdSurgeNativeAdView 包裹 TP 渲染好的视图，注册各素材视图与
//     可点击视图后调用 registerViewForInteraction:clickViews:，返回 AdSurge 容器。
//

#import "TPAdSurgeNativeAdapter.h"

#import "TPAdSurgeAdapterHelper.h"

#import <TradPlusAds/TradPlusAdRes.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>

#import <AdSurgeSDK/AdSurgeSDK.h>
NSString *const kTPAdSurgeNativeLogoPosKey = @"ad_logo_position";

@interface TPAdSurgeNativeAdapter () <AdSurgeNativeAdDelegate>

@property (nonatomic, strong, nullable) AdSurgeNativeAd *nativeAd;
@property (nonatomic, strong, nullable) AdSurgeNativeAdView *nativeAdView;
@property (nonatomic, assign) BOOL adLoaded;

@end

@implementation TPAdSurgeNativeAdapter

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
        strongSelf.nativeAd = [[AdSurgeNativeAd alloc] initWithAdUnitIdentifier:unitId];
        // viewController 必须先于 loadAd 设置，否则加载失败或点击无法处理
        strongSelf.nativeAd.viewController = item.nativeRootViewController ?: [TPAdSurgeAdapterHelper topViewController];
        strongSelf.nativeAd.delegate = strongSelf;

        AdSurgeAdConfig *config = [strongSelf adConfigWithFormat:AdSurgeAdFormat.native];
        // Logo 位置只认 TP 后台下发的广告源参数，未配置时保持 AdSurge SDK 默认（右上）
        AdSurgeNativeAdLogoPosition logoPos = [strongSelf nativeAdLogoPosWithItem:item];
        if (logoPos != 0)
        {
            config.nativeAdLogoPos = logoPos;
        }
        [strongSelf.nativeAd loadAd:config];

    }];
}

#pragma mark - 状态

- (BOOL)isReady
{
    return self.nativeAd != nil && self.adLoaded;
}

- (id)getCustomObject
{
    return self.nativeAd;
}

- (AdSurgePlacementType)adSurgePlacementType
{
    return AdSurgePlacementTypeNative;
}

#pragma mark - 渲染

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    if (self.nativeAd == nil)
    {
        return nil;
    }

    AdSurgeNativeAdView *nativeAdView = [[AdSurgeNativeAdView alloc] init];

    // 把 TP 渲染好的视图放进 AdSurge 容器
    UIView *adView = viewInfo[kTPRendererAdView];
    if (adView != nil)
    {
        nativeAdView.frame = adView.bounds;
        [nativeAdView addSubview:adView];
    }

    if (viewInfo[kTPRendererTitleLable] != nil)
    {
        [nativeAdView setHeadlineView:viewInfo[kTPRendererTitleLable]];
    }
    if (viewInfo[kTPRendererTextLable] != nil)
    {
        [nativeAdView setBodyView:viewInfo[kTPRendererTextLable]];
    }
    if (viewInfo[kTPRendererIconView] != nil)
    {
        [nativeAdView setIconView:viewInfo[kTPRendererIconView]];
    }
    if (viewInfo[kTPRendererCtaLabel] != nil)
    {
        [nativeAdView setCallToActionView:viewInfo[kTPRendererCtaLabel]];
    }
    if (viewInfo[kTPRendererMediaView] != nil)
    {
        [nativeAdView setMediaView:viewInfo[kTPRendererMediaView]];
    }

    NSArray<UIView *> *clickViews = array ?: @[];
    [self.nativeAd registerViewForInteraction:nativeAdView clickViews:clickViews];

    self.nativeAdView = nativeAdView;
    return nativeAdView;
}

- (void)adViewWillDestroy
{
    self.nativeAd.delegate = nil;
    [self.nativeAdView removeFromSuperview];
    self.nativeAdView = nil;
    self.nativeAd = nil;
    self.adLoaded = NO;
}

#pragma mark - Logo 位置

/// 从 TP 后台下发的广告源参数里读原生 Logo 位置。
/// @return 合法的 AdSurgeNativeAdLogoPosition；返回 0 表示后台未配置 / 配置非法，
///         调用方此时不要赋值，保留 AdSurgeAdConfig 的默认值。
- (AdSurgeNativeAdLogoPosition)nativeAdLogoPosWithItem:(TradPlusAdWaterfallItem *)item
{
    if (![item.config isKindOfClass:[NSDictionary class]])
    {
        return 0;
    }

    id value = item.config[kTPAdSurgeNativeLogoPosKey];
    NSInteger pos = 0;
    if ([value isKindOfClass:[NSNumber class]])
    {
        pos = [(NSNumber *)value integerValue];
    }
    else if ([value isKindOfClass:[NSString class]])
    {
        //后台可能把值填成字符串
        pos = [(NSString *)value integerValue];
    }

    //枚举原始值从 1 开始，0 与越界值都视为「未配置」，不能透传给 SDK
    if (pos < AdSurgeNativeLogoPosition_TopLeft || pos > AdSurgeNativeLogoPosition_BottomRight)
    {
        if (value != nil)
        {
            [TPAdSurgeAdapterHelper log:@"原生 Logo 位置配置非法，已忽略 value:%@", value];
        }
        return 0;
    }
    return (AdSurgeNativeAdLogoPosition)pos;
}

#pragma mark - AdSurgeNativeAdDelegate

- (void)didLoadAd:(AdSurgeAd *)ad
{
    self.adLoaded = YES;

    //绑定素材，供 TP SDK 的原生界面渲染
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.adType = TPAdResTypeAssets;
    res.title = self.nativeAd.headLine;
    res.body = self.nativeAd.body;
    res.ctaText = self.nativeAd.callToAction;

    NSString *iconUrl = self.nativeAd.iconInfo.iconUrl;
    if (iconUrl.length > 0)
    {
        res.iconImageURL = iconUrl;
    }

    AdSurgeMediaContent *mediaContent = self.nativeAd.mediaContent;
    if (mediaContent != nil)
    {
        res.mediaView = mediaContent;
        CGFloat aspectRatio = [mediaContent aspectRatio];
        if (aspectRatio > 0)
        {
            res.aspectRatio = aspectRatio;
        }
    }

    if (self.nativeAd.adChoicesView != nil)
    {
        res.adChoiceView = self.nativeAd.adChoicesView;
    }

    self.waterfallItem.adRes = res;

    //加载成功（C2S 取价阶段会在基类里转为回传 ecpm）
    [self handleAdSurgeDidLoadAd:ad];
}

- (void)didFailToLoadAdForAdUnitIdentifier:(NSString *)adUnitIdentifier withError:(AdSurgeError *)error
{
    self.adLoaded = NO;
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

- (void)didClickAd:(AdSurgeAd *)ad
{
    //广告点击
    [self AdClick];
}

- (void)didPayRevenueForAd:(AdSurgeAd *)ad
{
    [TPAdSurgeAdapterHelper log:@"原生收益回调 unitId:%@ revenue:%f creativeId:%@",
                                      self.unitId, ad.revenue, ad.creativeId];
}

@end
