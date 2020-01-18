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
BOARD_NAME = nanopi-neo2

# Board architecture as defined by uname -m (armv7l, mips, aarch64, x86_64, etc.)
BOARD_ARCH = aarch64



#
# u-boot support and configuration
#

# Defines if u-boot should be generated (set UBOOT_SUPPORT to 1) (0 means u-boot is not available).
# if UBOOT_SUPPORT is disabled packaging is skipped. In this case, you may have to activate GRUB.
UBOOT_SUPPORT = 1

# Make use the defconfig file from UBOOT_DEFCONFIG unless you specify your own in USE_CONFIG_FILE
UBOOT_DEFCONFIG = nanopi_neo2_defconfig

# List of files to copy from build to install directory (path is relative to build dir)
UBOOT_BINARY_FILE = u-boot.bin
UBOOT_DEFAULT_DTB = sun50i-h5-nanopi-neo2.dtb


#
# GRUB support and configuration (u-boot or grub should be activated to be able to boot the board).
#
GRUB_SUPPORT = 0
# Defines board name
BOARD_NAME = nanopi-neo2
BOARD_ARCH = aarch64

# Defines if the board use u-boot (set UBOOT_SUPPORT to 1) (0 it does not)
# if UBOOT_SUPPORT is disabled u-boot checks and generation are skipped
UBOOT_SUPPORT = 1

# Set config file to empty and define the name of the board to use a defconfig
USE_CONFIG_FILE        =
UBOOT_DEFCONFIG        = nanopi_neo2_defconfig

# Defines the default dtb to use (symlink used by generic boot.scr)
DEFAULT_DTB = sun50i-h5-nanopi-neo2.dtb

# Defines the list of files to copy (path is relative to build dir)
UBOOT_BINARY_FILE      = u-boot.bin
