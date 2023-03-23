//
//  ALEquativMediationAdapter.m
//  AppLovinSample
//
//  Created by Guillaume Laubier on 20/03/2023.
//

#import "ALEquativMediationAdapter.h"
#import <SASDisplayKit/SASDisplayKit.h>

#define SASErrorCodeNoAd           1
#define SASErrorCodeLoadingTimeout 6

@interface ALEquativMediationAdapter() <SASBannerViewDelegate, SASInterstitialManagerDelegate, SASRewardedVideoManagerDelegate>

/// Banner related properties
@property (nonatomic, nullable) SASBannerView *bannerView;
@property (assign) id<MAAdViewAdapterDelegate> maxAdViewAdapterDelegate;

/// Interstitial related properties
@property (nonatomic, nullable) SASInterstitialManager *interstitialManager;
@property (assign) id<MAInterstitialAdapterDelegate> maxInterstitialAdapterDelegate;

/// Rewarded related properties
@property (nonatomic, nullable) SASRewardedVideoManager *rewardedVideoManager;
@property (assign) id<MARewardedAdapterDelegate> maxRewardedAdapterDelegate;

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
    [SASConfiguration sharedInstance].primarySDK = NO;
    completionHandler(MAAdapterInitializationStatusDoesNotApply, nil);
}

-  (void)destroy {
    self.bannerView = nil;
}

- (NSString *)SDKVersion {
    return [SASFrameworkInfo sharedInstance].frameworkVersionString;
}

- (NSString *)adapterVersion {
    return @"1.0";
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
    [[SASConfiguration sharedInstance] configureWithSiteId:adPlacement.siteId];
    
    if (self.bannerView == nil) {
        self.bannerView = [[SASBannerView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, adFormat.size.height)];
        self.bannerView.delegate = self;
    }
    
    [self.bannerView loadWithPlacement:adPlacement];
}

- (void)bannerViewDidLoad:(SASBannerView *)bannerView {
    if (self.maxAdViewAdapterDelegate != nil && [self.maxAdViewAdapterDelegate respondsToSelector:@selector(didLoadAdForAdView:)]) {
        [self.maxAdViewAdapterDelegate didLoadAdForAdView:self.bannerView];
    }
    
    if (self.maxAdViewAdapterDelegate != nil && [self.maxAdViewAdapterDelegate respondsToSelector:@selector(didDisplayAdViewAd)]) {
        [self.maxAdViewAdapterDelegate didDisplayAdViewAd];
    }
}

- (void)bannerView:(SASBannerView *)bannerView didFailToLoadWithError:(NSError *)error {
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

- (void)bannerView:(SASBannerView *)bannerView didClickWithURL:(NSURL *)URL {
    if (self.maxAdViewAdapterDelegate != nil && [self.maxAdViewAdapterDelegate respondsToSelector:@selector(didClickAdViewAd)]) {
        [self.maxAdViewAdapterDelegate didClickAdViewAd];
    }
}

- (void)bannerView:(SASBannerView *)bannerView didExpandWithFrame:(CGRect)frame {
    if (self.maxAdViewAdapterDelegate != nil && [self.maxAdViewAdapterDelegate respondsToSelector:@selector(didExpandAdViewAd)]) {
        [self.maxAdViewAdapterDelegate didExpandAdViewAd];
    }
}

- (void)bannerViewDidCollapse:(SASBannerView *)bannerView {
    if (self.maxAdViewAdapterDelegate != nil && [self.maxAdViewAdapterDelegate respondsToSelector:@selector(didCollapseAdViewAd)]) {
        [self.maxAdViewAdapterDelegate didCollapseAdViewAd];
    }
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
    [[SASConfiguration sharedInstance] configureWithSiteId:adPlacement.siteId];
    
    // reset interstitial manager
    self.interstitialManager = nil;
    
    self.interstitialManager = [[SASInterstitialManager alloc] initWithPlacement:adPlacement delegate:self];
    
    [self.interstitialManager load];
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

- (void)interstitialManager:(SASInterstitialManager *)manager didLoadAd:(SASAd *)ad {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didLoadInterstitialAd)]) {
        [self.maxInterstitialAdapterDelegate didLoadInterstitialAd];
    }
}

