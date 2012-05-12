include theos/makefiles/common.mk

TWEAK_NAME = OneByOneContacts
OneByOneContacts_FILES = Tweak.xm
OneByOneContacts_FRAMEWORKS = AddressBook UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
