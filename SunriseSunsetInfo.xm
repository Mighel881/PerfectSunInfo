#import "SunriseSunsetInfo.h"
#import "SparkAppList.h"
#import "SparkColourPickerUtils.h"
#import <Cephei/HBPreferences.h>
#import <PeterDev/libpddokdo.h>

#define DegreesToRadians(degrees) (degrees * M_PI / 180)

static float const _3_HOURS = 60 * 60 * 3;

static double screenWidth;
static double screenHeight;
static UIDeviceOrientation orientationOld;

__strong static id sunriseSunsetInfoObject;

NSDateFormatter *dateFormatter;

static HBPreferences *pref;
static BOOL enabled;
static BOOL showOnLockScreen;
static BOOL showSunrise;
static NSString *sunrisePrefix;
static BOOL showSunset;
static NSString *sunsetPrefix;
static NSString *separator;
static BOOL showSecondTimeInNewLine;
static BOOL backgroundColorEnabled;
static float backgroundCornerRadius;
static BOOL customBackgroundColorEnabled;
static UIColor *customBackgroundColor;
static double portraitX;
static double portraitY;
static double landscapeX;
static double landscapeY;
static BOOL followDeviceOrientation;
static double width;
static double height;
static long fontSize;
static BOOL boldFont;
static BOOL customTextColorEnabled;
static UIColor *customTextColor;
static long alignment;
static BOOL enableBlackListedApps;
static NSArray *blackListedApps;

static BOOL isBlacklistedAppInFront = NO;

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
	if(followDeviceOrientation && sunriseSunsetInfoObject) 
		[sunriseSunsetInfoObject updateOrientation];
}

static void loadDeviceScreenDimensions()
{
	UIDeviceOrientation orientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
	if(orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight)
	{
		screenWidth = [[UIScreen mainScreen] bounds].size.height;
		screenHeight = [[UIScreen mainScreen] bounds].size.width;
	}
	else
	{
		screenWidth = [[UIScreen mainScreen] bounds].size.width;
		screenHeight = [[UIScreen mainScreen] bounds].size.height;
	}
}

@implementation UILabelWithInsets

- (void)drawTextInRect: (CGRect)rect
{
    UIEdgeInsets insets = {0, 5, 0, 5};
    [super drawTextInRect: UIEdgeInsetsInsetRect(rect, insets)];
}

@end

