@interface SBCoverSheetPresentationManager: NSObject
+ (id)sharedInstance;
- (BOOL)isPresented;
@end

@interface SBControlCenterController: NSObject
+ (id)sharedInstance;
- (BOOL)isVisible;
@end

@interface PerfectSunInfo: NSObject
{
    UIWindow *sunriseSunsetInfoWindow;
    UILabel *sunriseSunsetInfoLabel;
    UIColor *backupForegroundColor;
    UIColor *backupBackgroundColor;
}
- (id)init;
- (void)updateOrientation;
- (void)updateFrame;
- (void)updateSunriseSunsetLabelSize;
- (void)updateTextColor:(UIColor *)color;
- (void)openDoubleTapApp;
- (void)openHoldApp;
- (void)hideIfNeeded;
@end

@interface UIScreen ()
- (CGRect)_referenceBounds;
@end

@interface UIWindow ()
- (void)_setSecure:(BOOL)arg1;
@end

@interface SBApplication: NSObject
-(NSString*)bundleIdentifier;
@end

@interface SpringBoard: UIApplication
- (id)_accessibilityFrontMostApplication;
-(void)frontDisplayDidChange: (id)arg1;
@end

@interface UIApplication ()
- (UIDeviceOrientation)_frontMostAppOrientation;
- (BOOL)launchApplicationWithIdentifier:(id)arg1 suspended:(BOOL)arg2;
@end

@interface SBMainSwitcherViewController: UIViewController
- (BOOL)isMainSwitcherVisible;
@end