//
//  TPAdSurgeC2SAdapter.h
//  AdSurge ADN —— C2S Bidding 专用 Adapter 类名
//
//  为什么需要这些类？
//  C2S 逻辑本身已经在 TPAdSurgeBaseAdapter 里实现，普通格式 Adapter
//  （TPAdSurgeRewardedAdapter 等）天然就支持 C2S —— 引擎是通过
//  extraActWithEvent: 下发竞价事件的，与类名无关。
//
//  但 TradPlus 后台的实际配置习惯有两种：
//  A. 在同一个「自定义广告平台」下把广告源的竞价方式设为 C2S
//     → 类名继续填 TPAdSurgeRewardedAdapter 即可，本文件用不到；
//  B. 单独再建一个「AdSurge C2S」自定义广告平台，与 Waterfall 分开管理
//     → 类名填本文件里的 TPAdSurgeC2SRewardedAdapter 等。
//
//  两种方式的运行逻辑完全一致，按后台实际配置选一种填即可。
//

#import "TPAdSurgeBannerAdapter.h"
#import "TPAdSurgeInterstitialAdapter.h"
#import "TPAdSurgeNativeAdapter.h"
#import "TPAdSurgeRewardedAdapter.h"
#import "TPAdSurgeSplashAdapter.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 激励视频

@interface TPAdSurgeC2SRewardedAdapter : TPAdSurgeRewardedAdapter
@end

#pragma mark - 插屏

@interface TPAdSurgeC2SInterstitialAdapter : TPAdSurgeInterstitialAdapter
@end

#pragma mark - 横幅

@interface TPAdSurgeC2SBannerAdapter : TPAdSurgeBannerAdapter
@end

#pragma mark - 开屏（AdSurge 侧为 App Open）

@interface TPAdSurgeC2SSplashAdapter : TPAdSurgeSplashAdapter
@end

#pragma mark - 原生

@interface TPAdSurgeC2SNativeAdapter : TPAdSurgeNativeAdapter
@end

NS_ASSUME_NONNULL_END
