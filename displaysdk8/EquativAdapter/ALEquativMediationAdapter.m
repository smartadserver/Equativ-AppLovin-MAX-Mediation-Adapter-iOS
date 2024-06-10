//
//  ALEquativMediationAdapter.m
//
//  Created by Guillaume Laubier on 15/01/20234

#import "ALEquativMediationAdapter.h"
#import <SASDisplayKit/SASDisplayKit.h>

#define SASImplementationInfo_PrimarySDKName            @"AppLovin"
#define SASImplementationInfo_MediationAdapterVersion   @"2.0"

#define SASErrorCodeNoAd           30103
#define SASErrorCodeLoadingTimeout 20001

@interface ALEquativMediationAdapter() <SASBannerViewDelegate, SASInterstitialManagerDelegate>

/// Banner related properties
@property (nonatomic, nullable) SASBannerView *bannerView;
@property (assign) id<MAAdViewAdapterDelegate> maxAdViewAdapterDelegate;

/// Interstitial related properties
@property (nonatomic, nullable) SASInterstitialManager *interstitialManager;
@property (assign) id<MAInterstitialAdapterDelegate> maxInterstitialAdapterDelegate;

@end

@implementation ALEquativMediationAdapter

#pragma mark -- Util method

/**
 Convert the raw placement string to an SASAdPlacement model object.
 The raw placement string is the value set in PlacementId section of your custom network.
 
 The raw placement string should validate the following format: <site id>/<page id>/<format id>[/<targeting string> (optional)]
 ex: 123/456/789/targeting=string or 123/456/879
 
 @param rawAdPlacement The raw placement string that will be used to create SASAdPlacement object.
 @return a SASAdPlacement if the rawAdPlacement is valid, nil otherwise.
 */
- (nullable SASAdPlacement *)placementWith:(nullable NSString *)rawAdPlacement {
    // Quick fail if the given string is null or empty
    if (rawAdPlacement == nil || rawAdPlacement.length == 0) {
        return nil;
    }
    
    int siteID = 0;
    int pageID = 0;
    int formatID = 0;
    NSString *targeting = nil;
    
    // Processing the server parameter string
    NSArray<NSString *> *stringComponents = [rawAdPlacement componentsSeparatedByString:@"/"];
    if (stringComponents.count > 2 && stringComponents.count < 5) {
        siteID = [stringComponents[0] intValue];
        pageID = [stringComponents[1] intValue];
        formatID = [stringComponents[2] intValue];
        
        if (stringComponents.count == 4) {
            targeting = stringComponents[3];
        }
    }
    
    if (siteID == 0 || pageID == 0 || formatID == 0) {
        return nil;
    }
    
    return [[SASAdPlacement alloc] initWithSiteId:siteID pageId:pageID formatId:formatID keywordTargeting:targeting];
}

#pragma mark -- ALMediationAdapter implementation

- (void)initializeWithParameters:(id<MAAdapterInitializationParameters>)parameters completionHandler:(void (^)(MAAdapterInitializationStatus, NSString * _Nullable))completionHandler {
    [SASConfiguration sharedInstance].secondaryImplementationInfo = [[SASSecondaryImplementationInfo alloc] initWithPrimarySDKName:SASImplementationInfo_PrimarySDKName primarySDKVersion:ALSdk.version mediationAdapterVersion:SASImplementationInfo_MediationAdapterVersion];
    completionHandler(MAAdapterInitializationStatusDoesNotApply, nil);
}

-  (void)destroy {
    self.bannerView = nil;
}

- (NSString *)SDKVersion {
    return [SASFrameworkInfo sharedInstance].frameworkVersionString;
}

- (NSString *)adapterVersion {
    return SASImplementationInfo_MediationAdapterVersion;
}

#pragma mark -- MAAdViewAdapter implementation

- (void)loadAdViewAdForParameters:(nonnull id<MAAdapterResponseParameters>)parameters adFormat:(nonnull MAAdFormat *)adFormat andNotify:(nonnull id<MAAdViewAdapterDelegate>)delegate {
    SASAdPlacement *adPlacement = [self placementWith:parameters.thirdPartyAdPlacementIdentifier];
    
    if (adPlacement == nil) {
        [self log:@"The PlacementId found is not a valid Equativ placement. This placement should be formatted like: <site id>/<page id>/<format id>[/<targeting string> (optional)] (ex: 123/456/789/targetingString or 123/456/789). The invalid found PlacementId string: %@", parameters.thirdPartyAdPlacementIdentifier];
        [delegate didFailToLoadAdViewAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeInvalidConfiguration]];
        return;
    }
    
    self.maxAdViewAdapterDelegate = delegate;
    
    // Configure SASDisplayKit with siteID
    [[SASConfiguration sharedInstance] configure];
    
    if (self.bannerView == nil) {
        self.bannerView = [[SASBannerView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, adFormat.size.height)];
        self.bannerView.delegate = self;
    }
    
    [self.bannerView loadAdWithAdPlacement:adPlacement];
}

- (void)bannerView:(nonnull SASBannerView *)bannerView didLoadWithInfo:(nonnull SASAdInfo *)adInfo {
    if (self.maxAdViewAdapterDelegate != nil && [self.maxAdViewAdapterDelegate respondsToSelector:@selector(didLoadAdForAdView:)]) {
        [self.maxAdViewAdapterDelegate didLoadAdForAdView:self.bannerView];
    }
    
    if (self.maxAdViewAdapterDelegate != nil && [self.maxAdViewAdapterDelegate respondsToSelector:@selector(didDisplayAdViewAd)]) {
        [self.maxAdViewAdapterDelegate didDisplayAdViewAd];
    }
}

