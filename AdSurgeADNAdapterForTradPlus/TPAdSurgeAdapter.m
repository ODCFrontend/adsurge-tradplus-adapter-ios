//
//  TPAdSurgeAdapter.m
//

#import "TPAdSurgeAdapter.h"

#import "TPAdSurgeAdapterHelper.h"

@implementation TPAdSurgeAdapter

#pragma mark - TradPlusAdapterProtocol

/// 上报 AdSurge ADN SDK 版本号
+ (NSString *)sdkVersion
{
    return [TPAdSurgeAdapterHelper sdkVersion];
}

/// Bidding：TradPlus 取 token 时调用（要求同步返回）
+ (NSString *)getBuyeruidWithInfo:(NSDictionary *)infoDic
{
    NSString *token = [TPAdSurgeAdapterHelper bidderToken];
    return token ?: @"";
}

/// TradPlus 在取 token / 预初始化阶段调用
+ (void)initSDKWithInfo:(NSDictionary *)infoDic callback:(void (^)(void))callback
{
    NSString *appId = [TPAdSurgeAdapterHelper stringFromConfig:infoDic
                                                             forKey:kTPAdSurgeAppIdKey];
    [TPAdSurgeAdapterHelper initializeSDKWithAppId:appId
                                             completion:^(NSError *_Nullable error) {
        if (error != nil)
        {
            [TPAdSurgeAdapterHelper log:@"initSDKWithInfo 初始化失败:%@", error.localizedDescription];
        }
        if (callback != nil)
        {
            callback();
        }
    }];
}

@end
