//
//  TPAdSurgeBaseAdapter.m
//

#import "TPAdSurgeBaseAdapter.h"

#import "TPAdSurgeAdapter.h"
#import "TPAdSurgeAdapterHelper.h"

#import <TradPlusAds/TradPlusAdWaterfallItem.h>

#import <AdSurgeSDK/AdSurgeAd.h>

#pragma mark - TradPlus C2S 事件名（引擎约定，不可改）

/// 引擎 → Adapter：开始 C2S 取价
static NSString *const kTPC2SEventBidding = @"C2SBidding";
/// 引擎 → Adapter：竞价胜出，执行加载
static NSString *const kTPC2SEventLoadAd = @"LoadAdC2SBidding";
/// 引擎 → Adapter：竞价失败
static NSString *const kTPC2SEventLoss = @"C2SLoss";

/// Adapter → 引擎：取价成功，info 需含 ecpm / version
static NSString *const kTPC2SCallbackFinish = @"C2SBiddingFinish";
/// Adapter → 引擎：取价失败，info 需含 error
static NSString *const kTPC2SCallbackFail = @"C2SBiddingFail";

/// C2SLoss 事件里引擎下发的获胜价字段（注意 TradPlus 原始拼写是 Pirce）
static NSString *const kTPC2SLossTopPriceKey = @"topPirce";
static NSString *const kTPC2SLossTopPriceCNYKey = @"topPirce_cny";

@interface TPAdSurgeBaseAdapter ()

@property (nonatomic, copy, nullable) NSString *unitId;

@property (nonatomic, assign) BOOL isC2SBiddingPhase;
@property (nonatomic, strong, nullable) AdSurgeAd *loadedAdSurgeAd;
@property (nonatomic, assign) BOOL didSendC2SWin;
@property (nonatomic, assign) BOOL didSendC2SLoss;

@end

@implementation TPAdSurgeBaseAdapter

#pragma mark - TradPlusAdapterProtocol（转交平台级 Adapter）

+ (NSString *)sdkVersion
{
    return [TPAdSurgeAdapter sdkVersion];
}

+ (NSString *)getBuyeruidWithInfo:(NSDictionary *)infoDic
{
    return [TPAdSurgeAdapter getBuyeruidWithInfo:infoDic];
}

+ (void)initSDKWithInfo:(NSDictionary *)infoDic callback:(void (^)(void))callback
{
    [TPAdSurgeAdapter initSDKWithInfo:infoDic callback:callback];
}

#pragma mark - 加载前置流程

- (void)prepareForLoadWithItem:(TradPlusAdWaterfallItem *)item
                     loadBlock:(void (^)(NSString *unitId))loadBlock
{
    [TPAdSurgeAdapterHelper log:@"TP 下发广告源参数 config:%@", item.config];
    if (item.id != 0 && item.id != kTPAdSurgeNetworkId)
    {
        [TPAdSurgeAdapterHelper log:@"注意：当前广告源 network id=%ld，AdSurge 应为 %ld",
                                          (long)item.id, (long)kTPAdSurgeNetworkId];
    }

    NSString *appId = [TPAdSurgeAdapterHelper appIdWithItem:item];
    NSString *unitId = [TPAdSurgeAdapterHelper unitIdWithItem:item];

    if (appId.length == 0 || unitId.length == 0)
    {
        [TPAdSurgeAdapterHelper log:@"配置错误，appId 或 unitId 缺失 config:%@", item.config];
        if (self.isC2SBiddingPhase)
        {
            //C2S 取价阶段的配置错误也要走竞价失败，否则引擎会一直等超时
            [self failC2SBiddingWithErrorStr:@"TP 后台广告源参数缺少 appId 或 unitId"];
            return;
        }
        //配置错误
        [self AdConfigError];
        return;
    }

    self.unitId = unitId;

    [TPAdSurgeAdapterHelper log:@"发起请求 class:%@ appId:%@ unitId:%@ isC2S:%@ tpAdUnit:%@",
                                      NSStringFromClass([self class]), appId, unitId,
                                      item.isC2SBidding ? @"Y" : @"N", item.true_adunit_id];

    // 隐私状态可能在运行时变化，每次请求前同步一次
    [TPAdSurgeAdapterHelper syncPrivacyConfiguration];

    __weak typeof(self) weakSelf = self;
    [TPAdSurgeAdapterHelper initializeSDKWithAppId:appId
                                             completion:^(NSError *_Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil)
        {
            return;
        }
        if (error != nil)
        {
            if (strongSelf.isC2SBiddingPhase)
            {
                [strongSelf failC2SBiddingWithErrorStr:error.localizedDescription];
                return;
            }
            //初始化失败视为加载失败
            [strongSelf AdLoadFailWithError:error];
            return;
        }
        if (loadBlock != nil)
        {
            loadBlock(unitId);
        }
    }];
}

