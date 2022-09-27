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
	if [ "$(only-latest)" = "1" ] ; then \
		if [ ! "$(SW_LATEST)" = "" ] ; then \
			cd $(SW_LATEST) && $(MAKE) --no-print-directory $@ only-native-arch=$(only-native-arch) arch-warning=$(arch-warning) only-latest=$(only-latest) verbosity=$(verbosity) && cd .. ;  \
		fi ; \
	else \
		pwd ; \
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
	skip_target=0 ; \
	if [ "$(SW_VERSION)" == "undefined-sw-version" ] ; then \
		skip_target=1 ; \
		true ; \
	fi ; \
	if [ ! "x$(HOST_ARCH)" = "x$(BOARD_ARCH)" ] && [ "x$(only-native-arch)" = "x1" ] ; then \
		skip_target=1 ; \
		if [ "x$(arch-warning)" = "x1" ] ; then \
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
						cd "$(BUILD_DIR)" ; \
						make olddefconfig ; \
						cd - ; \
						cp "$(BUILD_DIR)/.config" "../config/$(BOARD_NAME)-kernel-$(SW_VERSION).config"  ; \
						git add "../config/$(BOARD_NAME)-kernel-$(SW_VERSION).config"  ; \
					else \
						echo "config/$(BOARD_NAME)-kernel-$(SW_VERSION).config exist using it" ; \
						cp "../config/$(BOARD_NAME)-kernel-$(SW_VERSION).config" "$(BUILD_DIR)/.config" ; \
						cd "$(BUILD_DIR)" ; \
						make olddefconfig ; \
					fi ; \
				fi ; \
				cd "$(BUILD_DIR)" ; \
  			  	cp -fr "$(FRAGMENT_HOME)"  "$(FRAGMENT_DIR)/" ; \
			fi ; \
		fi ; \
		cp "$(BUILD_DIR)/.config" "$(BUILD_DIR)/config.before-merge" ; \
		"./scripts/kconfig/merge_config.sh" -O "$(BUILD_DIR)" .config "$(BUILD_DIR)/collected-defconfig-fragments.cleaned" ; \
		cp "$(BUILD_DIR)/.config" "$(BUILD_DIR)/config.after-merge" ; \
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
	echo "Creating kernel collected config file" ; \
	if [ "$(SW_NAME)" = "linux" ] ; then \
		for f in "$(FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_COMMON_FRAGMENTS)" \
			 "$(FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_FAMILY_FRAGMENTS)" \
			 "$(FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_HW_SPECIFIC_FRAGMENTS)" \
			 "$(FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_COMMON_FRAGMENTS)" \
			 "$(FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_FAMILY_FRAGMENTS)" \
			 "$(FRAGMENT_HOME)/$(LINUX_KERNEL_BOARD_FUNC_SPECIFIC_FRAGMENTS)" ; do \
			if  test -e "$$f" ; then \
				echo "adding $$f to $(BUILD_DIR)/collected-defconfig-fragments" ; \
				cat "$$f" >> "$(BUILD_DIR)/collected-defconfig-fragments.raw" ; \
				cat "$$f" >> "$(BUILD_DIR)/collected-defconfig-fragments.cleaned" ; \
				sed --in-place -e 's/#.*$//' -e 'd/^$/' "$(BUILD_DIR)/collected-defconfig-fragments.cleaned" ; \
			else \
				echo NOT MERGING : "$$f" ; \
			fi ; \
		done ; \
	else \
		echo "Not yet collecting config file fragment for uboot (coming soon)" ; \
	fi ; 
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# ------------------------------------------------------------------------------
#
# Kernel config file has been generated according to board mafiles, now clean
# files which are no longer needed during compilation stagekernel configuration fragments and strip them from comments and emptry lines.
# The generated .config-with-fragments file is ten used at configure step.
# This pre- stage is meant to write simplier smaller parts of code, instead of
# a big blurry chunk of code doing all the magic magic ^^
#
#
# TODO : DELTA DEFCONFIG

post-configure:
	echo "Cleaning temporarifles generated when collecting kernel configuration fragments" ; \
	mv "$(BUILD_DIR)/collected-defconfig-fragments.cleaned" "$(BUILD_DIR)/collected-defconfig-fragments.after_configure" ; \
	
	$(DISPLAY_COMPLETED_TARGET_NAME)
	$(TARGET_DONE)

# Match initial ifdef DFT_TARGET_CONFIGURE
endif
