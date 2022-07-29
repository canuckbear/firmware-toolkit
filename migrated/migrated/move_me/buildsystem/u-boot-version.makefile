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
# Copyright 2016 DFT project (http://www.firmwaretoolkit.org).
# All rights reserved. Use is subject to license terms.
#
#
# Contributors list :
#
#    William Bonnet     wllmbnnt@gmail.com, wbonnet@theitmakers.com
#
#

# Defines variables specific to u-boot version level
SW_NAME          := u-boot
PATH_WORDS       := $(subst /, ,$(abspath Makefile))
SW_VERSIONFIELD  := $(shell echo $(PATH_WORDS) |  awk '{ print NF-1 }')
SW_VERSION       := $(shell echo $(PATH_WORDS) |  cut -d ' ' -f$(SW_VERSIONFIELD))

# Build system sould be available under board folder as a symlink. Keep it
# locally available under board folder computing a relative path is a nightmare
# and does not work in all cases. Environment variables are not git friendly
# since git add will loose variable name and generate an absolute path, which
# is not comptible with user need ans or workspace relocation nor packagng needs.
# better solutions wille be really welcomeds contributions.
# Include DFT build system shared Makfile includes
DFT_BUILDSYSTEM := buildsystem
include ../board.mk
include $(DFT_BUILDSYSTEM)/inc/u-boot.mk
include $(DFT_BUILDSYSTEM)/dft.mk

# ------------------------------------------------------------------------------
#
# Mandatory defines that have to be defined at least in the main Makefile
#

ifeq ($(SW_NAME),)
$(error SW_NAME is not set)
endif

ifeq ($(DOWNLOAD_TOOL),)
$(error DOWNLOAD_TOOL is not set)
endif

# u-boot version generic Makefile
#
# WARNING if you need to make any version specific modification or definition,
# Please take in consideration that you must not modify the content of this file.
# Otherwise it would modify the symlink target and become the new default value
# for all unmodified makefiles of all existing boards.

# Defines patches to apply to the upstream sources :
# PATCHFILES += 0000_some_patch.diff

# If you use the patch feature, please make a copy of this file to store
# the definition of the PATCHFILES variable. The previous line in comment is
# provided as an example of how to do it. Please duplicate, modify and
# uncomment the line. Files will be searched for in the files/ directory at
# the same level as this Makefile.

# Do not recurse the following subdirs
MAKE_FILTERS  = debian files patches

# ------------------------------------------------------------------------------
#
# Targets not associated with a file (aka PHONY)
#

