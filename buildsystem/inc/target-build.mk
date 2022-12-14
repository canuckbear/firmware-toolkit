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
# Copyright 2017 DFT project (http://www.firmwaretoolkit.org).
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
# Protection against multiple include
#
ifdef DFT_TARGET_BUILD
$(info target-build.mk has already been included)
else
DFT_TARGET_BUILD = 1

# ------------------------------------------------------------------------------
#
# Build the target binaries
#

BUILD_TARGETS ?= $(addprefix build-,$(SRC_DIST_FILES))

show-build-targets:
	@echo $(BUILD_TARGETS) ;

build: configure pre-build $(BUILD_TARGETS) post-build
	skip_target=0 ; \
	echo "verbosity : $(verbosity)" ; 	
	if [ "$(verbosity)" = "" ]  ; then \
		verbosity=1 ; \
	fi ; \
	if [ "$(SW_VERSION)" == "undefined-sw-version" ] ; then \
		skip_target=1 ; \
		true ; \
	fi ; \
	if [ ! "x$(HOST_ARCH)" = "x$(BOARD_ARCH)" ] && [ "x$(only_native_arch)" = "x1" ] ; then \
		skip_target=1 ; \
		if [ "x$(arch_warning)" = "x1" ] ; then \
			echo "Makefile processing had to be stopped during target $@ execution. Cross compilation is not supported. " ; \
			echo "The target board is based on $(BOARD_ARCH) architecture and make is running on a $(HOST_ARCH) board." ; \
			echo "The generated binaries might be invalid or scripts could fail before reaching the end of target." ; \
			echo "Makefile will now continue and process only $(HOST_ARCH) based boards. You can get the missing binaries by running" ; \
			echo "this target again on a $(BOARD_ARCH) based host and collect by yourself the generated items." ; \
			echo "In order to generate binaries for existing architectures, you need several builders, one for each target arch." ; \
		fi ; \
	fi ; \
	if [ ! "x$$skip_target" = "x1" ] ; then \
		cd $(BUILD_DIR) ; \
		if [ ! -f $(COOKIE_DIR)/$@ ] ; then \
			if [ "$(SW_NAME)" = "u-boot" ] ; then \
				$(BUILD_ENV) $(MAKE) $(BUILD_PROCESS_COUNT) $(UBOOT_BUILD_FLAGS) $(UBOOT_BUILD_ARGS) only_native_arch=$(only_native_arch) arch_warning=$(arch_warning) arch_latest=$(only_latest) verbosity=$(verbosity) ; \
			fi ; \
			if [ "$(SW_NAME)" = "linux" ] ; then \
				$(BUILD_ENV) $(MAKE) $(BUILD_PROCESS_COUNT) $(LINUX_KERNEL_BUILD_FLAGS) $(LINUX_KERNEL_BUILD_ARGS) only_native_arch=$(only_native_arch) arch_warning=$(arch_warning) arch_latest=$(only_latest) verbosity=$(verbosity) ; \
			fi ; \
		fi ; \
	fi ;
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# Post-build target is in charge of assembling and signing of the final binary
#
post-build: 
	if [ "$(SW_NAME)" = "u-boot" ] && [ "$(UBOOT_SUPPORT)" = "1" ] ; then \
		if [ ! -d  $(INSTALL_DIR)/u-boot ] ; then \
			mkdir $(INSTALL_DIR)/u-boot ; \
		fi ; \
		cp -fv $(BUILD_DIR)/$(UBOOT_BINARY_FILE) $(INSTALL_DIR)/u-boot/u-boot-$(BOARD_NAME)-$(SW_VERSION) ; \
		cp -fv $(BUILD_DIR)/u-boot.dtb $(INSTALL_DIR)/u-boot/u-boot-$(BOARD_NAME)-$(SW_VERSION).dtb ; \
		ln -sf u-boot-$(BOARD_NAME)-$(SW_VERSION) $(INSTALL_DIR)/u-boot/u-boot-$(BOARD_NAME) ; \
		if [ "$(UBOOT_ASSEMBLING)" = "1" ] ; then \
			if [ "$(UBOOT_ASSEMBLY_SCRIPT)" = "" ] ; then \
				echo "Error variable : UBOOT_ASSEMBLY_SCRIPT is undefined" ; \
			else \
				echo "Using UBOOT_ASSEMBLY_SCRIPT : $(DFT_BUILDSYSTEM)/uboot-assembly-scripts/$(UBOOT_ASSEMBLY_SCRIPT)" ; \
				ls -la $(DFT_BUILDSYSTEM)/uboot-assembly-scripts/$(UBOOT_ASSEMBLY_SCRIPT) ; \
				if [ ! -x  $(DFT_BUILDSYSTEM)/uboot-assembly-scripts/$(UBOOT_ASSEMBLY_SCRIPT) ] ; then \
				echo "ERROR : $(DFT_BUILDSYSTEM)/uboot-assembly-scripts/$(UBOOT_ASSEMBLY_SCRIPT) is not executable" ; \
				else \
					$(DFT_BUILDSYSTEM)/uboot-assembly-scripts/$(UBOOT_ASSEMBLY_SCRIPT) $(BUILD_DIR) ; \
				fi ; \
			fi ; \
		fi ; \
	fi ;
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# Rebuild the target binaries
#

