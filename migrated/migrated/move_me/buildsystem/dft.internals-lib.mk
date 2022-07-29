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
$(info included dft.internals-lib.mk)
ifdef DFT_INTERNALS_LIB
$(error dft.internals-lib.mk has already been included)
else
define DFT_INTERNALS_LIB
endef
# the matching endif teminates this file


# ------------------------------------------------------------------------------
#
# archive extraction utilities
#
TAR_ARGS = --no-same-owner

extract-archive-%.tar :
	@if test -f $(COOKIE_DIR)/extract-archive-$*.tar ; then \
		true ; \
	else \
		echo "        extracting $(DOWNLOAD_DIR)/$*.tar" ; \
		tar $(TAR_ARGS) -xf $(DOWNLOAD_DIR)/$*.tar -C $(EXTRACT_DIR) ; \
	fi ;
	$(TARGET_DONE)

extract-archive-%.tar.gz :
	@if test -f $(COOKIE_DIR)/extract-archive-$*.tar.gz ; then \
		true ; \
	else \
		echo "        extracting $(DOWNLOAD_DIR)/$*.tar.gz" ; \
		tar $(TAR_ARGS) -xzf $(DOWNLOAD_DIR)/$*.tar.gz -C $(EXTRACT_DIR) ; \
	fi ;
	$(TARGET_DONE)

extract-archive-%.tgz :
	@if test -f $(COOKIE_DIR)/extract-archive-$*.tgz ; then \
		true ; \
	else \
		echo "        extracting $(DOWNLOAD_DIR)/$*.tgz" ; \
		tar $(TAR_ARGS) -xzf $(DOWNLOAD_DIR)/$*.tgz -C $(EXTRACT_DIR) ; \
	fi ;
	$(TARGET_DONE)

extract-archive-%.tar.bz2 :
	@if test -f $(COOKIE_DIR)/extract-archive-$*.tar.bz2 ; then \
		true ; \
	else \
		echo "        extracting $(DOWNLOAD_DIR)/$*.tar.bz2" ; \
		tar $(TAR_ARGS) -xjf $(DOWNLOAD_DIR)/$*.tar.bz2 -C $(EXTRACT_DIR) ; \
	fi ;
	$(TARGET_DONE)

extract-archive-%.tar.xz :
	@if test -f $(COOKIE_DIR)/extract-archive-$*.tar.xz ; then \
		true ; \
	else \
		echo "        extracting $(DOWNLOAD_DIR)/$*.tar.xz" ; \
		tar $(TAR_ARGS) -xJf $(DOWNLOAD_DIR)/$*.tar.xz -C $(EXTRACT_DIR) ; \
	fi ;
	$(TARGET_DONE)

extract-archive-%.zip :
	@if test -f $(COOKIE_DIR)/extract-archive-$*.zip ; then \
		true ; \
	else \
		echo "        extracting $(DOWNLOAD_DIR)/$*.zip" ; \
		unzip $(DOWNLOAD_DIR)/$*.zip -d $(EXTRACT_DIR) ; \
	fi ;
	$(TARGET_DONE)

extract-git-% :
	@if test -f $(COOKIE_DIR)/extract-git-$* ; then \
		true ; \
	else \
	  echo "        moving git data to $(EXTRACT)/$*" ; \
		mv $(GIT_EXTRACT_DIR)/$(KERNEL_GIT_REPO) $(EXTRACT_DIR)/$(SOFTWARE_FULLNAME) ; \
	fi ;
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# patch utilities
#
PATCH_DIR_LEVEL ?= 1
PATCH_DIR_FUZZ  ?= 2
PATCH_ARGS       = --directory=$(WORK_SRC) --strip=$(PATCH_DIR_LEVEL) --fuzz=$(PATCH_DIR_FUZZ)

apply-patch-% :
	@echo " ==> Applying $(PATCH_DIR)/$*"
	patch $(PATCH_ARGS) < $(PATCH_DIR)/$*
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# Directory maker used by the base rules
#
$(sort $(BUILD_SYSTEM_ROOT) $(FILE_DIR) $(GIT_EXTRACT_DIR) $(WORK_ROOT_DIR) $(WORK_DIR) $(PARTIAL_DIR) $(COOKIE_DIR) $(EXTRACT_DIR) $(WORK_SRC) $(OBJ_DIR) $(INSTALL_DIR) $(PACKAGE_DIR) $(LOG_DIR) $(DOWNLOAD_DIR) $(PATCH_DIR)):
	@if test -d $@; then : ; else \
		echo making $@; \
		install -d $@; \
	fi

$(COOKIE_DIR)/%:
	@if test -d $@; then : ; else \
		install -d $@; \
	fi

# Match initial ifndef DFT_INTERNALS_LIB
endif


