//
//  ALEquativMediationAdapter.h
//
//  Created by Guillaume Laubier on 20/03/2023.
//

#import <Foundation/Foundation.h>
#import <AppLovinSDK/AppLovinSDK.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * This class is an implementation of all AppLovin mediation adapters compatible with Equativ Display SDK v7.x.
 * If you are using using the Equativ Display SDK v8.0+, please check the adapter dedicated to this version here:
 * https://github.com/smartadserver/Equativ-AppLovin-MAX-Mediation-Adapter-iOS/displaysdk8
 */
@interface ALEquativMediationAdapter : ALMediationAdapter<MAAdViewAdapter, MAInterstitialAdapter, MARewardedAdapter, MANativeAdAdapter>

@end

NS_ASSUME_NONNULL_END
