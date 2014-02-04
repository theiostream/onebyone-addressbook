TARGET = ::4.3
ARCHS = armv7 arm64

include theos/makefiles/common.mk

TWEAK_NAME = OneByOneContacts
OneByOneContacts_FILES = Tweak.xm
OneByOneContacts_FRAMEWORKS = AddressBook UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp OBOContactsPreferences.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/OBOContactsPreferences.plist$(ECHO_END)
	$(ECHO_NOTHING)cp icon.png $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/OBOContacts.png$(ECHO_END)
