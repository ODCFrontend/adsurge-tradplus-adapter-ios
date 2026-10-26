//
//  TPAdSurgeAdapterHelper.h
//  AdSurge ADN —— TradPlus Adapter 公共能力
//
//  职责：
//  1. AdSurge ADN SDK 的初始化；
//  2. 把 TradPlus 的隐私合规状态（COPPA / CCPA / GDPR）同步到 AdSurgePrivacyConfiguration；
//  3. 统一构建 AdSurgeAdConfig（静音、自动播放、聚合标记、payload 等）；
//  4. AdSurgeError → NSError 转换，便于 TradPlus 上报与排查。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TradPlusAdWaterfallItem;
@class AdSurgeAdConfig;
@class AdSurgeAdFormat;
@class AdSurgeError;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 平台信息

/// AdSurge 在 TradPlus 的广告平台 ID
FOUNDATION_EXPORT NSInteger const kTPAdSurgeNetworkId;

#pragma mark - TP 后台下发的配置字段

/// TP 后台广告源参数中的 App ID 字段名
FOUNDATION_EXPORT NSString *const kTPAdSurgeAppIdKey;
/// TP 后台广告源参数中的广告位 ID 字段名
FOUNDATION_EXPORT NSString *const kTPAdSurgeUnitIdKey;
/// S2S Bidding 场景下服务端下发的 payload 字段名
FOUNDATION_EXPORT NSString *const kTPAdSurgePayloadKey;

/// 传给 AdSurge 的聚合来源标记
FOUNDATION_EXPORT NSString *const kTPAdSurgeMediationSource;

/// Adapter 自身错误域
FOUNDATION_EXPORT NSString *const kTPAdSurgeAdapterErrorDomain;

FOUNDATION_EXPORT NSString *const kTPAdSurgeBidFloorKey;   // @"bid_floor"

typedef NS_ENUM(NSInteger, TPAdSurgeAdapterErrorCode) {
    /// TP 后台广告源参数缺失（appId / unitId）
    TPAdSurgeAdapterErrorInvalidConfig = 8001,
    /// AdSurge ADN SDK 初始化失败
    TPAdSurgeAdapterErrorSDKInitFailed = 8002,
    /// 广告未就绪 / 已过期却被要求展示
    TPAdSurgeAdapterErrorAdNotReady = 8003,
    /// AdSurge ADN 返回的错误（原始 code / message 见 userInfo）
    TPAdSurgeAdapterErrorADN = 8004,
};
#pragma mark - 可配置项字段名 server
/// 原生广告 Logo 位置：1=TL 2=TR 3=BL 4=BR（AdSurge 口径）
FOUNDATION_EXPORT NSString *const kTPAdSurgeNativeLogoPosKey;     // @"ad_logo_position"

@interface TPAdSurgeAdapterHelper : NSObject

#pragma mark - 配置读取

/// 从 config 读取字符串，自动过滤 NSNull / 空串；兼容后台填成数字的情况
+ (nullable NSString *)stringFromConfig:(nullable NSDictionary *)config forKey:(NSString *)key;

+ (nullable NSString *)appIdWithItem:(nullable TradPlusAdWaterfallItem *)item;

+ (nullable NSString *)unitIdWithItem:(nullable TradPlusAdWaterfallItem *)item;

#pragma mark - SDK 初始化 / 隐私

/// 初始化 AdSurge ADN SDK
+ (void)initializeSDKWithAppId:(nullable NSString *)appId
                    completion:(void (^)(NSError *_Nullable error))completion;

/// 把 TradPlus 的隐私状态同步到 AdSurge（必须在 SDK 初始化与广告请求之前调用）
+ (void)syncPrivacyConfiguration;

/// AdSurge ADN SDK 版本号
+ (NSString *)sdkVersion;

/// 同步获取 AdSurge 的 bidder token（供 TradPlus Bidding 的 getBuyeruid 使用）
+ (nullable NSString *)bidderToken;

#pragma mark - C2S Bidding

/// AdSurge 的 ad.revenue（单次曝光收益，USD）→ 回传给 TradPlus 的 ecpm 字符串。
+ (NSString *)c2sEcpmStringFromRevenue:(double)revenue;

#pragma mark - 请求参数

/// 依据 TP 下发的 item 构建 AdSurgeAdConfig（静音 / 自动播放 / 聚合标记 / payload / 自定义参数）
+ (AdSurgeAdConfig *)adConfigWithFormat:(AdSurgeAdFormat *)format
                                   item:(nullable TradPlusAdWaterfallItem *)item;

/// 顶层 ViewController 兜底（TP 未下发 rootViewController 时使用）
+ (nullable UIViewController *)topViewController;

#pragma mark - 错误

+ (NSError *)errorWithCode:(TPAdSurgeAdapterErrorCode)code description:(NSString *)description;

+ (NSError *)errorFromAdSurgeError:(nullable AdSurgeError *)error
                                   unitId:(nullable NSString *)unitId;

+ (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

@end

NS_ASSUME_NONNULL_END
