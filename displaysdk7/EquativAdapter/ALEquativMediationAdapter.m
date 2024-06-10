//
//  ALEquativMediationAdapter.m
//
//  Created by Guillaume Laubier on 20/03/2023.
//

#import "ALEquativMediationAdapter.h"
#import <AppLovinSDK/AppLovinSDK.h>
#import <SASDisplayKit/SASDisplayKit.h>

#define SASImplementationInfo_PrimarySDKName            @"AppLovin"
#define SASImplementationInfo_MediationAdapterVersion   @"1.4"

#define SASErrorCodeNoAd           1
#define SASErrorCodeLoadingTimeout 6

NS_ASSUME_NONNULL_BEGIN

@interface MAEquativNativeAd : MANativeAd

@property (nonatomic) SASNativeAd *sasNativeAd;
@property (nonatomic, nullable) SASNativeAdMediaView *sasNativeAdMediaView;
@property (atomic, weak, nullable) id<MANativeAdAdapterDelegate> nativeAdAdapterDelegate;

- (instancetype)initWithSASNativeAd:(SASNativeAd *)sasNativeAd
            nativeAdAdapterDelegate:(id<MANativeAdAdapterDelegate>)nativeAdAdapterDelegate
                       builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock;
@end

@interface ALEquativMediationAdapter() <SASBannerViewDelegate, SASInterstitialManagerDelegate, SASRewardedVideoManagerDelegate>

/// Banner related properties
@property (nonatomic, nullable) SASBannerView *bannerView;
@property (atomic, weak, nullable) id<MAAdViewAdapterDelegate> maxAdViewAdapterDelegate;

/// Interstitial related properties
@property (nonatomic, nullable) SASInterstitialManager *interstitialManager;
@property (atomic, weak, nullable) id<MAInterstitialAdapterDelegate> maxInterstitialAdapterDelegate;

/// Rewarded related properties
@property (nonatomic, nullable) SASRewardedVideoManager *rewardedVideoManager;
@property (atomic, weak, nullable) id<MARewardedAdapterDelegate> maxRewardedAdapterDelegate;

/// Native ad related properties
@property (nonatomic, nullable) SASNativeAdManager *nativeAdManager;
@property (nonatomic, nullable) SASNativeAd *nativeAd;
@property (atomic, weak, nullable) id<MANativeAdAdapterDelegate> maxNativeAdAdapterDelegate;

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

#pragma mark -- MANativeAd implementation

