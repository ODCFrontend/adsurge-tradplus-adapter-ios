//
//  TPAdSurgeC2SAdapter.m
//
//  这些子类不需要任何额外实现：C2S 的取价、胜出加载、win/loss 上报全部在
//  TPAdSurgeBaseAdapter 中完成，各格式的请求与展示逻辑则继承自对应的
//  格式 Adapter。此处仅提供可供 TP 后台单独登记的类名。
//

#import "TPAdSurgeC2SAdapter.h"

@implementation TPAdSurgeC2SRewardedAdapter
@end

@implementation TPAdSurgeC2SInterstitialAdapter
@end

@implementation TPAdSurgeC2SBannerAdapter
@end

@implementation TPAdSurgeC2SSplashAdapter
@end

@implementation TPAdSurgeC2SNativeAdapter
@end
