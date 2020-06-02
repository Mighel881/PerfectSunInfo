#import "SunriseSunsetInfo.h"
#import "SparkAppList.h"
#import "SparkColourPickerUtils.h"
#import <Cephei/HBPreferences.h>
#import <PeterDev/libpddokdo.h>

#define DegreesToRadians(degrees) (degrees * M_PI / 180)

static float const _3_HOURS = 60 * 60 * 3;

__strong static id sunriseSunsetInfoObject;

NSDateFormatter *dateFormatter;

static HBPreferences *pref;
static BOOL enabled;
static BOOL showOnLockScreen;
static BOOL showOnControlCenter;
static BOOL hideOnFullScreen;
static BOOL hideOnLandscape;
static BOOL showSunrise;
static NSString *sunrisePrefix;
static BOOL showSunset;
static NSString *sunsetPrefix;
static NSString *separator;
static BOOL showSecondTimeInNewLine;
static BOOL backgroundColorEnabled;
static NSInteger margin;
static CGFloat backgroundCornerRadius;
static BOOL customBackgroundColorEnabled;
static UIColor *customBackgroundColor;
static double portraitX;
static double portraitY;
static double landscapeX;
static double landscapeY;
static BOOL followDeviceOrientation;
static BOOL animateMovement;
static double width;
static double height;
static long fontSize;
static BOOL boldFont;
static BOOL customTextColorEnabled;
static UIColor *customTextColor;
static long alignment;
static BOOL enableDoubleTap;
static NSString *doubleTapIdentifier;
static BOOL enableHold;
static NSString *holdIdentifier;
static BOOL enableBlackListedApps;
static NSArray *blackListedApps;

static double screenWidth;
static double screenHeight;
static BOOL shouldHideBasedOnOrientation = NO;
static BOOL isBlacklistedAppInFront = NO;
static BOOL isLockScreenPresented;
static BOOL isControlCenterVisible;
static BOOL isOnLandscape;
static UIDeviceOrientation deviceOrientation;
static UIDeviceOrientation orientationOld;
static BOOL isStatusBarHidden;

static NSMutableString* formattedString()
{
	@autoreleasepool
	{
		PDDokdo *pDDokdo = [PDDokdo sharedInstance];
		[pDDokdo refreshWeatherData];

		NSMutableString* mutableString = [[NSMutableString alloc] init];
		if(showSunrise)
		{
			NSDate *sunrise = [pDDokdo sunrise];
			[mutableString appendString: [NSString stringWithFormat: @"%@%@", sunrisePrefix, sunrise ? [dateFormatter stringFromDate: sunrise] : @"--"]];
		}
		if(showSunset)
		{
			NSDate *sunset = [pDDokdo sunset];
			if([mutableString length] > 0)
			{
				if(showSecondTimeInNewLine) [mutableString appendString: @"\n"];
				else [mutableString appendString: separator];
			}
			[mutableString appendString: [NSString stringWithFormat: @"%@%@", sunsetPrefix, sunset ? [dateFormatter stringFromDate: sunset] : @"--"]];
		}
		return [mutableString copy];
	}
}

static void orientationChanged()
{
	deviceOrientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
	if(deviceOrientation == UIDeviceOrientationLandscapeRight || deviceOrientation == UIDeviceOrientationLandscapeLeft)
		isOnLandscape = YES;
	else
		isOnLandscape = NO;

	if((hideOnLandscape || followDeviceOrientation) && sunriseSunsetInfoObject) 
		[sunriseSunsetInfoObject updateOrientation];
}

static void loadDeviceScreenDimensions()
{
	screenWidth = [[UIScreen mainScreen] _referenceBounds].size.width;
	screenHeight = [[UIScreen mainScreen] _referenceBounds].size.height;
}