@implementation SunriseSunsetInfo

	- (id)init
	{
		self = [super init];
		if(self)
		{
			@try
			{
				sunriseSunsetInfoWindow = [[UIWindow alloc] initWithFrame: CGRectMake(0, 0, width, height)];
				[sunriseSunsetInfoWindow setHidden: NO];
				[sunriseSunsetInfoWindow setAlpha: 1];
				[sunriseSunsetInfoWindow _setSecure: YES];
				[sunriseSunsetInfoWindow setUserInteractionEnabled: NO];
				[[sunriseSunsetInfoWindow layer] setAnchorPoint: CGPointZero];
				
				sunriseSunsetInfoLabel = [[UILabelWithInsets alloc] initWithFrame: CGRectMake(0, 0, width, height)];
				[[sunriseSunsetInfoLabel layer] setMasksToBounds: YES];
				[(UIView *)sunriseSunsetInfoWindow addSubview: sunriseSunsetInfoLabel];

				[self updateFrame];

				[NSTimer scheduledTimerWithTimeInterval: _3_HOURS target: self selector: @selector(updateText) userInfo: nil repeats: YES];

				CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("com.apple.springboard.screenchanged"), NULL, 0);
				CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("UIWindowDidRotateNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
			}
			@catch (NSException *e) {}
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
		if(showOnLockScreen) [sunriseSunsetInfoWindow setWindowLevel: 1051];
		else [sunriseSunsetInfoWindow setWindowLevel: 1000];

		[self updateSunriseSunsetInfoLabelProperties];
		[self updateSunriseSunsetInfoSize];

		orientationOld = nil;
		[self updateOrientation];
	}

	- (void)updateSunriseSunsetInfoLabelProperties
	{
		if(boldFont) [sunriseSunsetInfoLabel setFont: [UIFont boldSystemFontOfSize: fontSize]];
		else [sunriseSunsetInfoLabel setFont: [UIFont systemFontOfSize: fontSize]];

		[sunriseSunsetInfoLabel setNumberOfLines: showSecondTimeInNewLine ? 2 : 1];

		[sunriseSunsetInfoLabel setTextAlignment: alignment];

		if(customTextColorEnabled)
			[sunriseSunsetInfoLabel setTextColor: customTextColor];

		if(!backgroundColorEnabled)
			[sunriseSunsetInfoLabel setBackgroundColor: [UIColor clearColor]];
		else
		{
			[[sunriseSunsetInfoLabel layer] setCornerRadius: backgroundCornerRadius];
			[[sunriseSunsetInfoLabel layer] setContinuousCorners: YES];
			
			if(customBackgroundColorEnabled)
				[sunriseSunsetInfoLabel setBackgroundColor: customBackgroundColor];
		}
	}

	- (void)updateSunriseSunsetInfoSize
	{
		CGRect frame = [sunriseSunsetInfoLabel frame];
		frame.size.width = width;
		frame.size.height = height;
		[sunriseSunsetInfoLabel setFrame: frame];

		frame = [sunriseSunsetInfoWindow frame];
		frame.size.width = width;
		frame.size.height = height;
		[sunriseSunsetInfoWindow setFrame: frame];
	}

	- (void)updateOrientation
	{
		if(!followDeviceOrientation)
		{
			CGRect frame = [sunriseSunsetInfoWindow frame];
			frame.origin.x = portraitX;
			frame.origin.y = portraitY;
			[sunriseSunsetInfoWindow setFrame: frame];
		}
		else
		{
			UIDeviceOrientation orientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
			if(orientation == orientationOld)
				return;
			
			CGAffineTransform newTransform;
			CGRect frame = [sunriseSunsetInfoWindow frame];

			switch (orientation)
			{
				case UIDeviceOrientationLandscapeRight:
				{
					frame.origin.x = landscapeY;
					frame.origin.y = screenHeight - landscapeX;
					newTransform = CGAffineTransformMakeRotation(-DegreesToRadians(90));
					break;
				}
				case UIDeviceOrientationLandscapeLeft:
				{
					frame.origin.x = screenWidth - landscapeY;
					frame.origin.y = landscapeX;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(90));
					break;
				}
				case UIDeviceOrientationPortraitUpsideDown:
				{
					frame.origin.x = screenWidth - portraitX;
					frame.origin.y = screenHeight - portraitY;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(180));
					break;
				}
				case UIDeviceOrientationPortrait:
				default:
				{
					frame.origin.x = portraitX;
					frame.origin.y = portraitY;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(0));
					break;
				}
			}

			[UIView animateWithDuration: 0.3f animations:
			^{
				[sunriseSunsetInfoWindow setTransform: newTransform];
				[sunriseSunsetInfoWindow setFrame: frame];
				orientationOld = orientation;
			} completion: nil];
		}
	}

	- (void)updateText
	{
		if(sunriseSunsetInfoWindow && sunriseSunsetInfoLabel)
		{
			[sunriseSunsetInfoLabel setText: formattedString()];
		}
	}

	- (void)updateTextColor: (UIColor*)color
	{
		CGFloat r;
    	[color getRed: &r green: nil blue: nil alpha: nil];
		if(r == 0 || r == 1)
		{
			if(!customTextColorEnabled) [sunriseSunsetInfoLabel setTextColor: color];
			if(backgroundColorEnabled && !customBackgroundColorEnabled) 
			{
				if(r == 0) [sunriseSunsetInfoLabel setBackgroundColor: [[UIColor whiteColor] colorWithAlphaComponent: 0.5]];
				else [sunriseSunsetInfoLabel setBackgroundColor: [[UIColor blackColor] colorWithAlphaComponent: 0.5]];
			}	

		}
	}

	- (void)setHidden: (BOOL)arg
	{
		[sunriseSunsetInfoWindow setHidden: arg];
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

	[sunriseSunsetInfoObject setHidden: isBlacklistedAppInFront];
}

