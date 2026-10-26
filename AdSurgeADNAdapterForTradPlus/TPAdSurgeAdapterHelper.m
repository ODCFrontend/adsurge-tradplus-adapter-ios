//
//  TPAdSurgeAdapterHelper.m
//

#import "TPAdSurgeAdapterHelper.h"

#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <AdSurgeSDK/AdSurgeSDK.h>

NSInteger const kTPAdSurgeNetworkId = 10611;

NSString *const kTPAdSurgeAppIdKey = @"appId";
NSString *const kTPAdSurgeUnitIdKey = @"unitId";
NSString *const kTPAdSurgePayloadKey = @"payload";

NSString *const kTPAdSurgeMediationSource = @"TradPlus";

NSString *const kTPAdSurgeAdapterErrorDomain = @"com.adsurge.tradplus.adapter";
/// TP 后台广告源参数中的 C2S 底价字段名。
/// 值必须是数字，单位以 AdSurge 侧的口径为准，适配器不做任何换算，原样透传。
NSString *const kTPAdSurgeBidFloorKey = @"bid_floor";

@implementation TPAdSurgeAdapterHelper

#pragma mark - 配置读取

+ (nullable NSString *)stringFromConfig:(nullable NSDictionary *)config forKey:(NSString *)key
{
    if (![config isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }
    id value = config[key];
    if ([value isKindOfClass:[NSString class]])
    {
        NSString *string = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return string.length > 0 ? string : nil;
    }
    if ([value isKindOfClass:[NSNumber class]])
    {
        return [(NSNumber *)value stringValue];
    }
    return nil;
}

+ (nullable NSString *)appIdWithItem:(nullable TradPlusAdWaterfallItem *)item
{
    NSString *appId = [self stringFromConfig:item.config forKey:kTPAdSurgeAppIdKey];
    return appId;
}

+ (nullable NSString *)unitIdWithItem:(nullable TradPlusAdWaterfallItem *)item
{
    NSString *unitId = [self stringFromConfig:item.config forKey:kTPAdSurgeUnitIdKey];

    return unitId;
}

#pragma mark - SDK 初始化 / 隐私
+ (void)initializeSDKWithAppId:(nullable NSString *)appId
                    completion:(void (^)(NSError *_Nullable error))completion
{
    if (completion == nil)
    {
        return;
    }

    if (appId.length == 0)
    {
        completion([self errorWithCode:TPAdSurgeAdapterErrorInvalidConfig
                          description:@"TP 后台广告源参数缺少 appId，无法初始化 AdSurge ADN SDK"]);
        return;
    }

    // 隐私合规必须先于初始化
    [self syncPrivacyConfiguration];

    AdSurgeSDKConfig *config = [AdSurgeSDKConfig new];
    config.appId = appId;

    [[AdSurgeAdSdk shared] initializeWithConfig:config
                             completionHandler:^(BOOL success, AdSurgeError *_Nullable error) {
        if (success)
        {
            [self log:@"AdSurge ADN SDK 初始化成功"];
            completion(nil);
            return;
        }

        NSError *resultError = [self errorFromAdSurgeError:error unitId:nil];
        [self log:@"AdSurge ADN SDK 初始化失败:%@", resultError.localizedDescription];
        completion(resultError);
    }];
}


+ (void)syncPrivacyConfiguration
{
    AdSurgePrivacyConfiguration *privacy = [AdSurgePrivacyConfiguration configuration];

    // COPPA：0=未设置 1=成人 2=儿童
    NSInteger coppa = [[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa == 1)
    {
        privacy.ageRestrictedUser = @(0);
    }
    else if (coppa == 2)
    {
        privacy.ageRestrictedUser = @(1);
    }

    // CCPA：0=未设置 1=不上报数据 2=上报数据
    NSInteger ccpa = [[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa == 1)
    {
        privacy.doNotSell = @(1);
    }
    else if (ccpa == 2)
    {
        privacy.doNotSell = @(0);
    }

    // GDPR：TP 是否允许收集个人信息
    BOOL canCollectPersonalInfo = [MSConsentManager sharedManager].canCollectPersonalInfo;
    privacy.userConsent = canCollectPersonalInfo ? @(1) : @(0);
    privacy.nonPersonalizedAds = canCollectPersonalInfo ? @(0) : @(1);
}

+ (NSString *)sdkVersion
{
    return AdSurgeAdSdkVersion ?: @"";
}

+ (nullable NSString *)bidderToken
{
    // AdSurge 的 getBidderToken: 是同步返回的（回调在当前线程立即执行）
    __block NSString *token = nil;
    [[AdSurgeAdSdk shared] getBidderToken:^(NSString *_Nullable bidderToken, AdSurgeError *_Nullable error) {
        if (error != nil)
        {
            [self log:@"获取 bidder token 失败 code:%ld message:%@", (long)error.code, error.message];
            return;
        }
        token = bidderToken;
    }];
    return token;
}

#pragma mark - C2S Bidding

+ (NSString *)c2sEcpmStringFromRevenue:(double)revenue
{
    if (revenue <= 0 || isnan(revenue) || isinf(revenue))
    {
        return @"0";
    }
    return [NSString stringWithFormat:@"%f", revenue];
}


#pragma mark - 请求参数

+ (AdSurgeAdConfig *)adConfigWithFormat:(AdSurgeAdFormat *)format
                                   item:(nullable TradPlusAdWaterfallItem *)item
{
    AdSurgeAdConfig *config = [AdSurgeAdConfig configWithAdFormat:format];

    // 静音：TP video_mute 1=是 2=否；item.mute 为广告对象级设置
    config.mute = (item.video_mute == 1) || item.mute;
    // 自动播放：TP auto_play_video 1=总是 2=仅 WiFi（仅原生生效）
    config.autoPlay = (item.auto_play_video != 2);
    // 底价：只读 TP 后台下发的广告源参数，且原样透传，不做单位换算
    id bidFloor = item.config[kTPAdSurgeBidFloorKey];
    if ([bidFloor isKindOfClass:[NSNumber class]] && [(NSNumber *)bidFloor doubleValue] > 0)
    {
        config.bidFloor = (NSNumber *)bidFloor;
    }

    // 聚合标记，便于 AdSurge 侧归因与排查
    config.mediationSource = kTPAdSurgeMediationSource;
    NSString *mediationAdUnitId = item.true_adunit_id.length > 0 ? item.true_adunit_id : item.placementID;
    if (mediationAdUnitId.length > 0)
    {
        config.mediationAdUnitId = mediationAdUnitId;
    }
    if (item.requestId.length > 0)
    {
        config.mediationTraceId = item.requestId;
    }

    // 透传开发者自定义参数
    if (item.dicCustomValue.count > 0)
    {
        config.extra = item.dicCustomValue;
    }

    return config;
}

+ (nullable UIViewController *)topViewController
{
    UIWindow *keyWindow = nil;
    for (UIWindow *window in UIApplication.sharedApplication.windows)
    {
        if (window.isKeyWindow)
        {
            keyWindow = window;
            break;
        }
    }
    UIViewController *viewController = keyWindow.rootViewController;
    while (viewController.presentedViewController != nil)
    {
        viewController = viewController.presentedViewController;
    }
    return viewController;
}

#pragma mark - 错误

+ (NSError *)errorWithCode:(TPAdSurgeAdapterErrorCode)code description:(NSString *)description
{
    return [NSError errorWithDomain:kTPAdSurgeAdapterErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"AdSurge adapter error"}];
}

+ (NSError *)errorFromAdSurgeError:(nullable AdSurgeError *)error
                                   unitId:(nullable NSString *)unitId
{
    NSInteger adSurgeCode = error != nil ? (NSInteger)error.code : -1;
    NSString *message = error.message;

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] =
        [NSString stringWithFormat:@"AdSurge ADN error. code:%ld message:%@", (long)adSurgeCode, message ?: @"(nil)"];
    userInfo[@"adsurge_error_code"] = @(adSurgeCode);
    if (message.length > 0)
    {
        userInfo[@"adsurge_error_message"] = message;
    }
    if (unitId.length > 0)
    {
        userInfo[@"adsurge_unit_id"] = unitId;
    }

    return [NSError errorWithDomain:kTPAdSurgeAdapterErrorDomain
                               code:TPAdSurgeAdapterErrorADN
                           userInfo:userInfo];
}

+ (void)log:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    MSLogTrace(@"[AdSurge] %@", message);
}


@end