@implementation SunriseSunsetInfo

	- (id)init
	{
		self = [super init];
		if(self)
		{
			sunriseSunsetInfoLabel = [[UILabel alloc] initWithFrame: CGRectMake(0, 0, 0, 0)];
			[sunriseSunsetInfoLabel setAdjustsFontSizeToFitWidth: YES];

			UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(openDoubleTapApp)];
			[tapGestureRecognizer setNumberOfTapsRequired: 2];

			UILongPressGestureRecognizer *holdGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget: self action: @selector(openHoldApp)];

			sunriseSunsetInfoWindow = [[UIWindow alloc] initWithFrame: CGRectMake(0, 0, 0, 0)];
			[sunriseSunsetInfoWindow setWindowLevel: 100000];
			[sunriseSunsetInfoWindow _setSecure: YES];
			[[sunriseSunsetInfoWindow layer] setAnchorPoint: CGPointZero];
			[sunriseSunsetInfoWindow addSubview: sunriseSunsetInfoLabel];
			[sunriseSunsetInfoWindow addGestureRecognizer: tapGestureRecognizer];
			[sunriseSunsetInfoWindow addGestureRecognizer: holdGestureRecognizer];

			deviceOrientation = [[UIApplication sharedApplication] _frontMostAppOrientation];

			backupForegroundColor = [UIColor whiteColor];
			backupBackgroundColor = [[UIColor blackColor] colorWithAlphaComponent: 0.5];
			[self updateFrame];

			[NSTimer scheduledTimerWithTimeInterval: _3_HOURS target: self selector: @selector(updateText) userInfo: nil repeats: YES];

			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("com.apple.springboard.screenchanged"), NULL, 0);
			CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("UIWindowDidRotateNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		}
		return self;
	}

	- (void)updateFrame
	{
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_updateFrame) object: nil];
		[self performSelector: @selector(_updateFrame) withObject: nil afterDelay: 0.3];
	}

	- (void)_updateFrame
	{
		orientationOld = nil;

		if(!backgroundColorEnabled)
			[sunriseSunsetInfoWindow setBackgroundColor: [UIColor clearColor]];
		else
		{
			if(customBackgroundColorEnabled)
				[sunriseSunsetInfoWindow setBackgroundColor: customBackgroundColor];
			else
				[sunriseSunsetInfoWindow setBackgroundColor: backupBackgroundColor];

			[[sunriseSunsetInfoWindow layer] setCornerRadius: backgroundCornerRadius];
		}

		[self updateSunriseSunsetLabelProperties];
		[self updateSunriseSunsetLabelSize];
		[self updateOrientation];
	}

	- (void)updateSunriseSunsetLabelProperties
	{
		if(boldFont) [sunriseSunsetInfoLabel setFont: [UIFont boldSystemFontOfSize: fontSize]];
		else [sunriseSunsetInfoLabel setFont: [UIFont systemFontOfSize: fontSize]];

		[sunriseSunsetInfoLabel setNumberOfLines: showSecondTimeInNewLine ? 2 : 1];
		[sunriseSunsetInfoLabel setTextAlignment: alignment];

		if(customTextColorEnabled)
			[sunriseSunsetInfoLabel setTextColor: customTextColor];
		else
			[sunriseSunsetInfoLabel setTextColor: backupForegroundColor];
	}

	- (void)updateSunriseSunsetLabelSize
	{
		CGRect frame = [sunriseSunsetInfoLabel frame];
		frame.origin.x = margin;
		frame.origin.y = margin;
		frame.size.width = width - 2 * margin;
		frame.size.height = height - 2 * margin;
		[sunriseSunsetInfoLabel setFrame: frame];
	}

	- (void)updateOrientation
	{
		shouldHideBasedOnOrientation = hideOnLandscape && isOnLandscape;
		[self hideIfNeeded];

		if(deviceOrientation == orientationOld)
			return;

		CGAffineTransform newTransform;
		CGRect frame = [sunriseSunsetInfoWindow frame];

		if(!followDeviceOrientation || deviceOrientation == UIDeviceOrientationPortrait)
		{
			frame.origin.x = portraitX;
			frame.origin.y = portraitY;
			newTransform = CGAffineTransformMakeRotation(DegreesToRadians(0));
		}
		else if(deviceOrientation == UIDeviceOrientationLandscapeLeft)
		{
			frame.origin.x = screenWidth - landscapeY;
			frame.origin.y = landscapeX;
			newTransform = CGAffineTransformMakeRotation(DegreesToRadians(90));
		}
		else if(deviceOrientation == UIDeviceOrientationPortraitUpsideDown)
		{
			frame.origin.x = screenWidth - portraitX;
			frame.origin.y = screenHeight - portraitY;
			newTransform = CGAffineTransformMakeRotation(DegreesToRadians(180));
		}
		else if(deviceOrientation == UIDeviceOrientationLandscapeRight)
		{
			frame.origin.x = landscapeY;
			frame.origin.y = screenHeight - landscapeX;
			newTransform = CGAffineTransformMakeRotation(-DegreesToRadians(90));
		}

		frame.size.width = isOnLandscape && followDeviceOrientation ? height : width;
		frame.size.height = isOnLandscape && followDeviceOrientation ? width : height;

		if(animateMovement)
		{
			[UIView animateWithDuration: 0.3f animations:
			^{
				[sunriseSunsetInfoWindow setTransform: newTransform];
				[sunriseSunsetInfoWindow setFrame: frame];
				orientationOld = deviceOrientation;
			} completion: nil];
		}
		else
		{
			[sunriseSunsetInfoWindow setTransform: newTransform];
			[sunriseSunsetInfoWindow setFrame: frame];
			orientationOld = deviceOrientation;
		}
	}

	- (void)updateText
	{
		if(sunriseSunsetInfoWindow && sunriseSunsetInfoLabel)
			[sunriseSunsetInfoLabel setText: formattedString()];
	}

	- (void)updateTextColor: (UIColor*)color
	{
		backupForegroundColor = color;
		CGFloat r;
    	[color getRed: &r green: nil blue: nil alpha: nil];
		if(r == 0 || r == 1)
		{
			if(!customTextColorEnabled)
				[sunriseSunsetInfoLabel setTextColor: color];

			if(backgroundColorEnabled && !customBackgroundColorEnabled) 
			{
				if(r == 0)
					[sunriseSunsetInfoWindow setBackgroundColor: [[UIColor whiteColor] colorWithAlphaComponent: 0.5]];
				else
					[sunriseSunsetInfoWindow setBackgroundColor: [[UIColor blackColor] colorWithAlphaComponent: 0.5]];
				backupBackgroundColor = [sunriseSunsetInfoWindow backgroundColor];
			}
		}
	}

	- (void)hideIfNeeded
	{
		[sunriseSunsetInfoWindow setHidden: 
			isLockScreenPresented && !showOnLockScreen
		 || isStatusBarHidden && hideOnFullScreen
		 || isControlCenterVisible && !showOnControlCenter
		 || !isLockScreenPresented && (shouldHideBasedOnOrientation || isBlacklistedAppInFront)];
	}

	- (void)openDoubleTapApp
	{
		if(enableDoubleTap && doubleTapIdentifier)
			[[UIApplication sharedApplication] launchApplicationWithIdentifier: doubleTapIdentifier suspended: NO];
	}

	- (void)openHoldApp
	{
		if(enableHold && holdIdentifier)
			[[UIApplication sharedApplication] launchApplicationWithIdentifier: holdIdentifier suspended: NO];
	}

