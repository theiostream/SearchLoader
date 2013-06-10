TARGET = ::4.3

include theos/makefiles/common.mk

## Install Scripts
TOOL_NAME = postinst prerm

postinst_FILES = postinst.mm
postinst_INSTALL_PATH = /DEBIAN

prerm_FILES = prerm.mm
prerm_INSTALL_PATH = /DEBIAN

## libspotlight
LIBRARY_NAME = libspotlight
libspotlight_FILES = TLLibrary.m

## SearchLoader
TWEAK_NAME = SearchLoader
SearchLoader_FILES = TLDomainHooker.xm #TLApplicationHooker.xm TLBundlePathHooker.xm
SearchLoader_LDFLAGS = -lspotlight
SearchLoader_PRIVATE_FRAMEWORKS = Search

## Theos
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/tool.mk

## Create SearchLoader Directories
internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/SearchLoader/$(ECHO_END)
	$(ECHO_NOTHING)mkdir $(THEOS_STAGING_DIR)/Library/SearchLoader/SearchBundles/$(ECHO_END)
	$(ECHO_NOTHING)mkdir $(THEOS_STAGING_DIR)/Library/SearchLoader/Internal/$(ECHO_END)
	$(ECHO_NOTHING)mkdir $(THEOS_STAGING_DIR)/Library/SearchLoader/Internal/OS6/$(ECHO_END)
	$(ECHO_NOTHING)mkdir $(THEOS_STAGING_DIR)/Library/SearchLoader/Missing/$(ECHO_END)

## (Local) Move libspotlight.dylib to $THEOS/lib
after-stage::
	$(ECHO_NOTHING)cp ./obj/libspotlight.dylib $(THEOS)/lib$(ECHO_END)

## (theos experimental-rebased branch: Restart backboardd, searchd and AppIndexer)
internal-after-install::
	install.exec "killall -9 backboardd searchd AppIndexer &>/dev/null"
