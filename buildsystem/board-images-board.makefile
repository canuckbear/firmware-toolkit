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
# Copyright 2019 DFT project (http://www.firmwaretoolkit.org).
# All rights reserved. Use is subject to license terms.
#
#
# Contributors list :
#
#    William Bonnet     wllmbnnt@gmail.com, wbonnet@theitmakers.com
#

# Force bash use instead of sh which is a symlink to dash on Debian. Dash use
# a slightly different syntax for some operators. This way we use a known shell.
SHELL := bash

# Build system sould be available under board folder as a symlink. Keep it
# locally available under board folder computing a relative path is a nightmare
# and does not work in all cases. Environment variables are not git friendly
# since git add will loose variable name and generate an absolute path, which
# is not comptible with user need ans or workspace relocation nor packagng needs.
# better solutions wille be really welcomeds contributions.

DFT_BUILDSYSTEM := buildsystem
include $(DFT_BUILDSYSTEM)/dft.mk
include board.mk

# ------------------------------------------------------------------------------
#
# Target that call the dft command line tool to build the image
#
image:
	echo "image from board-images-board.makefile" ; \
#	time sudo dft run_sequence --project project.yml --sequence produce-image  --log-level debug 

list-images:
	echo "list-images from board-images-board.makefile" ; \

# ------------------------------------------------------------------------------
#
# Checks that all mandatory files are available
#
sanity-check:
	@echo "Checking $(BOARD_NAME) $(IMAGE_TYPE)-$(IMAGE_NAME) image folder"
	@if [ ! -e "image.mk" ] ; then \
		echo "The image.mk file is missing in directory ${CURDIR}/" ; \
		echo "You can fix with the following commands : " ; \
		echo "cp $(DFT_BUILDSYSTEM)/templates/image.mk ${CURDIR}/" ; \
		echo "git add ${CURDIR}/image.mk" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2007-1301) ; \
	fi ;
	@if [ ! -e "project.yml" ] ; then \
		echo "The project.yml file is missing in directory ${CURDIR}/" ; \
		echo "You can fix with the following commands : " ; \
		echo "cp $(DFT_BUILDSYSTEM)/templates/board-image-project.yml ${CURDIR}/project.yml" ; \
		echo "git add ${CURDIR}/project.yml" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2007-1302) ; \
	fi ;
	@if [ ! -L "Makefile" ] ; then \
		echo "The Makefile symlink to ./buildsystem/board-image.makefile is missing in directory ${CURDIR}/" ; \
		echo "You can fix with the following commands : " ; \
		echo "ln -s ./buildsystem/board-image.makefile ${CURDIR}/Makefile" ; \
		echo "git add ${CURDIR}/Makefile" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2007-1304) ; \
	fi ;
	@if [ ! "$(shell readlink Makefile)" = "./buildsystem/board-image.makefile" ] ; then \
		echo "The target of symlink Makefile should be ./buildsystem/board-image.makefile in directory ${CURDIR}/" ; \
		echo "You can fix with the following commands : " ; \
		echo "git rm -f ${CURDIR}/Makefile" ; \
		echo "ln -s ./buildsystem/board-image.makefile ${CURDIR}/Makefile" ; \
		echo "git add ${CURDIR}/Makefile" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2007-1303) ; \
	fi ;
	@if [ ! -L "blueprint.yml" ] ; then \
		echo "The blueprint.yml to ../blueprint-$(BOARD_NAME).yml is missing in directory ${CURDIR}/" ; \
		echo "You can fix with the following commands : " ; \
		echo "ln -s ../blueprint-$(BOARD_NAME).yml blueprint.yml" ; \
		echo "git add ${CURDIR}/blueprint.yml" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2007-1305) ; \
	fi ;
	@if [ ! "$(shell readlink blueprint.yml)" = "../blueprint-$(BOARD_NAME).yml" ] ; then \
		echo "The target of symlink blueprint.yml should be ../blueprint-$(BOARD_NAME).yml in directory ${CURDIR}/" ; \
		echo "You can fix with the following commands : " ; \
		echo "git rm -f ${CURDIR}/blueprint.yml" ; \
		echo "ln -s ../blueprint-$(BOARD_NAME).yml ${CURDIR}/blueprint.yml" ; \
		echo "git add ${CURDIR}/Makefile" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2007-1306) ; \
	fi ;
	@if [ ! -e "board-variables.yml" ] ; then \
		echo "The board-variables.yml file is missing in directory ${CURDIR}/" ; \
		echo "You can fix with the following commands : " ; \
		echo "cp $(DFT_BUILDSYSTEM)/templates/board-variables.yml ${CURDIR}/board-variables.yml" ; \
		echo "git add ${CURDIR}/board-variables.yml" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2007-1307) ; \
	fi ;
	@if [ ! -e "disk-image.yml" ] ; then \
		echo "The disk-image.yml file is missing in directory ${CURDIR}/" ; \
		echo "You can fix with the following commands : " ; \
		echo "cp $(DFT_BUILDSYSTEM)/templates/disk-image.yml ${CURDIR}/disk-image.yml" ; \
		echo "git add ${CURDIR}/disk-image.yml" ; \
		echo "make sanity-check" ; \
		$(call dft_error ,2007-1309) ; \
	fi ;

