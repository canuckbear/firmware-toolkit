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
SW_NAME     = linux
SW_VERSION  = $(notdir $(patsubst %/,%,${CURDIR}/))

buildsystem := ../../../../../buildsystem
include ../board.mk
include $(buildsystem)/inc/u-boot.mk
include $(buildsystem)/dft.mk

# Retrieve th builder hot architecure if not defined yet
HOST_ARCH      ?= $(shell uname -m)

# Do not recurse the following subdirs
MAKE_FILTERS  = Makefile README.md .

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
		echo "error 191121-02" ; \
		exit 1 ; \
	fi ;
	@if [ ! -L "./Makefile" ] ; then \
		echo "Makefile symlink to ../../../../../buildsystem/linux-kernel-version.makefile is missing in ${CURDIR}/" ; \
		echo "You can fix with theyy following commands : " ; \
		echo "git rm -f ${CURDIR}//Makefile || rm -f ${CURDIR}//Makefile" ; \
		echo "ln -s $(buildsystem)/$(SW_NAME)-kernel-version.makefile ${CURDIR}//Makefile" ; \
		echo "git add ${CURDIR}//Makefile" ; \
		echo "error 191122-01" ; \
		exit 1 ; \
	fi ;
	@if [ ! "$(shell readlink ./Makefile)" = "../../../../../buildsystem/linux-kernel-version.makefile" ] ; then \
		echo "target of symlink Makefile should be ../../../../../buildsystem/linux-kernel-version.makefile in directory ${CURDIR}/" ; \
		echo "You can fix with the following commands : " ; \
		echo "git rm -f ${CURDIR}//Makefile || rm -f ${CURDIR}/Makefile" ; \
		echo "ln -s $(buildsystem)/$(SW_NAME)-kernel-version.makefile ${CURDIR}/Makefile" ; \
		echo "git add ${CURDIR}//Makefile" ; \
		echo "error 191121-03" ; \
		exit 1 ; \
	fi ;
	@if [ ! -d "../defconfig" ] ; then \
		echo "kernel config files directory is missing ${CURDIR}//.." ; \
		echo "You can fix with the following commands : " ; \
		echo "mkdir ../defconfig" ; \
		echo "touch ../defconfig/.gitkeep" ; \
		echo "git add ../defconfig" ; \
		echo "error 191121-01" ; \
		exit 1 ; \
	fi ;
	@if [ ! -d "./debian" ] ; then \
		echo "debian directory is missing in ${CURDIR}/. It should contain the files needed to create the debian package for $(BOARD_NAME) $(SW_NAME) kernel" ; \
		echo "error 191121-04" ; \
		echo "You can fix with the following commands : " ; \
		exit 1 ; \
	fi ;
	@if [ ! -L "./buildsystem" ] ; then \
		echo "buildsystem symlink to ../../../../../buildsystem is missing in ${CURDIR}/. You are using your own custom buildsystem" ; \
		echo "ln -s $(buildsystem) ${CURDIR}//buildsystem" ; \
		echo "git add ${CURDIR}//buildsystem" ; \
		echo "error 191121-06" ; \
		exit 1 ; \
	fi ;
	@if [ ! "$(shell readlink ./buildsystem)" = "../../../../../buildsystem" ] ; then \
		echo "target of symlink buildsystem should be ../../../../../buildsystem in directory ${CURDIR}" ; \
		echo "error 191121-08" ; \
		exit 1 ; \
	fi ;