- (void)loadNativeAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MANativeAdAdapterDelegate>)delegate {
    SASAdPlacement *adPlacement = [self placementWith:parameters.thirdPartyAdPlacementIdentifier];
    
    if (adPlacement == nil) {
        [self log:@"The PlacementId found is not a valid Equativ placement. This placement should be formatted like: <site id>/<page id>/<format id>[/<targeting string> (optional)] (ex: 123/456/789/targetingString or 123/456/789). The invalid found PlacementId string: %@", parameters.thirdPartyAdPlacementIdentifier];
        
        if (delegate != nil && [delegate respondsToSelector:@selector(didFailToLoadNativeAdWithError:)]) {
            [delegate didFailToLoadNativeAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeInvalidConfiguration]];
        }
        
        return;
    }
    
    self.maxNativeAdAdapterDelegate = delegate;
    
    // Configure SASDisplayKit with siteID
    [[SASConfiguration sharedInstance] configureWithSiteId:adPlacement.siteId];
    
    // Clean up if needed
    if (self.nativeAd != nil) {
        [self.nativeAd unregisterViews];
        self.nativeAd = nil;
    }
    
    self.nativeAdManager = nil;
    
    self.nativeAdManager = [[SASNativeAdManager alloc] initWithPlacement:adPlacement];
    [self.nativeAdManager requestAd:^(SASNativeAd * _Nullable nativeAd, NSError * _Nullable error) {
        if (nativeAd) {
            self.nativeAd = nativeAd;
            
            SASNativeAdMediaView *mediaView = nil;
            
            if (nativeAd.hasMedia) {
                mediaView = [[SASNativeAdMediaView alloc] initWithFrame:CGRectZero];
                [mediaView registerNativeAd:nativeAd];
                
                mediaView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
                mediaView.translatesAutoresizingMaskIntoConstraints = YES;
                
            } else if (nativeAd.coverImage != nil) {
                // MediaView has priority on cover image
                NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithURL:nativeAd.coverImage.URL
                                                                             completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable dataTaskError) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        UIImageView *coverImageView = nil;
                        
                        if (data != nil && dataTaskError == nil) {
                            coverImageView = [[UIImageView alloc] initWithImage:[[UIImage alloc] initWithData:data]];
                            coverImageView.contentMode = UIViewContentModeScaleAspectFit;
                        }
                        
                        // Create native only once cover image is downloaded
                        MANativeAd *maxNativeAd = [self createMAEquativNativeAdWithSASNativeAd:nativeAd nativeAdAdapterDelegate:delegate mediaView:coverImageView];
                        
                        if (delegate != nil && [delegate respondsToSelector:@selector(didLoadAdForNativeAd:withExtraInfo:)]) {
                            [delegate didLoadAdForNativeAd:maxNativeAd withExtraInfo:nil];
                        }
                    });
                }];
                
                [dataTask resume];
                
                // Quit the method has the delegate will be called in the URLSession
                return;
            }
            
            MAEquativNativeAd *maxNativeAd = [self createMAEquativNativeAdWithSASNativeAd:nativeAd nativeAdAdapterDelegate:delegate mediaView:mediaView];
            maxNativeAd.sasNativeAdMediaView = mediaView;
            
            if ([delegate respondsToSelector:@selector(didLoadAdForNativeAd:withExtraInfo:)]) {
                [delegate didLoadAdForNativeAd:maxNativeAd withExtraInfo:nil];
            }
            
        } else if (delegate != nil && [delegate respondsToSelector:@selector(didFailToLoadNativeAdWithError:)]) {
            // Error management
            if (error != nil && error.code == SASErrorCodeNoAd) {
                [delegate didFailToLoadNativeAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeNoFill]];
            } else if (error != nil && error.code == SASErrorCodeLoadingTimeout) {
                [delegate didFailToLoadNativeAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeTimeout]];
            } else {
                [delegate didFailToLoadNativeAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeUnspecified]];
            }
        }
    }];
}

- (MAEquativNativeAd *)createMAEquativNativeAdWithSASNativeAd:(SASNativeAd *)sasNativeAd
                                      nativeAdAdapterDelegate:(id<MANativeAdAdapterDelegate>)nativeAdAdapterDelegate
                                                    mediaView:(nullable UIView *)mediaView {
    
    return [[MAEquativNativeAd alloc] initWithSASNativeAd:sasNativeAd
                                  nativeAdAdapterDelegate:nativeAdAdapterDelegate
                                             builderBlock:^(MANativeAdBuilder * _Nonnull builder) {
        builder.title = sasNativeAd.title;
        builder.body = sasNativeAd.body;
        builder.starRating = [NSNumber numberWithFloat:sasNativeAd.rating];
        builder.callToAction = sasNativeAd.callToAction;
        
        if (sasNativeAd.icon != nil) {
            builder.icon = [[MANativeAdImage alloc] initWithURL:sasNativeAd.icon.URL];
        }
        
        if (mediaView != nil) {
            builder.mediaView = mediaView;
        }
    }];
}

@end

@implementation MAEquativNativeAd

- (instancetype)initWithSASNativeAd:(SASNativeAd *)sasNativeAd
            nativeAdAdapterDelegate:(id<MANativeAdAdapterDelegate>)nativeAdAdapterDelegate
                       builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock {
    if (self = [super initWithFormat:MAAdFormat.native builderBlock:builderBlock]) {
        self.sasNativeAd = sasNativeAd;
        self.nativeAdAdapterDelegate = nativeAdAdapterDelegate;
        return self;
    }
    return nil;
}

- (BOOL)prepareForInteractionClickableViews:(NSArray<UIView *> *)clickableViews withContainer:(UIView *)container {
    [self.sasNativeAd registerView:container tappableViews:clickableViews modalParentViewController:[ALUtils topViewControllerFromKeyWindow]];
    
    if (self.sasNativeAdMediaView != nil) {
        [self.sasNativeAdMediaView registerNativeAd:self.sasNativeAd];
    }
    
    if (self.nativeAdAdapterDelegate != nil && [self.nativeAdAdapterDelegate respondsToSelector:@selector(didDisplayNativeAdWithExtraInfo:)]) {
        [self.nativeAdAdapterDelegate didDisplayNativeAdWithExtraInfo:nil];
    }
    return YES;
}

@end

NS_ASSUME_NONNULL_END
