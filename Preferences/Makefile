ARCHS = arm64 arm64e
TARGET = iphone:clang:11.2:11.2

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PerfectSunInfoPrefs
PerfectSunInfoPrefs_FILES = SSIAppearanceSettings.m SSIRootHeaderView.mm SSIRootListController.xm
PerfectSunInfoPrefs_INSTALL_PATH = /Library/PreferenceBundles
PerfectSunInfoPrefs_FRAMEWORKS = UIKit
PerfectSunInfoPrefs_PRIVATE_FRAMEWORKS = Preferences
PerfectSunInfoPrefs_LIBRARIES = sparkcolourpicker sparkapplist
PerfectSunInfoPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
PerfectSunInfoPrefs_EXTRA_FRAMEWORKS = Cephei CepheiPrefs

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/PerfectSunInfoPrefs.plist$(ECHO_END)