- (void)interstitialManager:(SASInterstitialManager *)manager didFailToLoadWithError:(NSError *)error {
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

- (void)interstitialManager:(SASInterstitialManager *)manager didFailToShowWithError:(NSError *)error {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didFailToDisplayInterstitialAdWithError:)]) {
        [self.maxInterstitialAdapterDelegate didFailToDisplayInterstitialAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeInternalError]];
    }
}

- (void)interstitialManager:(SASInterstitialManager *)manager didAppearFromViewController:(UIViewController *)viewController {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didDisplayInterstitialAd)]) {
        [self.maxInterstitialAdapterDelegate didDisplayInterstitialAd];
    }
}

- (void)interstitialManager:(SASInterstitialManager *)manager didDisappearFromViewController:(UIViewController *)viewController {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didHideInterstitialAd)]) {
        [self.maxInterstitialAdapterDelegate didHideInterstitialAd];
    }
}

- (void)interstitialManager:(SASInterstitialManager *)manager didClickWithURL:(NSURL *)URL {
    if (self.maxInterstitialAdapterDelegate != nil && [self.maxInterstitialAdapterDelegate respondsToSelector:@selector(didClickInterstitialAd)]) {
        [self.maxInterstitialAdapterDelegate didClickInterstitialAd];
    }
}

#pragma mark -- MARewardedAdapter implementation

- (void)loadRewardedAdForParameters:(nonnull id<MAAdapterResponseParameters>)parameters andNotify:(nonnull id<MARewardedAdapterDelegate>)delegate {
    SASAdPlacement *adPlacement = [self placementWith:parameters.thirdPartyAdPlacementIdentifier];
    
    if (adPlacement == nil) {
        [self log:@"The PlacementId found is not a valid Equativ placement. This placement should be formatted like: <site id>/<page id>/<format id>[/<targeting string> (optional)] (ex: 123/456/789/targetingString or 123/456/789). The invalid found PlacementId string: %@", parameters.thirdPartyAdPlacementIdentifier];
        
        if ([delegate respondsToSelector:@selector(didFailToLoadRewardedAdWithError:)]) {
            [delegate didFailToLoadRewardedAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeInvalidConfiguration]];
        }
        
        return;
    }
    
    self.maxRewardedAdapterDelegate = delegate;
    
    // Configure SASDisplayKit with siteID
    [[SASConfiguration sharedInstance] configureWithSiteId:adPlacement.siteId];
    
    // reset interstitial manager
    self.rewardedVideoManager = nil;
    
    self.rewardedVideoManager = [[SASRewardedVideoManager alloc] initWithPlacement:adPlacement delegate:self];
    
    [self.rewardedVideoManager load];
}

- (void)showRewardedAdForParameters:(nonnull id<MAAdapterResponseParameters>)parameters andNotify:(nonnull id<MARewardedAdapterDelegate>)delegate {
    if (self.rewardedVideoManager != nil && self.rewardedVideoManager.adStatus == SASAdStatusReady) {
        UIViewController *presentingViewController = parameters.presentingViewController != nil ? parameters.presentingViewController : [ALUtils topViewControllerFromKeyWindow];
        
        [self.rewardedVideoManager showFromViewController:presentingViewController];
        
    } else if ([delegate respondsToSelector:@selector(didFailToDisplayRewardedAdWithError:)]) {
        // failure management
        [delegate didFailToDisplayRewardedAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeAdNotReady]];
    }
}