- (AdSurgeAdConfig *)adConfigWithFormat:(AdSurgeAdFormat *)format
{
    return [TPAdSurgeAdapterHelper adConfigWithFormat:format item:self.waterfallItem];
}

#pragma mark - 加载结果统一入口

- (void)handleAdSurgeDidLoadAd:(nullable AdSurgeAd *)ad
{
    if (ad != nil)
    {
        self.loadedAdSurgeAd = ad;
    }

    if (!self.isC2SBiddingPhase)
    {
        //加载成功
        [self AdLoadFinsh];
        return;
    }

    // C2S 取价阶段：把 AdSurge 返回的价格回传给引擎参与竞价排序
    double revenue = ad != nil ? ad.revenue : 0;
    NSString *ecpm = [TPAdSurgeAdapterHelper c2sEcpmStringFromRevenue:revenue];
    NSString *version = [TPAdSurgeAdapterHelper sdkVersion] ?: @"";

    [TPAdSurgeAdapterHelper log:@"C2S 取价成功 unitId:%@ revenue:%f ecpm:%@ creativeId:%@",
                                      self.unitId, revenue, ecpm, ad.creativeId];

    [self ADLoadExtraCallbackWithEvent:kTPC2SCallbackFinish
                                 info:@{@"ecpm" : ecpm, @"version" : version}];
}

- (void)handleAdSurgeLoadFailure:(nullable AdSurgeError *)error
{
    NSError *loadError = [TPAdSurgeAdapterHelper errorFromAdSurgeError:error
                                                                unitId:self.unitId];

    if (self.isC2SBiddingPhase)
    {
        [TPAdSurgeAdapterHelper log:@"C2S 取价失败 unitId:%@ error:%@",
                                          self.unitId, loadError.localizedDescription];
        [self failC2SBiddingWithErrorStr:loadError.localizedDescription];
        return;
    }

    [TPAdSurgeAdapterHelper log:@"加载失败 unitId:%@ error:%@",
                                      self.unitId, loadError.localizedDescription];
    [self AdLoadFailWithError:loadError];
}

- (void)handleAdSurgeShowFailure:(nullable AdSurgeError *)error
{
    NSError *showError = [TPAdSurgeAdapterHelper errorFromAdSurgeError:error
                                                                unitId:self.unitId];
    [TPAdSurgeAdapterHelper log:@"展示失败 unitId:%@ error:%@",
                                      self.unitId, showError.localizedDescription];
    [self AdShowFailWithError:showError];
}

- (void)handleAdNotReadyForShow
{
    NSError *error = [TPAdSurgeAdapterHelper errorWithCode:TPAdSurgeAdapterErrorAdNotReady
                                                    description:@"AdSurge 广告已失效或尚未加载完成"];
    [self AdShowFailWithError:error];
}

#pragma mark - C2S Bidding

/// 引擎通过该方法下发 C2S 各阶段事件
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)config
{
    if ([event isEqualToString:kTPC2SEventBidding])
    {
        //开始取价
        self.isC2SBiddingPhase = YES;
        self.didSendC2SWin = NO;
        self.didSendC2SLoss = NO;
        [self startC2SBiddingRequest];
        return YES;
    }

    if ([event isEqualToString:kTPC2SEventLoadAd])
    {
        //竞价胜出，进入加载
        self.isC2SBiddingPhase = NO;
        [self sendC2SWinNotification];
        [self loadAdAfterC2SBiddingWin];
        return YES;
    }

    if ([event isEqualToString:kTPC2SEventLoss])
    {
        //竞价失败
        self.isC2SBiddingPhase = NO;
        [self sendC2SLossNotificationWithInfo:config];
        return YES;
    }

    return [super extraActWithEvent:event info:config];
}

- (void)startC2SBiddingRequest
{
    // AdSurge 没有独立的「只取价不要广告」接口，价格随广告一起返回（AdSurgeAd.revenue），
    // 所以取价阶段直接走完整加载；胜出后无需重复请求。
    [self loadAdWithWaterfallItem:self.waterfallItem];
}

/// 竞价胜出后的加载：取价阶段已经把广告加载好了，这里只校验有效性
- (void)loadAdAfterC2SBiddingWin
{
    if ([self isReady])
    {
        [TPAdSurgeAdapterHelper log:@"C2S 竞价胜出，广告已就绪 unitId:%@", self.unitId];
        //加载成功
        [self AdLoadFinsh];
        return;
    }

    [TPAdSurgeAdapterHelper log:@"C2S 竞价胜出但广告已失效 unitId:%@", self.unitId];
    NSError *error = [TPAdSurgeAdapterHelper errorWithCode:TPAdSurgeAdapterErrorAdNotReady
                                                    description:@"C2S 竞价胜出，但 AdSurge 广告已失效"];
    //加载失败
    [self AdLoadFailWithError:error];
}

