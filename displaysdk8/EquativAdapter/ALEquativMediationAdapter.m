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

@interface MAEquativNativeAd : MANativeAd

@property (nonatomic) SASNativeAdAssets *nativeAdAssets;
@property (nonatomic) SASNativeAdView *sasNativeAdView;
@property (atomic, weak, nullable) id<MANativeAdAdapterDelegate> nativeAdAdapterDelegate;

- (instancetype)initWithNativeAdAssets:(SASNativeAdAssets *)nativeAdAssets
                          nativeAdView:(SASNativeAdView *)nativeAdView
               nativeAdAdapterDelegate:(id<MANativeAdAdapterDelegate>)nativeAdAdapterDelegate
                          builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock;

@end

@interface ALEquativMediationAdapter() <SASBannerViewDelegate, SASInterstitialManagerDelegate, SASNativeAdViewDelegate>

/// Banner related properties
@property (nonatomic, nullable) SASBannerView *bannerView;
@property (assign) id<MAAdViewAdapterDelegate> maxAdViewAdapterDelegate;

/// Interstitial related properties
@property (nonatomic, nullable) SASInterstitialManager *interstitialManager;
@property (assign) id<MAInterstitialAdapterDelegate> maxInterstitialAdapterDelegate;

/// Native ad related properties
@property (atomic, nullable) SASNativeAdView *nativeAdView;
@property (atomic, weak, nullable) id<MANativeAdAdapterDelegate> maxNativeAdAdapterDelegate;
@property (atomic, strong, nullable) UIImage *nativeAdMainImage;

@end

@implementation ALEquativMediationAdapter

#pragma mark - Util method

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

#pragma mark - ALMediationAdapter implementation

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

#pragma mark - MAAdViewAdapter implementation

- (void)loadAdViewAdForParameters:(nonnull id<MAAdapterResponseParameters>)parameters adFormat:(nonnull MAAdFormat *)adFormat andNotify:(nonnull id<MAAdViewAdapterDelegate>)delegate {
    SASAdPlacement *adPlacement = [self placementWith:parameters.thirdPartyAdPlacementIdentifier];
    
    if (adPlacement == nil) {
        [self log:@"The PlacementId found is not a valid Equativ placement. This placement should be formatted like: <site id>/<page id>/<format id>[/<targeting string> (optional)] (ex: 123/456/789/targetingString or 123/456/789). The invalid found PlacementId string: %@", parameters.thirdPartyAdPlacementIdentifier];
        [delegate didFailToLoadAdViewAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeInvalidConfiguration]];
        return;
    }
    
    self.maxAdViewAdapterDelegate = delegate;
    
    // Configure SASDisplayKit
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

#pragma mark - MAInterstitialAdapter implementation

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
    
    // Configure SASDisplayKit
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

#pragma mark - MAInterstitialAdapter implementation

- (void)loadNativeAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MANativeAdAdapterDelegate>)delegate {
    SASAdPlacement *adPlacement = [self placementWith:parameters.thirdPartyAdPlacementIdentifier];
    
    // Placement validation
    if (adPlacement == nil) {
        [self log:@"The PlacementId found is not a valid Equativ placement. This placement should be formatted like: <site id>/<page id>/<format id>[/<targeting string> (optional)] (ex: 123/456/789/targetingString or 123/456/789). The invalid found PlacementId string: %@", parameters.thirdPartyAdPlacementIdentifier];
        
        if (delegate != nil && [delegate respondsToSelector:@selector(didFailToLoadNativeAdWithError:)]) {
            [delegate didFailToLoadNativeAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeInvalidConfiguration]];
        }
        
        return;
    }
    
    // Saving the AppLovin delegate for later use…
    self.maxNativeAdAdapterDelegate = delegate;
    
    // Switching to the main thread as this method is not guaranteed to be called on it!
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        // Configure SASDisplayKit
        [[SASConfiguration sharedInstance] configure];
        
        // Native ad view instance creation if needed
        if (weakSelf.nativeAdView == nil) {
            weakSelf.nativeAdView = [[SASNativeAdView alloc] initWithFrame:CGRectZero];
            weakSelf.nativeAdView.delegate = self;
        }
        
        // Native ad view loading
        [weakSelf.nativeAdView loadAdWithAdPlacement:adPlacement];
    });
}

- (void)nativeAdView:(SASNativeAdView *)nativeAdView didLoadWithInfo:(SASAdInfo *)adInfo nativeAdAssets:(SASNativeAdAssets *)nativeAdAssets {
    // Attempting to download the main image if needed because AppLovin does not seems to handle it automatically contrary to the icon image…
    __weak __typeof(self) weakSelf = self;
    [self asynchonousImageDownloadWithURL:nativeAdAssets.mainView.url completionHandler:^(UIImage *image) {
        // Saving the main image if any
        weakSelf.nativeAdMainImage = image;
        
        // Creating an AppLovin native ad object from the Equativ assets
        MANativeAd *nativeAd = [weakSelf createMAEquativNativeAdWithNativeAdAssets:nativeAdAssets
                                                                      nativeAdView:nativeAdView
                                                           nativeAdAdapterDelegate:weakSelf.maxNativeAdAdapterDelegate];
        
        // Returning the load success to AppLovin delegate
        [weakSelf.maxNativeAdAdapterDelegate didLoadAdForNativeAd:nativeAd withExtraInfo:nil];
    }];
}