REBUILD_TARGETS ?= $(addprefix rebuild-,$(BUILD_TARGETS))

rebuild: configure pre-rebuild $(REBUILD_TARGETS) build post-rebuild
	@rm -f $(COOKIE_DIR)/build
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# Execute the building script
#

build-%:
	if [ ! "$(SW_VERSION)" = "" ] ; then \
		if [ ! "$(SW_VERSION)" == "undefined-sw-version" ] ; then \
			if [ ! "x$(HOST_ARCH)" = "x$(BOARD_ARCH)" ] && [ "x$(only_native_arch)" = "x1" ] ; then \
				if [ "x$(arch_warning)" = "x1" ] ; then \
					echo "Makefile processing had to be stopped during target $@ execution. Cross compilation is not supported. " ; \
					echo "The target board is based on $(BOARD_ARCH) architecture and make is running on a $(HOST_ARCH) board." ; \
					echo "The generated binaries might be invalid or scripts could fail before reaching the end of target." ; \
					echo "Makefile will now continue and process only $(HOST_ARCH) based boards. You can get the missing binaries by running" ; \
					echo "this target again on a $(BOARD_ARCH) based host and collect by yourself the generated items." ; \
					echo "In order to generate binaries for existing architectures, you need several builders, one for each target arch." ; \
				fi ; \
			else \
				cd $(BUILD_DIR) ; \
				if [ "$(SW_NAME)" = "linux" ] ; then \
					if [ ! -f $(COOKIE_DIR)/build-$* ] ; then \
						$(BUILD_ENV) $(MAKE) $(BUILD_PROCESS_COUNT) $(LINUX_KERNEL_BUILD_FLAGS) $(LINUX_KERNEL_BUILD_ARGS) only_native_arch=$(only_native_arch) arch_warning=$(arch_warning) arch_latest=$(only_latest) ; \
					fi ; \
				fi ; \
				if [ "$(SW_NAME)" = "u-boot" ] ; then \
					if [ ! -f $(COOKIE_DIR)/build-$* ] ; then \
						echo "UBOOT_BUILD_FLAGS : $(UBOOT_BUILD_FLAGS)" ; \
						echo "LINUX_KERNEL_BUILD_FLAGS : $(LINUX_KERNEL_BUILD_FLAGS)" ; \
				       		echo "UBOOT_BUILD_ARGS : $(UBOOT_BUILD_ARGS)"; \
				       		echo "LINUX_KERNEL_BUILD_ARGS : $(LINUX_KERNEL_BUILD_ARGS)"; \
						$(BUILD_ENV) $(MAKE) $(BUILD_PROCESS_COUNT) $(UBOOT_BUILD_FLAGS) $(UBOOT_BUILD_ARGS) only_native_arch=$(only_native_arch) arch_warning=$(arch_warning) arch_latest=$(only_latest) ; \
					fi ; \
				fi ; \
			fi ; \
		fi ; \
	fi ;
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

rebuild-%:
	@if [ -f $(COOKIE_DIR)/build-$* ] ; then \
		rm -f $(COOKIE_DIR)/build-$* ; \
	fi ;
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# Definition of the package that must be installed on each build platform
#

PREREQUISITE_BASE_PKGS ?= make
PREREQUISITE_BASE_PKGS_UBUNTU ?= build-essential
PREREQUISITE_BASE_PKGS_DEBIAN ?= build-essential

# Match initial ifdef DFT_TARGET_BUILD
endif
