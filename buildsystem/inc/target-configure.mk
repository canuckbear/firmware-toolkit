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
ifdef DFT_TARGET_CONFIGURE
$(info target-configure.mk has already been included)
else
DFT_TARGET_CONFIGURE = 1

# ------------------------------------------------------------------------------
#
# Run the configure script
#

CONFIGURE_TARGETS = $(addprefix configure-, $(CONFIGURE_SCRIPTS))

configure: patch pre-configure do-configure post-configure
	if [ "$(only_latest)" = "1" ] ; then \
		if [ ! "$(SW_LATEST)" = "" ] ; then \
			cd $(SW_LATEST) && $(MAKE) --no-print-directory $@ only_native_arch=$(only_native_arch) arch_warning=$(arch_warning) only_latest=$(only_latest) verbosity=$(verbosity) && cd .. ;  \
		fi ; \
	else \
		for v in configure_debug $(filter-out $(MAKE_FILTERS),$(shell find .  -mindepth 1 -maxdepth 1 -type d -printf '%P\n')) ; \
			do echo "target-configure iterateur configure_debug : $$v" ; \
		done ; \
	fi ;
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# Force running again the configure script
#

RECONFIGURE_TARGETS ?= $(addprefix reconfigure-,$(basedir $(CONFIGURE_SCRIPTS)))

reconfigure: patch pre-reconfigure $(RECONFIGURE_TARGETS) configure post-reconfigure
	@rm -f $(COOKIE_DIR)/configure
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# Execute the configure script
#

configure: extract pre-configure do-configure post-configure
do-configure:
	@skip_target=0 ; \
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
		if [ ! -f $(COOKIE_DIR)/$@ ] ; then \
			if [ "$(SW_NAME)" = "u-boot" ] ; then \
				if [ ! -f "$(BUILD_DIR)/configs/$(UBOOT_DEFCONFIG)" ] ; then \
					echo "ERROR defconfig file $(UBOOT_DEFCONFIG) for board $(BOARD_NAME) does not exist in $(SW_NAME) v$(SW_VERSION) sources." ; \
					$(call dft_error ,2001-1001) ; \
				else \
					cd "$(BUILD_DIR)" ; \
					echo "    running u-boot make $(BUILD_FLAGS) $(UBOOT_DEFCONFIG) in $(BUILD_DIR)" ; \
					make -C $(BUILD_DIR) $(BUILD_FLAGS) $(UBOOT_DEFCONFIG) ; \
				fi ; \
			else \
				if [ "$(SW_NAME)" = "linux" ] ; then \
					if [ ! -f "../config/$(BOARD_NAME)-kernel-$(SW_VERSION).config" ] ; then \
						echo "config/$(BOARD_NAME)-kernel-$(SW_VERSION).config does not exist using default instead" ; \
						cp "../config/$(BOARD_NAME)-kernel-default.config" "$(BUILD_DIR)/.config" ; \
						cp -v "$(BUILD_DIR)/.config"  "$(BUILD_DIR)/config.step1" ; \
						cd "$(BUILD_DIR)" ; \
						make olddefconfig ; \
						cp -v "$(BUILD_DIR)/.config"  "$(BUILD_DIR)/config.step2" ; \
						cd - ; \
						cp "$(BUILD_DIR)/.config" "../config/$(BOARD_NAME)-kernel-$(SW_VERSION).config"  ; \
						cp -v "$(BUILD_DIR)/.config"  "$(BUILD_DIR)/config.step3" ; \
						if [ "$(DFT_ENABLE_GIT_CHANGE)" = "1" ] ; then \
							git add "../config/$(BOARD_NAME)-kernel-$(SW_VERSION).config"  ; \
						fi ; \
					else \
						echo "config/$(BOARD_NAME)-kernel-$(SW_VERSION).config exist using it" ; \
						cp "../config/$(BOARD_NAME)-kernel-$(SW_VERSION).config" "$(BUILD_DIR)/.config" ; \
						cp -v "$(BUILD_DIR)/.config"  "$(BUILD_DIR)/config.step4" ; \
						cd "$(BUILD_DIR)" ; \
						make olddefconfig ; \
						cp -v "$(BUILD_DIR)/.config"  "$(BUILD_DIR)/config.step5" ; \
					fi ; \
				fi ; \
				cd "$(BUILD_DIR)" ; \
  			  	cp -fr "$(KERNEL_FRAGMENT_HOME)" "$(KERNEL_FRAGMENT_DIR)/" ; \
			fi ; \
		fi ; \
		cp "$(BUILD_DIR)/.config" "$(BUILD_DIR)/config.before-merge" ; \
		KCONFIG_CONFIG="$(BUILD_DIR)" "./scripts/kconfig/merge_config.sh" -m "$(BUILD_DIR)/config.before-merge" "$(BUILD_DIR)/collected-defconfig-fragments.cleaned" ; \
		cp -v "$(BUILD_DIR)/.config"  "$(BUILD_DIR)/config.step6-after-first-merge" ; \
	fi ;
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# When compiling a Linux  kernel Pre-configure target is in charge of gathering 
# kernel configuration fragments and strip them from comments and emptry lines.
# The generated .config-with-fragments file is ten used at configure step.
# This pre- stage is meant to write simplier smaller parts of code, instead of
# a big blurry chunk of code doing all the magic magic ^^
#
#
# TODO : DELTA DEFCONFIG

