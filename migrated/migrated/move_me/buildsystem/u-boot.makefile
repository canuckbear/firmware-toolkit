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
# Copyright 2016 DFT project (http://www.debianfirmwaretoolkit.org).
# All rights reserved. Use is subject to license terms.
#
#
# Contributors list :
#
#    William Bonnet     wllmbnnt@gmail.com, wbonnet@theitmakers.com
#
#

# Defines variables specific to u-boot
SW_NAME     := u-boot
buildsystem := ../../../../buildsystem
include ../board.mk
include $(buildsystem)/inc/u-boot.mk
include $(buildsystem)/dft.mk

# Do not recurse the following subdirs
MAKE_FILTERS  := files defconfig Makefile README.md patches .

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

# ------------------------------------------------------------------------------
#
# Targets not associated with a file (aka PHONY)
#
.PHONY: help check

# 
# Board level u-boot makefile
#
sanity-check:
	@if [ $(UBOOT_SUPPORT) = 0  ] ; then \
		exit 0 ; \
	fi ;
	@echo "Checking $(BOARD_NAME) u-boot packages folder" ;
	@if [ ! -L "Makefile"  ] ; then \
		echo "Makefile symlink $(buildsystem)/u-boot.makefile is missing in directory ${CURDIR}" ; \
		echo "You can fix with the following commands : " ; \
		echo "git rm -f ${CURDIR}/Makefile" ; \
		echo "ln -s $(buildsystem)/u-boot.makefile ${CURDIR}/Makefile" ; \
		echo "git add ${CURDIR}/Makefile" ; \
		echo "error 1911115-02" ; \
		echo "error 1911115-02" ; \
		exit 1 ; \
	fi ;
	@if [ ! "$(shell readlink ./Makefile)" = "$(buildsystem)/u-boot.makefile" ] ; then \
		echo "target of symlink Makefile should be $(buildsystem)/u-boot.makefile in directory ${CURDIR}" ; \
		echo "You can fix with the following commands : " ; \
		echo "git rm -f ${CURDIR}/Makefile" ; \
		echo "ln -s $(buildsystem)/u-boot.makefile ${CURDIR}/Makefile" ; \
		echo "git add ${CURDIR}/Makefile" ; \
		echo "error 1911115-01" ; \
		exit 1 ; \
	fi ;
	@if [ ! -d "${CURDIR}/files" ] ; then \
		echo "files directory is missing in ${CURDIR}. It should contains the markdown file install.u-boot-$(BOARD_NAME).md needed by target package." ; \
		echo "You can fix with the following commands : " ; \
		echo "mkdir -p ${CURDIR}/files" ; \
		echo "touch ${CURDIR}/files/.gitkeep" ; \
		echo "ln -s ../../files/install.$(SW_NAME)-$(BOARD_NAME).md ${CURDIR}/files/" ; \
		echo "git add ${CURDIR}/files" ; \
		echo "error 1911115-03" ; \
		exit 1 ; \
	fi ;  
	@if [ ! -d "${CURDIR}/files" ] ; then \
		echo "You can fix with the following commands : " ; \
		echo "mkdir -p ${CURDIR}/files" ; \
		echo "touch ${CURDIR}/files/.gitkeep" ; \
		echo "git add ${CURDIR}/files" ; \
		echo "error 191112-02" ; \
		exit 1 ; \
	fi ;
	@if [ ! -f "${CURDIR}/files/install.$(SW_NAME)-$(BOARD_NAME).md" ] ; then \
		ls -lh "${CURDIR}/files/install.$(SW_NAME)-$(BOARD_NAME).md" ;  \
		echo "the $(SW_NAME) installation procedure is missing in the files/ folder. This folder should contain a file named install.$(SW_NAME)-$(BOARD_NAME).md describing. This file is needed by target package." ; \
		echo "error 191116-01" ; \
		exit 1 ; \
	fi ;
	@if [ ! -L "board.mk" ] ; then \
		echo "board.mk symlink to ../board.mk is missing in directory ${CURDIR}" ; \
		echo "You can fix with the following commands : " ; \
		echo "ln -s ../board.mk board.mk" ; \
		echo "git add board.mk" ; \
		echo "error 1911115-04" ; \
		exit 1 ; \
	fi ;
	@if [ ! "$(shell readlink ${CURDIR}/board.mk)" = "../board.mk" ] ; then \
		echo "target of symlink board.mk should be ../board.mk in directory ${CURDIR}" ; \
		echo "You can fix with the following commands : " ; \
		echo "git rm -f ${CURDIR}/board.mk" ; \
		echo "ln -s ../board.mk ${CURDIR}/board.mk" ; \
		echo "git add ${CURDIR}/board.mk" ; \
		echo "error 1911115-05" ; \
		exit 1 ; \
	fi ;
	@for version in $(shell find . -mindepth 1 -maxdepth 1 -type d -name '*\.*' ) ; do \
	 echo "Checking $(BOARD_NAME) u-boot $$version package definition" ; \
         if [ ! -L "$$version/Makefile" ] ; then \
            echo "Makefile in ${CURDIR}/$$version is missing. It should be a symlink to $(buildsystem)/u-boot-version.makefile" ; \
            echo "You can fix with the following shell commands :" ; \
            echo "ln -s ../$(buildsystem)/u-boot-version.makefile $$version/Makefile" ; \
            echo "git add $$version/Makefile" ; \
            echo "exit 191115-07" ; \
            exit 1 ; \
           fi ; \
           s=`readlink $$version/Makefile` ; \
           if [ !  "$$s" = "../$(buildsystem)/u-boot-version.makefile" ] ; then \
               echo "Makefile symlink in $$version must link to $(buildsystem)/u-boot-version.makefile" ; \
               echo "You can fix with the following shell commands :" ; \
               git rm -f ${CURDIR}/$$version/Makefile || rm -f ${CURDIR}/$$version/Makefile ; \
               ln -s ../$(buildsystem)/u-boot-version.makefile ${CURDIR}/$$version/Makefile ; \
               git add ${CURDIR}/$$version/Makefile ; \
               echo "exit 191122-21" ; \
            fi ; \
	done ; 
	@for version in $(shell find . -mindepth 1 -maxdepth 1 -type d  -name '*\.*' ) ; do \
		if [ -f $$version/Makefile ] ; then \
			cd $$version && $(MAKE) sanity-check ; \
		fi ; \
	done ;

# Catch all target. Call the same targets in each subfolder
%:
	for i in $(filter-out $(MAKE_FILTERS),$(shell find . -mindepth 1 -maxdepth 1 -type d )) ; do \
		cd $$i && $(MAKE) $* ; \
        done