list-architectures:
	for board in $(filter-out $(MAKE_FILTERS),$(shell find .  -mindepth 1 -maxdepth 1 -type d -printf '%P\n')) ; do \
		$(MAKE) --no-print-directory --directory=$$board $@ ; \
	done | sort ;

list-boards:
	@echo "DEBUG : in board-images-category.makefile running list-boards with argument arch $(arch)" ; \
	if [ "$(arch)" == "armhf" ] ; then \
		arch=armv7l; \
	fi ; \
	if [ "$(arch)" == "arm64" ] ; then \
		arch=aarch64; \
	fi ; \
	if [ "$(arch)" == "amd64" ] ; then \
		arch=x86_64; \
	fi ; \
	for board in $(filter-out $(MAKE_FILTERS),$(shell find .  -mindepth 1 -maxdepth 1 -type d -printf '%P\n')) ; do \
		if [ ! "$(arch)" = "" ] ; then \
			$(MAKE) --no-print-directory --directory=$$board $@ arch=$(arch); \
		else \
			$(MAKE) --no-print-directory --directory=$$board $@ ; \
		fi ; \
	done | sort ;

# Create a new board entry
add-image:
	@echo "DEBUG : in board-images-board.makefile running add-image with argument image-name $(image-name)" ; \
	if [ "$(image-name)" == "" ] ; then \
		echo "DEBUG : from category.makefile argument image-name is missing or has no value. Doing nothing..." ; \
		$(call dft_error ,2009-2301) ; \
	fi ; \
	if [ -d "./$(image-name)" ] ; then \
		echo ". Board $(image-name) already exist. Doing nothing..." ; \
	else  \
		echo ". Creating the directory for board $(image-name)" ; \
		mkdir -p $(image-name) ; \
		ln -s buildsystem/board-image.makefile $(image-name)/Makefile ; \
		ln -s ../buildsystem $(image-name)/buildsystem ; \
		ln -s ../blueprint-$(BOARD_NAME).yml $(image-name)/blueprint.yml ; \
	fi ; \
	ln -s ../../../inc/repository-debian-de-bullseye.yml $(image-name)/repository-debian.yml ; \
	ln -s ../../../inc/rootfs-$(image-name).yml $(image-name)/project-rootfs.yml ; \
	ln -s ../../../inc/variables-$(image-name).yml $(image-name)/project-variables.yml ; \
	cp  $(DFT_BUILDSYSTEM)/templates/board-images/$(image-name)/* $(image-name)/ ; \
	sed -i -s "s/__BOARD_NAME__/$(BOARD_NAME)/g" $(image-name)/project.yml $(image-name)/disk-image.yml $(image-name)/board-variables.yml ; \
	echo "Your work is still local, to make it available, you have to run git add commit and push : " ; \
	echo "git add $(image-name)" ; \
	echo "You are done, you can now build the image using" ; \
	echo "cd $(image-name) && make image" ; \

# ------------------------------------------------------------------------------
#
# Target that prints the help
#
help-contextual-targets help-context:
	@echo "Contextual targets are :"
	@echo "   add-board               Add a new board entry"
	@echo "   list-boards             Display the list of supported boards in this category"
	@echo "   list-architectures      Display the list of distinct architecture of boards supported in this category"
	@echo "   help-context            Display this help about contextual (or local) targets"
	@echo "   help                    Display global help menu and topics"