- (void)bannerView:(nonnull SASBannerView *)bannerView didFailToLoadWithError:(nonnull NSError *)error {
    if (self.maxAdViewAdapterDelegate != nil && [self.maxAdViewAdapterDelegate respondsToSelector:@selector(didFailToLoadAdViewAdWithError:)]) {
        if (error.code == SASErrorCodeNoAd) {
            [self.maxAdViewAdapterDelegate didFailToLoadAdViewAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeNoFill]];
        } else if (error.code == SASErrorCodeLoadingTimeout) {
            [self.maxAdViewAdapterDelegate didFailToLoadAdViewAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeTimeout]];
        } else {
            [self.maxAdViewAdapterDelegate didFailToLoadAdViewAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeUnspecified]];
        }
    }
}

- (void)bannerViewClicked:(SASBannerView *)bannerView {
    if (self.maxAdViewAdapterDelegate != nil && [self.maxAdViewAdapterDelegate respondsToSelector:@selector(didClickAdViewAd)]) {
        [self.maxAdViewAdapterDelegate didClickAdViewAd];
    }
}

- (void)bannerViewDidRequestClose:(SASBannerView *)bannerView {
    // Nothing to do
}

#pragma mark -- MAInterstitialAdapter implementation

- (void)loadInterstitialAdForParameters:(nonnull id<MAAdapterResponseParameters>)parameters andNotify:(nonnull id<MAInterstitialAdapterDelegate>)delegate {
    SASAdPlacement *adPlacement = [self placementWith:parameters.thirdPartyAdPlacementIdentifier];
    
    if (adPlacement == nil) {
        [self log:@"The PlacementId found is not a valid Equativ placement. This placement should be formatted like: <site id>/<page id>/<format id>[/<targeting string> (optional)] (ex: 123/456/789/targetingString or 123/456/789). The invalid found PlacementId string: %@", parameters.thirdPartyAdPlacementIdentifier];
        if ([delegate respondsToSelector:@selector(didFailToLoadInterstitialAdWithError:)]) {
            [delegate didFailToLoadInterstitialAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeInvalidConfiguration]];
        }
        return;
    }
    
    self.maxInterstitialAdapterDelegate = delegate;
    
    // Configure SASDisplayKit with siteID
    [[SASConfiguration sharedInstance] configure];
    
    // reset interstitial manager
    self.interstitialManager = nil;
    
    self.interstitialManager = [[SASInterstitialManager alloc] initWithAdPlacement:adPlacement];
    self.interstitialManager.delegate = self;
    
    [self.interstitialManager loadAd];
}

- (void)showInterstitialAdForParameters:(nonnull id<MAAdapterResponseParameters>)parameters andNotify:(nonnull id<MAInterstitialAdapterDelegate>)delegate {
    if (self.interstitialManager != nil && self.interstitialManager.adStatus == SASAdStatusReady) {
        UIViewController *presentingViewController = parameters.presentingViewController != nil ? parameters.presentingViewController : [ALUtils topViewControllerFromKeyWindow];
        
        [self.interstitialManager showFromViewController:presentingViewController];
        
    } else if ([delegate respondsToSelector:@selector(didFailToDisplayInterstitialAdWithError:)]) {
        // failure management
        [delegate didFailToDisplayInterstitialAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeAdNotReady]];
    }
}

- (void)interstitialManager:(nonnull SASInterstitialManager *)interstitialManager didLoadWithInfo:(nonnull SASAdInfo *)adInfo {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didLoadInterstitialAd)]) {
        [self.maxInterstitialAdapterDelegate didLoadInterstitialAd];
    }
}

- (void)interstitialManager:(nonnull SASInterstitialManager *)interstitialManager didFailToLoadWithError:(nonnull NSError *)error {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didFailToLoadInterstitialAdWithError:)]) {
        if (error.code == SASErrorCodeNoAd) {
            [self.maxInterstitialAdapterDelegate didFailToLoadInterstitialAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeNoFill]];
        } else if (error.code == SASErrorCodeLoadingTimeout) {
            [self.maxInterstitialAdapterDelegate didFailToLoadInterstitialAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeTimeout]];
        } else {
            [self.maxInterstitialAdapterDelegate didFailToLoadInterstitialAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeUnspecified]];
        }
    }
}

- (void)interstitialManagerDidShow:(SASInterstitialManager *)interstitialManager {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didDisplayInterstitialAd)]) {
        [self.maxInterstitialAdapterDelegate didDisplayInterstitialAd];
    }
}

- (void)interstitialManager:(SASInterstitialManager *)interstitialManager didFailToShowWithError:(NSError *)error {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didFailToDisplayInterstitialAdWithError:)]) {
        [self.maxInterstitialAdapterDelegate didFailToDisplayInterstitialAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeInternalError]];
    }
}

- (void)interstitialManagerDidClose:(SASInterstitialManager *)interstitialManager {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didHideInterstitialAd)]) {
        [self.maxInterstitialAdapterDelegate didHideInterstitialAd];
    }
}

- (void)interstitialManagerClicked:(SASInterstitialManager *)interstitialManager {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didClickInterstitialAd)]) {
        [self.maxInterstitialAdapterDelegate didClickInterstitialAd];
    }
}

@end
