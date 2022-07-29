# vim: ft=make ts=4 sw=4 noet
#
# The contents of this file are subject to the Apache 2.0 license you may not
# use this file except in compliance with the License.
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
# for the specific language governing rights and limitations under the
# License.
#
#
# Copyright 2017 DFT project (http://www.debianfirmwaretoolkit.org).
# All rights reserved. Use is subject to license terms.
#
#
# Even if this work is a complete rewrite, it is originally derivated work based
# upon mGAR build system from OpenCSW project (http://www.opencsw.org).
#
# Copyright 2001 Nick Moffitt: GAR ports system
# Copyright 2006 Cory Omand: Scripts and add-on make modules, except where otherwise noted.
# Copyright 2008 Dagobert Michelsen (OpenCSW): Enhancements to the CSW GAR system
# Copyright 2008-2013 Open Community Software Association: Packaging content
#
#
# Contributors list :
#
#    William Bonnet     wllmbnnt@gmail.com, wbonnet@theitmakers.com
#
#

# ------------------------------------------------------------------------------
#
# Protection against multiple includes
#
$(info included dft.target-build.mk)
ifdef DFT_BUILDSYSTEM_TARGET_BUILD
$(error dft.target-build.mk has already been included)
else
define DFT_BUILDSYSTEM_TARGET_BUILD
endef
# the matching endif teminates this file

# ------------------------------------------------------------------------------
#
# Build the target binaries
#

BUILD_TARGETS ?= $(addprefix build-,$(BUILD_CHECK_SCRIPTS)) $(addprefix build-,$(BUILD_SCRIPTS))

build : configure $(OBJ_DIR) pre-build $(BUILD_TARGETS) post-build
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)


# ------------------------------------------------------------------------------
#
# Rebuild the target binaries
#

REBUILD_TARGETS ?= $(addprefix rebuild-,$(BUILD_CHECK_SCRIPTS)) $(addprefix rebuild-,$(BUILD_SCRIPTS))

rebuild : configure pre-rebuild $(REBUILD_TARGETS) build post-rebuild
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# Execute the building script
#

build-%/Makefile :
	@if test -f $(COOKIE_DIR)/build-$*/Makefile ; then \
		true ; \
	else \
		echo "        running make in $*"  ; \
		$(BUILD_ENV) $(MAKE) -C $(abspath $(OBJ_DIR)) $(BUILD_PROCESS_COUNT) $(BUILD_FLAGS) \
		                                  $(BUILD_ARGS) ; \
	fi ;
	@$(TARGET_DONE)

rebuild-%/Makefile :
	@if test -f $(COOKIE_DIR)/build-$*/Makefile ; then \
		rm -f $(COOKIE_DIR)/build-$*/Makefile ; \
	fi ;
	$(TARGET_DONE)



# ------------------------------------------------------------------------------
#
# Definition of the package that must be installed on each build platform
#

PREREQUISITE_BASE_PKGS ?= make
PREREQUISITE_BASE_PKGS_UBUNTU ?= build-essential
PREREQUISITE_BASE_PKGS_DEBIAN ?= build-essential

# ------------------------------------------------------------------------------
# Match initial ifdef
endif
