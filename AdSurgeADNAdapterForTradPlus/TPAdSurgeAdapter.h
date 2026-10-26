//
//  TPAdSurgeAdapter.h
//  AdSurge ADN —— TradPlus 平台级 Adapter（SDK 初始化 / 版本号 / Bidding Token）
//
//  TradPlus 引擎按后台登记的平台级类名查找本类（本平台为 TPAdSurgeAdapter），
//  用于三方 SDK 预初始化、上报三方 SDK 版本号、以及 Bidding 取 token。
//  AdSurge 广告平台 ID：10611
//

#import <Foundation/Foundation.h>
#import <TradPlusAds/TradPlusAdapterProtocol.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPAdSurgeAdapter : NSObject <TradPlusAdapterProtocol>

@end

NS_ASSUME_NONNULL_END
