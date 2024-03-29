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

# Defines variables specific to Linux kernel
SW_NAME         := linux
PATH_WORDS      := $(subst /, ,$(abspath Makefile))
SW_VERSIONFIELD := $(shell echo $(PATH_WORDS) |  awk '{ print NF-1 }')
SW_VERSION      := $(shell echo $(PATH_WORDS) |  cut -d ' ' -f$(SW_VERSIONFIELD))

# Build system sould be available under board folder as a symlink. Keep it
# locally available under board folder computing a relative path is a nightmare
# and does not work in all cases. Environment variables are not git friendly
# since git add will loose variable name and generate an absolute path, which
# is not comptible with user need ans or workspace relocation nor packagng needs.
# better solutions wille be really welcomeds contributions.
buildsystem := buildsystem
include ../board.mk
include $(buildsystem)/inc/linux-kernel.mk
include $(buildsystem)/dft.mk

# Strip the variables defined in board.mk to remove trailing whitespaces or
# some calls will fail (when passing defconfig name etc.)
BOARD_NAME      := $(subst ,,$(BOARD_NAME))
BOARD_ARCH      := $(subst ,,$(BOARD_ARCH))
BOARD_FAMILY    ?= unknow-board-family
UBOOT_SUPPORT   := $(subst ,,$(UBOOT_SUPPORT))
UBOOT_DEFCONFIG := $(subst ,,$(UBOOT_DEFCONFIG))
USE_CONFIG_FILE := $(subst ,,$(USE_CONFIG_FILE))

# Retrieve th builder hot architecure if not defined yet
HOST_ARCH      ?= $(shell uname -m)

# Do not recurse the following subdirs
MAKE_FILTERS  := Makefile README.md debian patches

#
# Linux kernel configuration fragment to apply during make configure stage.
#

# Board hardware support fragments for any board, family and model specific
LINUX_KERNEL_BOARD_HW_COMMON_FRAGMENTS     ?= hardware/common/
LINUX_KERNEL_BOARD_HW_SPECIFIC_FRAGMENTS   ?= hardware/board-blueprints/$(BOARD_NAME)
LINUX_KERNEL_BOARD_HW_FAMILY_FRAGMENTS     ?= hardware/board-blueprints/$(BOARD_FAMILY)

# Board functioninal support fragments for any board, family and model specific
LINUX_KERNEL_BOARD_FUNC_COMMON_FRAGMENTS   ?= functional/common/
LINUX_KERNEL_BOARD_FUNC_SPECIFIC_FRAGMENTS ?= functional/board-blueprints/$(BOARD_NAME)
LINUX_KERNEL_BOARD_FUNC_FAMILY_FRAGMENTS   ?= functional/board-blueprints/$(BOARD_FAMILY)

# ------------------------------------------------------------------------------
#
# Mandatory defines that have to be defined at least in the main Makefile
#

ifndef SW_NAME
$(error SW_NAME is not set)
endif

ifndef DOWNLOAD_TOOL
$(error DOWNLOAD_TOOL is not set)
endif

# Defines patches to apply to the upstream sources :
# PATCHFILES += 0000_some_patch.diff

# If you use this patche feature please make a copy of this file to store
# version specific list of patches. You should not modify the target of the link,
# otherwise it would then behave as new default value for all unmodified versions
# of all existing boards.

sanity-check:
	@echo "Checking $(BOARD_NAME) kernel $(SW_VERSION) package definition"
	@if [ ! -f "../board.mk" ] ; then \
		echo "file board.mk is missing in directory ${CURDIR}//.." ; \
		$(call dft_error ,2011-2102) ; \
	fi ;
	@if [ ! -L "./Makefile" ] ; then \
		echo "Makefile symlink to buildsystem/linux-kernel-version.makefile is missing in ${CURDIR}/" ; \
		echo "You can fix with theyy following commands : " ; \
		echo "git rm -f ${CURDIR}//Makefile || rm -f ${CURDIR}//Makefile" ; \
		echo "ln -s buildsystem/$(SW_NAME)-kernel-version.makefile ${CURDIR}//Makefile" ; \
		echo "git add ${CURDIR}/Makefile" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2011-2201) ; \
	fi ;
	@if [ ! "$(shell readlink ./Makefile)" = "buildsystem/$(SW_NAME)-kernel-version.makefile" ] ; then \
		echo "The target of symlink Makefile should be buildsystem/$(SW_NAME)-kernel-version.makefile in directory ${CURDIR}/" ; \
		echo "You can fix with the following commands : " ; \
		echo "git rm -f ${CURDIR}//Makefile || rm -f ${CURDIR}/Makefile" ; \
		echo "ln -s $(buildsystem)/$(SW_NAME)-kernel-version.makefile ${CURDIR}/Makefile" ; \
		echo "git add ${CURDIR}/Makefile" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2011-2103) ; \
	fi ;
	@if [ ! -d "../config" ] ; then \
		echo "The directory storing kernel defconfig files is missing in ${CURDIR}/.." ; \
		echo "You can fix with the following commands : " ; \
		echo "mkdir ../config" ; \
		echo "touch ../config/.gitkeep" ; \
		echo "git add ../config" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2011-2101) ; \
	fi ;
	@if [ ! -e "../config/$(BOARD_NAME)-kernel-$(SW_VERSION).config" ] ; then \
		echo "The kernel kernel config file $(BOARD_NAME)-kernel-$(SW_VERSION).config is missing" ; \
		$(call dft_warning ,2004-2301) ; \
	fi ;
	@if [ ! -d "./debian" ] ; then \
		echo "The debian directory is missing in ${CURDIR}/. It should contain the files needed to create the debian package for $(BOARD_NAME) $(SW_NAME) kernel" ; \
		echo "You can fix with the following commands : TODO" ; \
		$(call dft_error ,2011-2104) ; \
	fi ;
	@if [ ! -L "./buildsystem" ] ; then \
		echo "The buildsystem symlink to ../../buildsystem is missing in ${CURDIR}/. You are using your own custom buildsystem" ; \
		echo "ln -s ../buildsystem ${CURDIR}//buildsystem" ; \
		echo "git add ${CURDIR}//buildsystem" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2011-2106) ; \
	fi ;
	@if [ ! "$(shell readlink ./buildsystem)" = "../buildsystem" ] ; then \
		echo "The target of symlink buildsystem should be ../buildsystem in directory ${CURDIR}" ; \
		echo "You can fix with the following commands : " ; \
		echo "git rm -f ${CURDIR}//buildsystem || rm -f ${CURDIR}//buildsystem" ; \
		echo "ln -s ../buildsystem ${CURDIR}//buildsystem" ; \
		echo "git add ${CURDIR}//buildsystem" ; \
		echo "make sanity-check" ; \
		echo "It is $(shell readlink ./buildsystem) in ${CURDIR}" ; \
		$(call dft_error ,2011-2108) ; \
	fi ;

# Simple forwarder just  in case
linux-kernel-package : package
kernel-package : package
