//
//  ALEquativMediationAdapter.h
//
//  Created by Guillaume Laubier on 15/01/2024.
//

#import <Foundation/Foundation.h>
#import <AppLovinSDK/AppLovinSDK.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * This class is an implementation of all AppLovin mediation adapters compatible with Equativ Display SDK v8.0+.
 * If you are using an older version of the SDK (formerly Smart Display SDK), with a 7.x version, please check the adapter dedicated to this version here:
 * https://github.com/smartadserver/Equativ-AppLovin-MAX-Mediation-Adapter-iOS/displaysdk7
 */
@interface ALEquativMediationAdapter : ALMediationAdapter<MAAdViewAdapter, MAInterstitialAdapter, MANativeAdAdapter>

@end

NS_ASSUME_NONNULL_END