- (void)asynchonousImageDownloadWithURL:(nullable NSURL *)imageURL completionHandler:(void(^)(UIImage * _Nullable ))completionHandler {
    if (imageURL != nil) {
        // Downloading the image if any
        NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithURL:imageURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (data != nil) {
                    // Returning the image in case of success
                    completionHandler([[UIImage alloc] initWithData:data]);
                } else {
                    // In case of failure, returning nil so it does not interrupt the loading process
                    completionHandler(nil);
                }
            });
        }];
        [task resume];
    } else {
        //  If no image, returning immediately instead
        completionHandler(nil);
    }
}

- (void)nativeAdView:(SASNativeAdView *)nativeAdView didFailToLoadWithError:(NSError *)error {
    // Choosing the relevant AppLovin error code depending on the Equativ error code
    if (error.code == SASErrorCodeNoAd) {
        [self.maxNativeAdAdapterDelegate didFailToLoadNativeAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeNoFill]];
    } else if (error.code == SASErrorCodeLoadingTimeout) {
        [self.maxNativeAdAdapterDelegate didFailToLoadNativeAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeTimeout]];
    } else {
        [self.maxNativeAdAdapterDelegate didFailToLoadNativeAdWithError:[MAAdapterError errorWithCode:MAAdapterError.errorCodeUnspecified]];
    }
}

- (MAEquativNativeAd *)createMAEquativNativeAdWithNativeAdAssets:(SASNativeAdAssets *)nativeAdAssets
                                                    nativeAdView:(SASNativeAdView *)nativeAdView
                                         nativeAdAdapterDelegate:(id<MANativeAdAdapterDelegate>)nativeAdAdapterDelegate {
    // Creating an AppLovin compatible native ad object from the Equativ assets
    return [[MAEquativNativeAd alloc] initWithNativeAdAssets:nativeAdAssets
                                                nativeAdView:nativeAdView
                                     nativeAdAdapterDelegate:nativeAdAdapterDelegate builderBlock:^(MANativeAdBuilder *builder) {
        // Binding all the common assets directly…
        builder.title = nativeAdAssets.title;
        builder.body = nativeAdAssets.body;
        builder.advertiser = nativeAdAssets.advertiser;
        builder.starRating = nativeAdAssets.rating;
        builder.callToAction = nativeAdAssets.callToAction;
        
        // The icon image can be handled automatically be AppLovin if necessary
        if (nativeAdAssets.iconImage.url != nil) {
            builder.icon = [[MANativeAdImage alloc] initWithURL:nativeAdAssets.iconImage.url];
        }
        
        // The main image must be handled manually:
        // it should have already been downloaded if relevant so we simply wrap it into an Image View if it exists…
        if (self.nativeAdMainImage != nil) {
            UIImageView *mediaView = [[UIImageView alloc] initWithImage:self.nativeAdMainImage];
            mediaView.contentMode = UIViewContentModeScaleAspectFit;
            builder.mediaView = mediaView;
        }
    }];
}

@end

@implementation MAEquativNativeAd

- (instancetype)initWithNativeAdAssets:(SASNativeAdAssets *)nativeAdAssets
                          nativeAdView:(SASNativeAdView *)nativeAdView
               nativeAdAdapterDelegate:(id<MANativeAdAdapterDelegate>)nativeAdAdapterDelegate
                          builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock {
    
    if (self = [super initWithFormat:MAAdFormat.native builderBlock:builderBlock]) {
        self.nativeAdAssets = nativeAdAssets;
        self.sasNativeAdView = nativeAdView;
        self.nativeAdAdapterDelegate = nativeAdAdapterDelegate;
    }
    
    return self;
}

- (BOOL)prepareForInteractionClickableViews:(NSArray<UIView *> *)clickableViews withContainer:(UIView *)container {
    // Tracking the third party mediation view to handle impression, viewability & clicks
    [self.sasNativeAdView trackMediationView:container];
    
    // Disabling interactions on all views except the container view: we don't want subviews to steal the click events
    // as only the container is tracked!
    for (UIView *view in clickableViews) {
        if (view != container) {
            view.userInteractionEnabled = NO;
        }
    }
    
    // Calling the AppLovin delegate to notify it that the view is ready for interaction
    if (self.nativeAdAdapterDelegate != nil && [self.nativeAdAdapterDelegate respondsToSelector:@selector(didDisplayNativeAdWithExtraInfo:)]) {
        [self.nativeAdAdapterDelegate didDisplayNativeAdWithExtraInfo:nil];
    }
    
    return YES;
}

@end
