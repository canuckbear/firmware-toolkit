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
#		William Bonnet	 	wllmbnnt@gmail.com, wbonnet@theitmakers.com
#
#

# Defines variables specific to u-boot
SW_NAME    := u-boot

# Build system sould be available under board folder as a symlink. Keep it
# locally available under board folder computing a relative path is a nightmare
# and does not work in all cases. Environment variables are not git friendly
# since git add will loose variable name and generate an absolute path, which
# is not comptible with user need ans or workspace relocation nor packagng needs.
# better solutions wille be really welcomeds contributions.

DFT_BUILDSYSTEM := buildsystem
include ../board.mk
include $(DFT_BUILDSYSTEM)/inc/u-boot.mk
include $(DFT_BUILDSYSTEM)/dft.mk

# Strip the variables defined in board.mk to remove trailing whitespaces or
# some calls will fail (when passing defconfig name etc.)
BOARD_NAME      := $(subst ,,$(BOARD_NAME))
BOARD_ARCH      := $(subst ,,$(BOARD_ARCH))
UBOOT_SUPPORT   := $(subst ,,$(UBOOT_SUPPORT))
UBOOT_DEFCONFIG := $(subst ,,$(UBOOT_DEFCONFIG))
USE_CONFIG_FILE := $(subst ,,$(USE_CONFIG_FILE))

# default behavior is to process only th latest version
only-latest      ?= 1
only-native-arch ?= 0
arch-warning     ?= 0
verbosity        ?= "normal"

# Do not recurse the following subdirs
MAKE_FILTERS  := files defconfig Makefile README.md patches .

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

# ------------------------------------------------------------------------------
#
# Targets not associated with a file (aka PHONY)
#

#
# Board level directory generic u-boot kernel makefile
#