pre-configure:
	@echo "Creating collected defconfig file" ; \
	if [ "$(SW_NAME)" = "linux" ] ; then \
		if [ -f "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_COMMON_FRAGMENTS)" ] ; then \
			echo "MERGING : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_COMMON_FRAGMENTS) to $(BUILD_DIR)/collected-defconfig-fragments" ; \
			cat "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_COMMON_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_COMMON_FRAGMENTS) file does not exists" ; \
		fi ; \
		if [ -f "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_FAMILY_FRAGMENTS)" ] ; then \
			echo "MERGING : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_FAMILY_FRAGMENTS) to $(BUILD_DIR)/collected-defconfig-fragments" ; \
			cat "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_FAMILY_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_FAMILY_FRAGMENTS) file does not exists" ; \
		fi ; \
		if [ -f "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_SPECIFIC_FRAGMENTS)" ] ; then \
			echo "MERGING : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_SPECIFIC_FRAGMENTS) to $(BUILD_DIR)/collected-defconfig-fragments" ; \
			cat "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_SPECIFIC_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_SPECIFIC_FRAGMENTS) file does not exists" ; \
		fi ; \
		if [ -f "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_COMMON_FRAGMENTS)" ] ; then \
			echo "MERGING : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_COMMON_FRAGMENTS) to $(BUILD_DIR)/collected-defconfig-fragments" ; \
			cat "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_COMMON_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_COMMON_FRAGMENTS) file does not exists" ; \
		fi ; \
		if [ -f "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_FAMILY_FRAGMENTS)" ] ; then \
			echo "MERGING : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_FAMILY_FRAGMENTS) to $(BUILD_DIR)/collected-defconfig-fragments" ; \
			cat "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_FAMILY_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_FAMILY_FRAGMENTS) file does not exists" ; \
		fi ; \
		if [ -f "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_SPECIFIC_FRAGMENTS)" ] ; then \
			echo "MERGING : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_SPECIFIC_FRAGMENTS) to $(BUILD_DIR)/collected-defconfig-fragments" ; \
			cat "$(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_SPECIFIC_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(KERNEL_FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_SPECIFIC_FRAGMENTS) file does not exists" ; \
		fi ; \
	fi ; \
	if [ "$(SW_NAME)" = "u-boot" ] ; then \
		if [ -f "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_HW_COMMON_FRAGMENTS)" ] ; then \
			cat "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_HW_COMMON_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_HW_COMMON_FRAGMENTS) file does not exists" ; \
		fi ; \
		if [ -f "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_HW_FAMILY_FRAGMENTS)" ] ; then \
			cat "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_HW_FAMILY_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_HW_FAMILY_FRAGMENTS) file does not exists" ; \
		fi ; \
		if [ -f "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_HW_SPECIFIC_FRAGMENTS)" ] ; then \
			cat "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_HW_SPECIFIC_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_HW_SPECIFIC_FRAGMENTS) file does not exists" ; \
		fi ; \
		if [ -f "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_FUNC_COMMON_FRAGMENTS)" ] ; then \
			cat "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_FUNC_COMMON_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_HW_COMMON_FRAGMENTS) file does not exists" ; \
		fi ; \
		if [ -f "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_FUNC_FAMILY_FRAGMENTS)" ] ; then \
			cat "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_FUNC_FAM ILY_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_FUNC_FAMILY_FRAGMENTS) file does not exists" ; \
		fi ; \
		if [ -f "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_FUNC_SPECIFIC_FRAGMENTS)" ] ; then \
			cat "$(UBOOT_FRAGMENT_HOME)/$(UBOOT_BOARD_FUNC_SPECIFIC_FRAGMENTS)" >> $(BUILD_DIR)/collected-defconfig-fragments ; \
		else \
			echo "SKIPPED : $(UBOOT_FRAGMENT_HOME)/$(UBOOT_KERNEL_BOARD_FUNC_SPECIFIC_FRAGMENTS) file does not exists" ; \
		fi ; \
	fi ; \
	cp $(BUILD_DIR)/collected-defconfig-fragments $(BUILD_DIR)/config.step7.collected.before.clean ; \
	if [ -f "$(BUILD_DIR)/collected-defconfig-fragments.cleaned" ] ; then \
			sed --in-place -e '/^$$/d' -e '/^#.*$$/d' "$(BUILD_DIR)/collected-defconfig-fragments.cleaned" ; \
			cp "$(BUILD_DIR)/collected-defconfig-fragments.cleaned" "$(BUILD_DIR)/config.step8.cleaned" ; \
	fi ; \
	
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# Kernel config file has been generated according to board mafiles, now clean
# files which are no longer needed during compilation stagekernel configuration fragments and strip them from comments and emptry lines.
# The generated .config-with-fragments file is ten used at configure step.
# This pre- stage is meant to write simplier smaller parts of code, instead of
# a big blurry chunk of code doing all the magic ^^
#
#
# TODO : DELTA DEFCONFIG

post-configure:
	echo "Cleaning files generated when collecting configuration fragments" ; \
	if [ -f "$(BUILD_DIR)/collected-defconfig-fragments.cleaned" ] ; then \
		cp "$(BUILD_DIR)/collected-defconfig-fragments.cleaned" "$(BUILD_DIR)/.config" ; \
		cp -v "$(BUILD_DIR)/.config"  "$(BUILD_DIR)/config.step9.postconfigure" ; \
	fi ;
	
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# Match initial ifdef DFT_TARGET_CONFIGURE
endif
