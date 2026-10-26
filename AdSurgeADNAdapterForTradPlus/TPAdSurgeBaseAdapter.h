//
//  TPAdSurgeBaseAdapter.h
//  AdSurge ADN —— 各广告格式 Adapter 的基类
//
//  复用：
//  - 配置校验 → 隐私同步 → SDK 初始化 的加载前置流程；
//  - TradPlusAdapterProtocol（sdkVersion / buyeruid / initSDK），Bidding 场景下
//    引擎可能直接对格式 Adapter 类调用这几个类方法；
//  - AdSurge 错误 → TradPlus 回调的转换；
//  - C2S Bidding 全流程（取价 / 胜出加载 / win-loss 上报），对 5 种格式通用。
//

#import <TradPlusAds/TradPlusAdapterProtocol.h>
#import <TradPlusAds/TradPlusBaseAdapter.h>

#import <AdSurgeSDK/AdSurgeAd.h>

@class AdSurgeAdConfig;
@class AdSurgeAdFormat;
@class AdSurgeError;
@class TradPlusAdWaterfallItem;

NS_ASSUME_NONNULL_BEGIN

@interface TPAdSurgeBaseAdapter : TradPlusBaseAdapter <TradPlusAdapterProtocol>

/// 当前广告位 ID（来自 TP 后台广告源参数 unitId）
@property (nonatomic, copy, readonly, nullable) NSString *unitId;

/// 加载前置流程：校验配置 → 同步隐私 → 初始化 AdSurge SDK。
/// 配置缺失会自动回调 AdConfigError（C2S 取价阶段则回调 C2SBiddingFail），
/// 初始化失败会自动回调 AdLoadFailWithError:，只有成功时才会执行 loadBlock。
- (void)prepareForLoadWithItem:(TradPlusAdWaterfallItem *)item
                     loadBlock:(void (^)(NSString *unitId))loadBlock;

/// 依据 TP 下发参数构建 AdSurge 请求配置
- (AdSurgeAdConfig *)adConfigWithFormat:(AdSurgeAdFormat *)format;

#pragma mark - 加载结果统一入口（子类必须走这两个方法）

/// AdSurge 加载成功 → 普通加载回调 AdLoadFinsh；C2S 取价阶段回传 C2SBiddingFinish。
/// 各格式子类的 didLoadAd: 必须调用它，不要直接调 AdLoadFinsh，否则 C2S 竞价拿不到价格。
- (void)handleAdSurgeDidLoadAd:(nullable AdSurgeAd *)ad;

/// AdSurge 加载失败 → 普通加载回调 AdLoadFailWithError:；C2S 取价阶段回传 C2SBiddingFail
- (void)handleAdSurgeLoadFailure:(nullable AdSurgeError *)error;

/// AdSurge 展示失败 → AdShowFailWithError:
- (void)handleAdSurgeShowFailure:(nullable AdSurgeError *)error;

/// 广告未就绪时的展示失败回调
- (void)handleAdNotReadyForShow;

#pragma mark - C2S Bidding

/// 是否处于 C2S 取价阶段。该阶段的加载结果要回传竞价事件，而不是加载事件。
@property (nonatomic, assign, readonly) BOOL isC2SBiddingPhase;

/// 最近一次加载成功的 AdSurge 广告对象。C2S 取价与 win/loss 上报都依赖它，
/// 因为 revenue 和通知 URL 都绑定在具体的广告实例上。
@property (nonatomic, strong, readonly, nullable) AdSurgeAd *loadedAdSurgeAd;

/// 子类必须重写：该格式对应的 AdSurge 竞价位类型，用于 win/loss 通知
- (AdSurgePlacementType)adSurgePlacementType;

/// 子类可重写：C2S 取价阶段如何发起请求。
/// AdSurge 属于「加载成功即拿到价格」的类型（价格来自 AdSurgeAd.revenue），
/// 因此默认实现直接复用完整加载流程，无需为竞价单独写一套请求逻辑。
- (void)startC2SBiddingRequest;

/// 上报 win（幂等）。默认在收到 LoadAdC2SBidding（即竞价胜出）时由基类自动调用。
- (void)sendC2SWinNotification;

@end

NS_ASSUME_NONNULL_END