- (void)failC2SBiddingWithErrorStr:(nullable NSString *)errorStr
{
    NSString *message = errorStr.length > 0 ? errorStr : @"AdSurge C2S Bidding Fail";
    [self ADLoadExtraCallbackWithEvent:kTPC2SCallbackFail info:@{@"error" : message}];
}

- (void)sendC2SWinNotification
{
    if (self.didSendC2SWin)
    {
        return;
    }

    AdSurgeAd *ad = self.loadedAdSurgeAd;
    if (ad == nil)
    {
        [TPAdSurgeAdapterHelper log:@"跳过 win 上报：没有可用的 AdSurge 广告对象 unitId:%@",
                                          self.unitId];
        return;
    }

    self.didSendC2SWin = YES;

    // 一价成交，成交价即本次出价
    double auctionPrice = ad.revenue;

    // 第二高价（引擎在 waterfallItem 上下发，字段原始拼写为 secondPirce）
    NSNumber *minToWinPrice = nil;
    NSString *secondPrice = self.waterfallItem.secondPirce;
    if (secondPrice.length > 0 && secondPrice.doubleValue > 0)
    {
        minToWinPrice = @(secondPrice.doubleValue);
    }

    NSString *minToWinSeat = self.waterfallItem.secondPirceASPID;
    if (minToWinSeat.length == 0)
    {
        minToWinSeat = nil;
    }

    [TPAdSurgeAdapterHelper log:@"C2S 上报 win unitId:%@ auctionPrice:%f minToWinPrice:%@ seat:%@",
                                      self.unitId, auctionPrice, minToWinPrice, minToWinSeat];

    // 同一个 TP 广告位下的竞争者广告格式一致，故第二名的位类型按本 Adapter 的格式上报；
    // 第二名的计价策略无法从引擎获知，传 nil 让 SDK 跳过该宏替换。
    [ad sendWinNotificationWithPrice:auctionPrice
                      minToWinPrice:minToWinPrice
                       minToWinSeat:minToWinSeat
                  minToWinPlacement:@(self.adSurgePlacementType)
                   minToWinStrategy:nil];
}

- (void)sendC2SLossNotificationWithInfo:(nullable NSDictionary *)info
{
    if (self.didSendC2SWin || self.didSendC2SLoss)
    {
        //已胜出或已上报过，不重复上报
        return;
    }

    AdSurgeAd *ad = self.loadedAdSurgeAd;
    if (ad == nil)
    {
        // 取价阶段就没拿到广告（no fill / 报错），本来也没参与竞价，无需上报
        return;
    }

    self.didSendC2SLoss = YES;

    // 引擎下发的获胜价：topPirce 为美元口径，topPirce_cny 为人民币口径。
    // AdSurge 的 loss 通知按 USD 计价，因此取 topPirce。
    NSString *topPrice = [TPAdSurgeAdapterHelper stringFromConfig:info forKey:kTPC2SLossTopPriceKey];
    double auctionPrice = topPrice.doubleValue;

    AdSurgeLossReason lossReason = topPrice.length > 0
                                     ? AdSurgeLossReasonLossToOtherBidder
                                     : AdSurgeLossReasonUnknown;

    [TPAdSurgeAdapterHelper log:@"C2S 上报 loss unitId:%@ auctionPrice:%f (cny:%@) lossReason:%ld",
                                      self.unitId, auctionPrice,
                                      [TPAdSurgeAdapterHelper stringFromConfig:info
                                                                       forKey:kTPC2SLossTopPriceCNYKey],
                                      (long)lossReason];

    // 获胜方与本广告源同属一个 TP 广告位，格式一致；获胜方的计价策略未知，传 nil。
    [ad sendLossNotificationWithPrice:auctionPrice
                        currencyType:@"USD"
                          lossReason:@(lossReason)
                         auctionSeat:nil
                       placementType:@(self.adSurgePlacementType)
                       priceStrategy:nil];
}

- (AdSurgePlacementType)adSurgePlacementType
{
    //子类必须重写
    return AdSurgePlacementTypeUnknown;
}

#pragma mark - TradPlusBaseAdapter

- (BOOL)isReady
{
    //子类必须重写
    return NO;
}

- (id)getCustomObject
{
    //子类按需重写，返回三方广告对象
    return nil;
}

@end