sanity-check:
	@echo "Checking $(BOARD_NAME) u-boot packages definition folder" ;
	@if [ $(UBOOT_SUPPORT) = 0  ] ; then \
		exit 0 ; \
	fi ;
	@echo "Checking $(BOARD_NAME) u-boot packages folder" ;
	if [ ! -L "Makefile"  ] ; then \
		echo "Makefile symlink $(DFT_BUILDSYSTEM)/u-boot.makefile is missing in directory ${CURDIR}" ; \
		echo "It has been fixed with following commands : " ; \
		echo "git rm -f ${CURDIR}/Makefile" ; \
		git rm -f ${CURDIR}/Makefile ; \
		echo "ln -s $(buildsystem)/u-boot.makefile ${CURDIR}/Makefile" ; \
		ln -sf $(buildsystem)/u-boot.makefile ${CURDIR}/Makefile ; \
		echo "git add ${CURDIR}/Makefile" ; \
		git add ${CURDIR}/Makefile ; \
	fi ;
	@if [ ! "$(shell readlink ./Makefile)" = "$(DFT_BUILDSYSTEM)/u-boot.makefile" ] ; then \
		echo "target of symlink Makefile should be $(DFT_BUILDSYSTEM)/u-boot.makefile in directory ${CURDIR}" ; \
		echo "You can fix with the following commands : " ; \
		echo "git rm -f ${CURDIR}/Makefile" ; \
		echo "ln -s $(DFT_BUILDSYSTEM)/u-boot.makefile ${CURDIR}/Makefile" ; \
		echo "git add ${CURDIR}/Makefile" ; \
		$(call dft_error ,2105-0202) ; \
		exit 1 ; \
	fi ;
	@if [ ! -d "${CURDIR}/files" ] ; then \
		echo "files directory is missing in ${CURDIR}. It should contains the markdown file install.u-boot-$(BOARD_NAME).md needed by target package." ; \
		echo "You can fix with the following commands : " ; \
		echo "mkdir -p ${CURDIR}/files" ; \
		echo "touch ${CURDIR}/files/.gitkeep" ; \
		echo "ln -s ../../files/install.$(SW_NAME)-$(BOARD_NAME).md ${CURDIR}/files/" ; \
		echo "git add ${CURDIR}/files" ; \
		$(call dft_error ,2105-0203) ; \
		exit 1 ; \
	fi ;  
	@if [ ! -d "${CURDIR}/files" ] ; then \
		echo "You can fix with the following commands : " ; \
		echo "mkdir -p ${CURDIR}/files" ; \
		echo "touch ${CURDIR}/files/.gitkeep" ; \
		echo "git add ${CURDIR}/files" ; \
		$(call dft_error ,2105-0209) ; \
		exit 1 ; \
	fi ;
	@if [ ! -f "${CURDIR}/files/install.$(SW_NAME)-$(BOARD_NAME).md" ] ; then \
		ls -lh "${CURDIR}/files/install.$(SW_NAME)-$(BOARD_NAME).md" ;  \
		echo "the $(SW_NAME) installation procedure is missing in the files/ folder. This folder should contain a file named install.$(SW_NAME)-$(BOARD_NAME).md describing. This file is needed by target package." ; \
		$(call dft_error ,2105-0204) ; \
		exit 1 ; \
	fi ;
	@if [ ! -L "board.mk" ] ; then \
		echo "board.mk symlink to ../board.mk is missing in directory ${CURDIR}" ; \
		echo "You can fix with the following commands : " ; \
		echo "ln -s ../board.mk board.mk" ; \
		echo "git add board.mk" ; \
		$(call dft_error ,2105-0205) ; \
		exit 1 ; \
	fi ;
	@if [ ! "$(shell readlink ${CURDIR}/board.mk)" = "../board.mk" ] ; then \
		echo "target of symlink board.mk should be ../board.mk in directory ${CURDIR}" ; \
		echo "You can fix with the following commands : " ; \
		echo "git rm -f ${CURDIR}/board.mk" ; \
		echo "ln -s ../board.mk ${CURDIR}/board.mk" ; \
		echo "git add ${CURDIR}/board.mk" ; \
		$(call dft_error ,2105-0206) ; \
		exit 1 ; \
	fi ;
	@for version in $(shell find . -mindepth 1 -maxdepth 1 -type d -name '*\.*' ) ; do \
	 echo "Checking $(BOARD_NAME) u-boot $$version package definition" ; \
         if [ ! -L "$$version/Makefile" ] ; then \
            echo "Makefile in ${CURDIR}/$$version was missing. It should be a symlink to $(DFT_BUILDSYSTEM)/u-boot-version.makefile" ; \
            ln -s ../$(DFT_BUILDSYSTEM)/u-boot-version.makefile $$version/Makefile ; \
            git add $$version/Makefile ; \
            exit 1 ; \
           fi ; \
           s=`readlink $$version/Makefile` ; \
           if [ !  "$$s" = "../$(DFT_BUILDSYSTEM)/u-boot-version.makefile" ] ; then \
               echo "Makefile symlink in $$version must link to $(DFT_BUILDSYSTEM)/u-boot-version.makefile" ; \
               echo "It has been fixed with the following shell commands :" ; \
               echo "git rm -f ${CURDIR}/$$version/Makefile || rm -f ${CURDIR}/$$version/Makefile" ; \
               git rm -f ${CURDIR}/$$version/Makefile || rm -f ${CURDIR}/$$version/Makefile ; \
               ln -s ../$(DFT_BUILDSYSTEM)/u-boot-version.makefile ${CURDIR}/$$version/Makefile ; \
               git add ${CURDIR}/$$version/Makefile ; \
            fi ; \
	done ; 
	@echo "before" ;
	@for version in $(shell find . -mindepth 1 -maxdepth 1 -type d  -name '*\.*' ) ; do \
		if [ -f $$version/Makefile ] ; then \
			cd $$version && $(MAKE) sanity-check ; \
		if [ ! "$(shell readlink ./Makefile)" = "$(DFT_BUILDSYSTEM)/u-boot.makefile" ] ; then \
			echo "target of symlink Makefile should be $(DFT_BUILDSYSTEM)/u-boot.makefile in directory ${CURDIR}" ; \
	if [ $(UBOOT_SUPPORT) = 1  ] ; then \
		echo "Checking $(BOARD_NAME) u-boot packages folder" ; \
		if [ ! -L "Makefile"  ] ; then \
			echo "Makefile symlink $(DFT_BUILDSYSTEM)/u-boot.makefile is missing in directory ${CURDIR}" ; \
			echo "You can fix with the following commands : " ; \
			echo "git rm -f ${CURDIR}/Makefile" ; \
			echo "ln -s $(DFT_BUILDSYSTEM)/u-boot.makefile ${CURDIR}/Makefile" ; \
			echo "git add ${CURDIR}/Makefile" ; \
			$(call dft_error ,2001-0810) ; \
		fi ; \
		if [ ! "$(shell readlink ./Makefile)" = "$(DFT_BUILDSYSTEM)/$(SW_NAME).makefile" ] ; then \
			echo "The target of symlink Makefile should be $(DFT_BUILDSYSTEM)/$(SW_NAME).makefile in directory ${CURDIR}" ; \
			echo "You can fix with the following commands : " ; \
			echo "git rm -f ${CURDIR}/Makefile" ; \
			echo "ln -s $(DFT_BUILDSYSTEM)/u-boot.makefile ${CURDIR}/Makefile" ; \
			echo "git add ${CURDIR}/Makefile" ; \
			$(call dft_error ,2001-0809) ; \
		fi ; \
		if [ ! -d "${CURDIR}/files" ] ; then \
			echo "The files directory is missing in ${CURDIR}. It should contains the markdown file install.u-boot-$(BOARD_NAME).md needed by target package." ; \
			echo "You can fix with the following commands : " ; \
			echo "mkdir -p ${CURDIR}/files" ; \
			echo "touch ${CURDIR}/files/.gitkeep" ; \
			echo "ln -s ../../files/install.$(SW_NAME)-$(BOARD_NAME).md ${CURDIR}/files/" ; \
			echo "git add ${CURDIR}/files" ; \
			$(call dft_error ,2001-0808) ; \
		fi ; \
		if [ ! -f "${CURDIR}/files/install.$(SW_NAME)-$(BOARD_NAME).md" ] ; then \
			ls -lh "${CURDIR}/files/install.$(SW_NAME)-$(BOARD_NAME).md" ;  \
			echo "the $(SW_NAME) installation procedure is missing in the files/ folder. This folder should contain a file named install.$(SW_NAME)-$(BOARD_NAME).md describing. This file is needed by target package." ; \
			$(call dft_error ,2001-0806) ; \
		fi ; \
		if [ ! -L "board.mk" ] ; then \
			echo "The board.mk symlink to ../board.mk is missing in directory ${CURDIR}" ; \
			echo "You can fix with the following commands : " ; \
			echo "ln -s ../board.mk board.mk" ; \
			echo "git add board.mk" ; \
			$(call dft_error ,2001-0805) ; \
		fi ; \
		if [ ! "$(shell readlink ${CURDIR}/board.mk)" = "../board.mk" ] ; then \
			echo "The target of symlink board.mk should be ../board.mk in directory ${CURDIR}" ; \
			echo "You can fix with the following commands : " ; \
			echo "git rm -f ${CURDIR}/board.mk" ; \
			echo "ln -s ../board.mk ${CURDIR}/board.mk" ; \
			echo "git add ${CURDIR}/board.mk" ; \
			echo "make sanity-check" ; \
			$(call dft_error ,2001-0804) ; \
		fi ; \
