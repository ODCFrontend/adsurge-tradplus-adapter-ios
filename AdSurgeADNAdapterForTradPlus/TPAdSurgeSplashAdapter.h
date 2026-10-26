//
//  TPAdSurgeSplashAdapter.h
//  AdSurge ADN 开屏（App Open）—— TradPlus Adapter
//
//  服务端下发的类名需为 TPAdSurgeSplashAdapter。
//  AdSurge 广告平台 ID：10611
//  广告源参数：{"appId": "<AdSurge App ID>", "unitId": "<AdSurge 广告位 ID>"}
//
//  注意：AdSurge 使用 AdSurgeAppOpenAd 承载开屏，展示只需要 rootViewController，
//  TP 传入的 bottomView（开屏底部自定义 View）AdSurge 侧不支持，会被忽略。
//

#import "TPAdSurgeBaseAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPAdSurgeSplashAdapter : TPAdSurgeBaseAdapter

@end

NS_ASSUME_NONNULL_END