%end

%hook SBCoverSheetPresentationManager

-(BOOL)isPresented
{
	BOOL isPresented = %orig;

	if(isPresented || !isBlacklistedAppInFront)
		[sunriseSunsetInfoObject setHidden: NO];
	else
		[sunriseSunsetInfoObject setHidden: YES];

	return isPresented;
}

%end

%hook _UIStatusBar

-(void)setForegroundColor: (UIColor*)color
{
	%orig;
	
	if(sunriseSunsetInfoObject && [self styleAttributes] && [[self styleAttributes] imageTintColor]) 
		[sunriseSunsetInfoObject updateTextColor: [[self styleAttributes] imageTintColor]];
}

%end

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if(!pref) pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.sunrisesunsetinfoprefs"];
	enabled = [pref boolForKey: @"enabled"];
	showOnLockScreen = [pref boolForKey: @"showOnLockScreen"];
	showSunrise = [pref boolForKey: @"showSunrise"];
	sunrisePrefix = [pref objectForKey: @"sunrisePrefix"];
	showSunset = [pref boolForKey: @"showSunset"];
	sunsetPrefix = [pref objectForKey: @"sunsetPrefix"];
	showSecondTimeInNewLine = [pref boolForKey: @"showSecondTimeInNewLine"];
	separator = [pref objectForKey: @"separator"];
	backgroundColorEnabled = [pref boolForKey: @"backgroundColorEnabled"];
	backgroundCornerRadius = [pref floatForKey: @"backgroundCornerRadius"];
	customBackgroundColorEnabled = [pref boolForKey: @"customBackgroundColorEnabled"];
	portraitX = [pref floatForKey: @"portraitX"];
	portraitY = [pref floatForKey: @"portraitY"];
	landscapeX = [pref floatForKey: @"landscapeX"];
	landscapeY = [pref floatForKey: @"landscapeY"];
	followDeviceOrientation = [pref boolForKey: @"followDeviceOrientation"];
	width = [pref floatForKey: @"width"];
	height = [pref floatForKey: @"height"];
	fontSize = [pref integerForKey: @"fontSize"];
	boldFont = [pref boolForKey: @"boldFont"];
	customTextColorEnabled = [pref boolForKey: @"customTextColorEnabled"];
	alignment = [pref integerForKey: @"alignment"];
	enableBlackListedApps = [pref boolForKey: @"enableBlackListedApps"];

	if(backgroundColorEnabled && customBackgroundColorEnabled || customTextColorEnabled)
	{
		NSDictionary *preferencesDictionary = [NSDictionary dictionaryWithContentsOfFile: @"/var/mobile/Library/Preferences/com.johnzaro.sunrisesunsetinfoprefs.colors.plist"];
		customBackgroundColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customBackgroundColor"] withFallback: @"#000000:0.50"];
		customTextColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customTextColor"] withFallback: @"#FF9400"];
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
		[pref registerDefaults:
		@{
			@"enabled": @NO,
			@"showOnLockScreen": @NO,
			@"showSunrise": @NO,
			@"sunrisePrefix": @"↑",
			@"showSunset": @NO,
			@"sunsetPrefix": @"↓",
			@"showSecondTimeInNewLine": @NO,
			@"separator": @" ",
			@"backgroundColorEnabled": @NO,
			@"backgroundCornerRadius": @6,
			@"customBackgroundColorEnabled": @NO,
			@"portraitX": @5,
			@"portraitY": @32,
			@"landscapeX": @5,
			@"landscapeY": @32,
			@"followDeviceOrientation": @NO,
			@"width": @82,
			@"height": @12,
			@"fontSize": @8,
			@"boldFont": @NO,
			@"customTextColorEnabled": @NO,
			@"alignment": @1,
			@"enableBlackListedApps": @NO
    	}];

		settingsChanged(NULL, NULL, NULL, NULL, NULL);

		if(enabled)
		{
			dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setDateFormat: @"H:mm"];

			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("com.johnzaro.sunrisesunsetinfoprefs/reloadprefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);

			%init;
		}
	}
}