# first loop is to control that version makefile exist \
		for version in $(shell find . -mindepth 1 -maxdepth 1 -type d -name '*\.*' ) ; do \
			echo "Checking $(BOARD_NAME) u-boot $$version package definition" ; \
			if [ ! -L "$$version/Makefile" ] ; then \
				echo "version folder $$version" ; \
				echo "Makefile symlink in ${CURDIR}/$$version is missing. It should be a symlink to $(DFT_BUILDSYSTEM)/$(SW_NAME)-version.makefile" ; \
				echo "You can fix with the following shell commands :" ; \
				if [ -f "$$version/Makefile" ] ; then \
					echo "git rm ${CURDIR}//$$version/Makefile" ; \
				fi ; \
				echo "ln -s ../../$(DFT_BUILDSYSTEM)/$(SW_NAME)-version.makefile ${CURDIR}/$$version/Makefile" ; \
				echo "git add ${CURDIR}//$$version/Makefile" ; \
				echo "make sanity-check" ; \
				$(call dft_error ,1911-2118) ; \
			fi ; \
		#		echo "trying to readlink $$version/Makefile" ; \
			s=`readlink $$version/Makefile` ; \
		#		echo "Le lien $$version/Makefile vaut $$s" ; \
#			pwd ; \
			if [ !  "$$s" = "buildsystem/$(SW_NAME)-version.makefile" ] ; then \
				echo "Makefile symlink in $$version must link to buildsystem/$(SW_NAME)-version.makefile" ; \
				echo "The link currently targets to $$s" ; \
				echo "You can fix with the following shell commands :" ; \
				echo "git rm -f ${CURDIR}/$$version/Makefile || rm -f ${CURDIR}/$$version/Makefile" ; \
				echo "ln -s buildsystem/$(SW_NAME)-version.makefile ${CURDIR}/$$version/Makefile" ; \
				echo "git add ${CURDIR}//$$version/Makefile" ; \
				echo "make sanity-check" ; \
				$(call dft_error ,1911-0803) ; \
			fi ; \
		done ; \