sanity-check:
	@echo "sanity-check from u-boot-version.makefile"
	@echo "Checking u-boot $(SW_VERSION) package sanity for $(BOARD_NAME)" ;
	@if [ ! -f "../board.mk" ] ; then \
		echo "file board.mk is missing in directory ${CURDIR}/.." ; \
		$(call dft_error ,1911-1512) ; \
	fi ;
	@if [ ! -d "${CURDIR}/files" ] ; then \
		echo "files directory is missing in ${CURDIR}. It should contains a link to the markdown file install.$(SW_NAME)-$(BOARD_NAME).md needed by target package." ; \
		echo "You can fix this with the following commands : " ; \
		echo "mkdir -p $(shell pwd)/files" ; \
		echo "touch $(shell pwd)/files/.gitkeep" ; \
		echo "ln -s ../../files/install.$(SW_NAME)-$(BOARD_NAME).md $(shell pwd)/files/" ; \
		echo "git add $(shell pwd)/files" ; \
		echo "error 191115-11" ; \
		exit 1 ; \
	fi ;
	@if [ ! -L "files/install.$(SW_NAME)-$(BOARD_NAME).md" ] then
		echo "The link to the markdown file install.$(SW_NAME)-$(BOARD_NAME).md is missing in the ${CURDIR}/files directory." ;
		echo "You can fix this with the following commands : " ;
		mkdir -p ${CURDIR}/files ;
		touch ${CURDIR}/files/.gitkeep ;
		ln -s ../../files/install.$(SW_NAME)-$(BOARD_NAME).md ${CURDIR}/files/ ;
		echo git add ${CURDIR}/files ;
	fi ;
	s=`readlink files/install.$(SW_NAME)-$(BOARD_NAME).md` ;
	if [ ! "$$s" == "../../files/install.$(SW_NAME)-$(BOARD_NAME).md" ] then
		echo "The link to the markdown file in ${CURDIR}/files must target to ../../files/install.$(SW_NAME)-$(BOARD_NAME).md" ;
		echo "You can fix this with the following shell commands :" ; \
		echo "git rm -f files/install.$(SW_NAME)-$(BOARD_NAME).md || rm -f files/install.$(SW_NAME)-$(BOARD_NAME).md" ; \
		echo "ln -s ../../files/install.$(SW_NAME)-$(BOARD_NAME).md $(shell pwd)/files/" ; \
		echo "git add $(shell pwd)/files" ; \
		echo "exit 191120-02" ; \
		exit 1 ; \
	fi ;
	@if [ ! -d "$(shell pwd)/patches" ] ; then \
		echo "patches directory is missing in $(shell pwd). It is used to store patches to be applied on sources after extract and before build targets. By default it is an empty folder." ; \
		mkdir -p ${CURDIR}/files ; \
		touch ${CURDIR}/files/.gitkeep ; \
		ln -s ../files/install.$(SW_NAME)-$(BOARD_NAME).md ${CURDIR}/files/ ; \
		git add ${CURDIR}/files ; \
	fi ;
	@if [ ! -L "files/install.$(SW_NAME)-$(BOARD_NAME).md" ] ; then \
		echo "The link to the markdown file install.$(SW_NAME)-$(BOARD_NAME).md is missing in the ${CURDIR}/files directory." ; \
		echo "You can fix this with the following commands : " ; \
		mkdir -p ${CURDIR}/files ; \
		touch ${CURDIR}/files/.gitkeep ; \
		ln -s ../../files/install.$(SW_NAME)-$(BOARD_NAME).md ${CURDIR}/files/ ; \
		echo git add ${CURDIR}/files ; \
	fi ;
	s=`readlink files/install.$(SW_NAME)-$(BOARD_NAME).md` ;
	if [ ! "$$s" == "../../files/install.$(SW_NAME)-$(BOARD_NAME).md" ] ; then \
		echo "The link to the markdown file in ${CURDIR}/files must target to ../../files/install.$(SW_NAME)-$(BOARD_NAME).md" ; \
		echo "You can fix this with the following shell commands :" ; \
		git rm -f files/install.$(SW_NAME)-$(BOARD_NAME).md || rm -f files/install.$(SW_NAME)-$(BOARD_NAME).md ; \
		ln -s ../../files/install.$(SW_NAME)-$(BOARD_NAME).md ${CURDIR}/files/ ; \
		git add ${CURDIR}/files ; \
	fi ;
	@if [ ! -d "${CURDIR}/patches" ] ; then \
		echo "patches directory is missing in ${CURDIR}. It is used to store patches to be applied on sources after extract and before build targets. By default it is an empty folder." ; \
	fi ;
	@if [ ! -d "${CURDIR}/debian" ]  then
		echo "debian directory is missing in ${CURDIR}. It should contains the files needed to create the debian package for $(BOARD_NAME) u-boot." ;
		echo "error 191115-10" ;
		exit 1 ;
	fi ;
	@s=`readlink Makefile`;
	if [ !  "$$s" == "$(buildsystem)/u-boot-version.makefile" ]  then
		echo "Makefile symlink must link to $(buildsystem)/u-boot-version.makefile" ;
		echo "You can fix this with the following shell commands :" ;
		git rm -f Makefile || rm -f Makefile ;
		ln -s $(buildsystem)/u-boot-version.makefile Makefile ;
		git add Makefile ;
	fi ;

# Since u-boot tarball contains sudir sources have to be moves to the right location
# and hidden files and hidden empty dirs must be removed
post-extract:
#	@mv $(BUILD_DIR)/$(SW_NAME)-$(SW_VERSION)/* $(BUILD_DIR)/
#	@mv $(BUILD_DIR)/$(SW_NAME)-$(SW_VERSION)/.github $(BUILD_DIR)/
#	@mv $(BUILD_DIR)/$(SW_NAME)-$(SW_VERSION)/.checkpatch.conf $(BUILD_DIR)/
#	@mv $(BUILD_DIR)/$(SW_NAME)-$(SW_VERSION)/.gitignore $(BUILD_DIR)/
#	@mv $(BUILD_DIR)/$(SW_NAME)-$(SW_VERSION)/.mailmap $(BUILD_DIR)/
#	@mv $(BUILD_DIR)/$(SW_NAME)-$(SW_VERSION)/.travis.yml $(BUILD_DIR)/