@end

%hook SpringBoard

- (void)applicationDidFinishLaunching: (id)application
{
	%orig;

	loadDeviceScreenDimensions();
	if(!sunriseSunsetInfoObject) 
	{
		sunriseSunsetInfoObject = [[SunriseSunsetInfo alloc] init];
		[sunriseSunsetInfoObject updateText];
	}
}

-(void)frontDisplayDidChange: (id)arg1 
{
	%orig;

	NSString *currentApp = [(SBApplication*)[self _accessibilityFrontMostApplication] bundleIdentifier];
	isBlacklistedAppInFront = blackListedApps && currentApp && [blackListedApps containsObject: currentApp];
	[sunriseSunsetInfoObject hideIfNeeded];
}

%end

%hook SBCoverSheetPresentationManager

-(BOOL)isPresented
{
	isLockScreenPresented = %orig;
	[sunriseSunsetInfoObject hideIfNeeded];
	return isLockScreenPresented;
}

%end

%hook SBControlCenterController

-(BOOL)isVisible
{
	isControlCenterVisible = %orig;
	[sunriseSunsetInfoObject hideIfNeeded];
	return isControlCenterVisible;
}

%end

%hook _UIStatusBar

- (void)setStyle: (long long)style
{
	%orig;

	if(sunriseSunsetInfoObject) 
		[sunriseSunsetInfoObject updateTextColor: (style == 1) ? [UIColor whiteColor] : [UIColor blackColor]];
}

- (void)setStyle: (long long)style forPartWithIdentifier: (id)arg2
{
	%orig;

	if(sunriseSunsetInfoObject) 
		[sunriseSunsetInfoObject updateTextColor: (style == 1) ? [UIColor whiteColor] : [UIColor blackColor]];
}

%end

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)_applyStatusBarHidden: (BOOL)arg1 withAnimation: (long long)arg2 toSceneWithIdentifier: (id)arg3
{
	isStatusBarHidden = arg1;
	[sunriseSunsetInfoObject hideIfNeeded];
	%orig;
}