- (void)rewardedVideoManager:(SASRewardedVideoManager *)manager didLoadAd:(SASAd *)ad {
    if (self.maxRewardedAdapterDelegate != nil && [self.maxRewardedAdapterDelegate respondsToSelector:@selector(didLoadRewardedAd)]) {
        [self.maxRewardedAdapterDelegate didLoadRewardedAd];
    }
}

- (void)rewardedVideoManager:(SASRewardedVideoManager *)manager didFailToLoadWithError:(NSError *)error {
    if (self.maxRewardedAdapterDelegate != nil && [self.maxRewardedAdapterDelegate respondsToSelector:@selector(didFailToLoadRewardedAdWithError:)]) {
        if (error.code == SASErrorCodeNoAd) {
            [self.maxRewardedAdapterDelegate didFailToLoadRewardedAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeNoFill]];
        } else if (error.code == SASErrorCodeLoadingTimeout) {
            [self.maxRewardedAdapterDelegate didFailToLoadRewardedAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeTimeout]];
        } else {
            [self.maxRewardedAdapterDelegate didFailToLoadRewardedAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeUnspecified]];
        }
    }
}

- (void)rewardedVideoManager:(SASRewardedVideoManager *)manager didAppearFromViewController:(UIViewController *)viewController {
    if (self.maxRewardedAdapterDelegate != nil && [self.maxRewardedAdapterDelegate respondsToSelector:@selector(didDisplayRewardedAd)]) {
        [self.maxRewardedAdapterDelegate didDisplayRewardedAd];
    }
}

- (void)rewardedVideoManager:(SASRewardedVideoManager *)manager didDisappearFromViewController:(UIViewController *)viewController {
    if (self.maxRewardedAdapterDelegate != nil && [self.maxRewardedAdapterDelegate respondsToSelector:@selector(didHideRewardedAd)]) {
        [self.maxRewardedAdapterDelegate didHideRewardedAd];
    }
}

- (void)rewardedVideoManager:(SASRewardedVideoManager *)manager didFailToShowWithError:(NSError *)error {
    if (self.maxRewardedAdapterDelegate != nil && [self.maxRewardedAdapterDelegate respondsToSelector:@selector(didFailToDisplayRewardedAdWithError:)]) {
        [self.maxRewardedAdapterDelegate didFailToDisplayRewardedAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeInternalError]];
    }
}

- (void)rewardedVideoManager:(SASRewardedVideoManager *)manager didClickWithURL:(NSURL *)URL {
    if (self.maxRewardedAdapterDelegate != nil && [self.maxRewardedAdapterDelegate respondsToSelector:@selector(didClickRewardedAd)]) {
        [self.maxRewardedAdapterDelegate didClickRewardedAd];
    }
}

- (void)rewardedVideoManager:(SASRewardedVideoManager *)manager didSendVideoEvent:(SASVideoEvent)videoEvent {
    if (self.maxRewardedAdapterDelegate != nil) {
        if (videoEvent == SASVideoEventStart && [self.maxRewardedAdapterDelegate respondsToSelector:@selector(didStartRewardedAdVideo)]) {
            [self.maxRewardedAdapterDelegate didStartRewardedAdVideo];
        } else if (videoEvent == SASVideoEventComplete && [self.maxRewardedAdapterDelegate respondsToSelector:@selector(didCompleteRewardedAdVideo)]) {
            [self.maxRewardedAdapterDelegate didCompleteRewardedAdVideo];
        }
    }
}

- (void)rewardedVideoManager:(SASRewardedVideoManager *)manager didCollectReward:(SASReward *)reward {
    if (self.maxRewardedAdapterDelegate != nil && [self.maxRewardedAdapterDelegate respondsToSelector:@selector(didRewardUserWithReward:)]) {
        MAReward *maxReward = [MAReward rewardWithAmount:reward.amount.integerValue label:reward.currency];
        [self.maxRewardedAdapterDelegate didRewardUserWithReward:maxReward];
    }
}

@end
