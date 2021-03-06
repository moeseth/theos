ifeq ($(_THEOS_PACKAGE_RULES_LOADED),)
_THEOS_PACKAGE_RULES_LOADED := 1

.PHONY: package internal-before-package before-package internal-package after-package

# For the toplevel invocation of make, mark 'all' and the *-package rules as prerequisites.
# We do not do this for anything else, because otherwise, all the packaging rules would run for every subproject.
ifeq ($(_THEOS_TOP_INVOCATION_DONE),)
_THEOS_HAS_DPKG_DEB := $(shell PATH="$(THEOS_BIN_PATH):$$PATH" type dpkg-deb > /dev/null 2>&1 && echo 1 || echo 0)
ifeq ($(_THEOS_HAS_DPKG_DEB),1)
package:: stage before-package internal-package after-package
else # _THEOS_HAS_DPKG_DEB == 0
package::
	@echo "$(MAKE) package requires dpkg-deb."; exit 1
endif

install:: before-install internal-install after-install
else # _THEOS_TOP_INVOCATION_DONE
package::
install::
endif

FAKEROOT := $(THEOS_BIN_PATH)/fakeroot.sh -p "$(THEOS_PROJECT_DIR)/.theos/fakeroot"
export FAKEROOT

# Only do the master packaging rules if we're the toplevel make invocation.
ifeq ($(_THEOS_TOP_INVOCATION_DONE),)
ifeq ($(_THEOS_CAN_PACKAGE),1) # Control file found (or layout/ found.)

THEOS_PACKAGE_NAME := $(shell grep "^Package:" "$(_THEOS_PACKAGE_CONTROL_PATH)" | cut -d' ' -f2)
THEOS_PACKAGE_ARCH := $(shell grep "^Architecture:" "$(_THEOS_PACKAGE_CONTROL_PATH)" | cut -d' ' -f2)
THEOS_PACKAGE_VERSION := $(shell grep "^Version:" "$(_THEOS_PACKAGE_CONTROL_PATH)" | cut -d' ' -f2)

THEOS_PACKAGE_DEBVERSION = $(shell grep "^Version:" "$(THEOS_STAGING_DIR)/DEBIAN/control" | cut -d' ' -f2)

THEOS_PACKAGE_FILENAME = $(THEOS_PACKAGE_NAME)_$(THEOS_PACKAGE_DEBVERSION)_$(THEOS_PACKAGE_ARCH)

FW_DEVICE_USER ?= root

ifdef FW_DEVICE_TUNNEL
FW_DEVICE_PORT = 2222
FW_DEVICE_IP = 127.0.0.1
else
FW_DEVICE_PORT ?= 22
endif

$(_THEOS_ESCAPED_STAGING_DIR)/DEBIAN/control:
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/DEBIAN"$(ECHO_END)
ifeq ($(_THEOS_HAS_STAGING_LAYOUT),1) # If we have a layout/ directory, copy layout/DEBIAN to the staging directory.
	$(ECHO_NOTHING)rsync -a "$(THEOS_PROJECT_DIR)/layout/DEBIAN/" "$(THEOS_STAGING_DIR)/DEBIAN" $(_THEOS_RSYNC_EXCLUDE_COMMANDLINE)$(ECHO_END)
endif # _THEOS_HAS_STAGING_LAYOUT
ifdef FINALPACKAGE
	$(ECHO_NOTHING)cat "$(_THEOS_PACKAGE_CONTROL_PATH)" > "$(THEOS_STAGING_DIR)/DEBIAN/control"$(ECHO_END)
else
	$(ECHO_NOTHING)$(THEOS_BIN_PATH)/package_version.sh -c "$(_THEOS_PACKAGE_CONTROL_PATH)" $(if $(PACKAGE_BUILDNAME),-e $(PACKAGE_BUILDNAME),) > "$(THEOS_STAGING_DIR)/DEBIAN/control"$(ECHO_END)
endif
	$(ECHO_NOTHING)echo "Installed-Size: $(shell du $(_THEOS_PLATFORM_DU_EXCLUDE) DEBIAN -ks "$(THEOS_STAGING_DIR)" | cut -f 1)" >> "$(THEOS_STAGING_DIR)/DEBIAN/control"$(ECHO_END)

internal-before-package:: $(_THEOS_ESCAPED_STAGING_DIR)/DEBIAN/control

internal-package::
	$(ECHO_NOTHING)$(FAKEROOT) -r dpkg-deb -b "$(THEOS_STAGING_DIR)" "$(THEOS_PROJECT_DIR)/$(THEOS_PACKAGE_FILENAME).deb" $(STDERR_NULL_REDIRECT)$(ECHO_END)

else # _THEOS_CAN_PACKAGE == 0
internal-before-package::
	@echo "$(MAKE) package requires you to have a layout/ directory in the project root, containing the basic package structure, or a control file in the project root describing the package."; exit 1

internal-package::

endif # _THEOS_CAN_PACKAGE

endif # _THEOS_TOP_INVOCATION_DONE

before-package:: internal-before-package
after-package::

before-install::
after-install:: internal-after-install
internal-after-install::

endif # _THEOS_PACKAGE_RULES_LOADED
