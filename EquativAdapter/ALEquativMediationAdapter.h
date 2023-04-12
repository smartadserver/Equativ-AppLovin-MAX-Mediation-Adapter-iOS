//
//  ALEquativMediationAdapter.h
//  AppLovinSample
//
//  Created by Guillaume Laubier on 20/03/2023.
//

#import <Foundation/Foundation.h>
#import <AppLovinSDK/AppLovinSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface ALEquativMediationAdapter : ALMediationAdapter<MAAdViewAdapter, MAInterstitialAdapter, MARewardedAdapter, MANativeAdAdapter>

@end

NS_ASSUME_NONNULL_END
