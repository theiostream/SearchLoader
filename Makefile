TARGET = ::4.3

ARCHS = armv7 arm64

include theos/makefiles/common.mk

## Install Scripts
TOOL_NAME = postinst prerm
postinst_FILES = postinst.m
postinst_INSTALL_PATH = /DEBIAN
prerm_FILES = prerm.m
prerm_INSTALL_PATH = /DEBIAN

## libspotlight
LIBRARY_NAME = libspotlight
libspotlight_FILES = TLLibrary.m
libspotlight_PRIVATE_FRAMEWORKS = Search

## SearchLoader
TWEAK_NAME = SearchLoader
SearchLoader_FILES = TLDomainHooker.xm
SearchLoader_LDFLAGS = -lspotlight
SearchLoader_PRIVATE_FRAMEWORKS = Search

## Preferences
BUNDLE_NAME = SearchLoaderPreferences
SearchLoaderPreferences_INSTALL_PATH = /Library/PreferenceBundles/
SearchLoaderPreferences_FILES = TLPreferences.mm
SearchLoaderPreferences_FRAMEWORKS = UIKit
SearchLoaderPreferences_PRIVATE_FRAMEWORKS = Preferences

## Theos
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/tool.mk
include $(THEOS_MAKE_PATH)/bundle.mk

## Create SearchLoader Directories
internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/SearchLoader/$(ECHO_END)
	$(ECHO_NOTHING)mkdir $(THEOS_STAGING_DIR)/Library/SearchLoader/SearchBundles/$(ECHO_END)
	$(ECHO_NOTHING)mkdir $(THEOS_STAGING_DIR)/Library/SearchLoader/Internal/$(ECHO_END)
	$(ECHO_NOTHING)mkdir $(THEOS_STAGING_DIR)/Library/SearchLoader/Preferences/$(ECHO_END)
	$(ECHO_NOTHING)mkdir $(THEOS_STAGING_DIR)/Library/SearchLoader/Missing/$(ECHO_END)

	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp TLPreferences.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
#	$(ECHO_NOTHING)cp TLPreferences.png $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)

## (Local) Move libspotlight.dylib to $THEOS/lib
after-stage::
	$(ECHO_NOTHING)cp ./obj/libspotlight.dylib $(THEOS)/lib$(ECHO_END)

## (theos experimental-rebased branch: Restart backboardd, searchd and AppIndexer)
internal-after-install::
	install.exec "killall -9 backboardd searchd AppIndexer &>/dev/null"