%end

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if(backgroundColorEnabled && customBackgroundColorEnabled || customTextColorEnabled)
	{
		NSDictionary *preferencesDictionary = [NSDictionary dictionaryWithContentsOfFile: @"/var/mobile/Library/Preferences/com.johnzaro.sunrisesunsetinfoprefs.colors.plist"];
		customBackgroundColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customBackgroundColor"] withFallback: @"#000000:0.50"];
		customTextColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customTextColor"] withFallback: @"#FF9400"];
	}

	if(enableDoubleTap)
	{
		NSArray *doubleTapApp = [SparkAppList getAppListForIdentifier: @"com.johnzaro.sunrisesunsetinfoprefs.gestureApps" andKey: @"doubleTapApp"];
		if(doubleTapApp && [doubleTapApp count] == 1)
			doubleTapIdentifier = doubleTapApp[0];
	}

	if(enableHold)
	{
		NSArray *holdApp = [SparkAppList getAppListForIdentifier: @"com.johnzaro.sunrisesunsetinfoprefs.gestureApps" andKey: @"holdApp"];
		if(holdApp && [holdApp count] == 1)
			holdIdentifier = holdApp[0];
	}

	if(enableBlackListedApps)
		blackListedApps = [SparkAppList getAppListForIdentifier: @"com.johnzaro.sunrisesunsetinfoprefs.blackListedApps" andKey: @"blackListedApps"];
	else
		blackListedApps = nil;

	if(sunriseSunsetInfoObject)
	{
		[sunriseSunsetInfoObject updateFrame];
		[sunriseSunsetInfoObject updateText];
	}
}

%ctor
{
	@autoreleasepool
	{
		pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.sunrisesunsetinfoprefs"];
		[pref registerBool: &enabled default: NO forKey: @"enabled"];
		if(enabled)
		{
			[pref registerBool: &showOnLockScreen default: NO forKey: @"showOnLockScreen"];
			[pref registerBool: &showOnControlCenter default: NO forKey: @"showOnControlCenter"];
			[pref registerBool: &hideOnFullScreen default: NO forKey: @"hideOnFullScreen"];
			[pref registerBool: &hideOnLandscape default: NO forKey: @"hideOnLandscape"];
			[pref registerBool: &showSunrise default: NO forKey: @"showSunrise"];
			[pref registerObject: &sunrisePrefix default: @"↑" forKey: @"sunrisePrefix"];
			[pref registerBool: &showSunset default: NO forKey: @"showSunset"];
			[pref registerObject: &sunsetPrefix default: @"↓" forKey: @"sunsetPrefix"];
			[pref registerBool: &showSecondTimeInNewLine default: NO forKey: @"showSecondTimeInNewLine"];
			[pref registerObject: &separator default: @" " forKey: @"separator"];
			[pref registerBool: &backgroundColorEnabled default: NO forKey: @"backgroundColorEnabled"];
			[pref registerInteger: &margin default: 3 forKey: @"margin"];
			[pref registerFloat: &backgroundCornerRadius default: 6 forKey: @"backgroundCornerRadius"];
			[pref registerBool: &customBackgroundColorEnabled default: NO forKey: @"customBackgroundColorEnabled"];
			[pref registerFloat: &portraitX default: 5 forKey: @"portraitX"];
			[pref registerFloat: &portraitY default: 32 forKey: @"portraitY"];
			[pref registerFloat: &landscapeX default: 5 forKey: @"landscapeX"];
			[pref registerFloat: &landscapeY default: 32 forKey: @"landscapeY"];
			[pref registerBool: &followDeviceOrientation default: NO forKey: @"followDeviceOrientation"];
			[pref registerBool: &animateMovement default: NO forKey: @"animateMovement"];
			[pref registerFloat: &width default: 82 forKey: @"width"];
			[pref registerFloat: &height default: 12 forKey: @"height"];
			[pref registerInteger: &fontSize default: 8 forKey: @"fontSize"];
			[pref registerBool: &boldFont default: NO forKey: @"boldFont"];
			[pref registerBool: &customTextColorEnabled default: NO forKey: @"customTextColorEnabled"];
			[pref registerInteger: &alignment default: 1 forKey: @"alignment"];
			[pref registerBool: &enableDoubleTap default: NO forKey: @"enableDoubleTap"];
			[pref registerBool: &enableHold default: NO forKey: @"enableHold"];
			[pref registerBool: &enableBlackListedApps default: NO forKey: @"enableBlackListedApps"];

			settingsChanged(NULL, NULL, NULL, NULL, NULL);
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("com.johnzaro.sunrisesunsetinfoprefs/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);

			dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setDateFormat: @"H:mm"];

			%init;
		}
	}
}