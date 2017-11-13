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
# Execute the install target script
#

do-install :
	@if test -f $(COOKIE_DIR)/do-install ; then \
		true ; \
	else \
		echo "        running install in $(OBJ_DIR)"  ; \
		mkdir -p $(abspath $(INSTALL_DIR))/boot/dtb ; \
		cd $(OBJ_DIR) && $(BUILD_ENV) $(MAKE) INSTALL_PATH=$(abspath $(INSTALL_DIR))/boot install ; \
		$(BUILD_ENV) $(MAKE) INSTALL_MOD_PATH=$(abspath $(INSTALL_DIR))/ modules_install ; \
		cp -fr arch/arm/boot/dts/*.dtb $(abspath $(INSTALL_DIR))/boot/dtb ; \
	fi ;
	@$(TARGET_DONE)

do-reinstall :
	@if test -f $(COOKIE_DIR)/do-install ; then \
		rm -f $(COOKIE_DIR)/do-install ; \
		rm -fr $(abspath $(INSTALL_DIR)) ; \
	fi ;
	$(TARGET_DONE)