# second loop is to forward recursive cal to version folders \
		for version in $(shell find . -mindepth 1 -maxdepth 1 -type d -name '*\.*') ; do \
			if [ -f $$version/Makefile ] ; then \
				$(MAKE) --no-print-directory --directory=$$version sanity-check ; \
			fi ; \
		done ; \
	fi ; \

	@echo "after" ;
# Create a new u-boot version entry
add-u-boot-version:
	@if [ "$(new-version)" == "" ] ; then \
		echo "DEBUG : from u-boot.makefile argument new-version is missing or has no value. Doing nothing..." ; \
		$(call dft_error ,2001-0801) ; \
	fi ;
	@if [ -d "./$(new-version)" ] ; then \
		echo ". Version $(new-version) already exist. Doing nothing..." ; \
	else  \
		echo ". Creating the directory for u-boot version $(new-version)" ; \
		mkdir -p $(new-version) ; \
		ln -s ../$(DFT_BUILDSYSTEM) $(new-version)/buildsystem ; \
		ln -s ../$(DFT_BUILDSYSTEM)/u-boot-version.makefile $(new-version)/Makefile ; \
		mkdir -p $(new-version)/files ; \
		ln -s ../../files/install.u-boot-$(BOARD_NAME).md $(new-version)/files/ ; \
		touch $(new-version)/files/.gitkeep ; \
		mkdir -p $(new-version)/patches ; \
		touch $(new-version)/patches/.gitkeep ; \
		cp -fr ../$(DFT_BUILDSYSTEM)/templates/debian-u-boot-package $(new-version)/debian ; \
		for suffix in install postinst postrm preinst prerm ; do \
			if [ -f $(new-version)/debian/u-boot.$$suffix ] ; then \
				mv $(new-version)/debian/u-boot.$$suffix $(new-version)/debian/u-boot-$(BOARD_NAME).$$suffix ; \
			fi ; \
    		done ; \
		find $(new-version)/debian -type f | xargs sed -i -e "s/__SW_VERSION__/$(new-version)/g" \
                                           -e "s/__BOARD_NAME__/$(BOARD_NAME)/g" \
                                           -e "s/__DATE__/$(shell LC_ALL=C date +"%a, %d %b %Y %T %z")/g" ; \
		if [ "${DEBEMAIL}" = "" ] ; then \
			find $(new-version)/debian -type f | xargs sed -i -e "s/__MAINTAINER_EMAIL__/unknown/g" ; \
		else \
			find $(new-version)/debian -type f | xargs sed -i -e "s/__MAINTAINER_EMAIL__/${DEBEMAIL}/g" ; \
		fi ; \
		if [ "${DEBFULLNAME}" = "" ] ; then \
			find $(new-version)/debian -type f | xargs sed -i -e "s/__MAINTAINER_NAME__/unknown/g" ; \
		else \
			find $(new-version)/debian -type f | xargs sed -i -e "s/__MAINTAINER_NAME__/${DEBFULLNAME}/g" ; \
		fi ; \
		echo "git add $(new-version)" ; \
	fi ;

# Override standard targets
configure build install package:
	@if [ ! "x$(HOST_ARCH)" = "x$(BOARD_ARCH)" ] ; then \
		echo "Makefile processing had to be stopped during target $@ execution. The target board is based on $(BOARD_ARCH) architecture and make is running on a $(HOST_ARCH) board." ; \
		echo "Cross compilation is not supported. The generated binaries might be invalid or scripts could fail before reaching the end of target." ; \
		echo "Makefile will now continue and process only $(HOST_ARCH) based boards. You can get the missing binaries by running this target again on a $(BOARD_ARCH) based host and collect by yourself the generated items." ; \
		echo "To generate binaries for all architectures you need several builders, one for each target architecture flavor." ; \
	else \
		for v in $(filter-out $(MAKE_FILTERS),$(shell find .  -mindepth 1 -maxdepth 1 -type d  -name "2*" -printf '%P\n' | sort --sort=version)) ; do \
			$(MAKE) --no-print-directory --directory=$$v $@ only-native-arch=$(only-native-arch) arch-warning=$(arch-warning) ; \
		done \
	fi ; \

# Simple forwarder
check-u-boot-defconfig setup extract fetch mrproper:
	@for v in $(filter-out $(MAKE_FILTERS),$(shell find .  -mindepth 1 -maxdepth 1 -type d  -name "2*" -printf '%P\n' | sort --sort=version)) ; do \
		$(MAKE) --no-print-directory --directory=$$v $@ only-native-arch=$(only-native-arch) arch-warning=$(arch-warning) ; \
	done
