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

#
# Board global parameters
#

# The board name fragment will be used in package naming, path and files content generation
BOARD_NAME = asus-tinkerboard

# Board architecture as defined by uname -m (armv7l, mips, aarch64, x86_64, etc.)
BOARD_ARCH = armv7l
BOARD_PLATFORM = rockchip
BOARD_SOC = rk3288


#
# u-boot support and configuration
#

# Defines if u-boot should be generated (set UBOOT_SUPPORT to 1) (0 means u-boot is not available).
# if UBOOT_SUPPORT is disabled packaging is skipped. In this case, you may have to activate GRUB.
UBOOT_SUPPORT = 1

# Defines if an assembly script has to be executed (this script can execute final assembly and/or signature operation)
UBOOT_ASSEMBLING = 1

# Defines the script used to produce (assemble and sign) the u-boot binary
UBOOT_ASSEMBLY_SCRIPT = assemble-uboot-$(BOARD_PLATFORM)-$(BOARD_SOC).sh

# List of files to copy from build to install directory (path is relative to build dir)

# Defines if an assembly script has to be executed (this script can execute final assembly and/or signature operation)
UBOOT_ASSEMBLING = 1
UBOOT_DEFCONFIG = tinker-rk3288_defconfig
UBOOT_BINARY_FILE = u-boot.img
UBOOT_BINARY_EXTRA_FILES = idbloader.img 
DEFAULT_DTB = rk3288-tinker.dtb


#
# GRUB support and configuration (u-boot or grub should be activated to be able to boot the board).
#
GRUB_SUPPORT = 0
