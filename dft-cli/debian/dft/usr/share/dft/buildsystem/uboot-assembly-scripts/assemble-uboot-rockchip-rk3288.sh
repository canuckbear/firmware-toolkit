#!/usr/bin/env bash 

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
# Copyright 2021 DFT project (http://www.firmwaretoolkit.org).
# All rights reserved. Use is subject to license terms.
#
#
# Contributors list :
#
#    William Bonnet     wllmbnnt@gmail.com, wbonnet@theitmakers.com
#
#

# Activate "fail fast". Stop on first error encountered.
set -ex

# The following procedure is provided with u-boot sources in readme from doc/board folder
# The one and only argument is the target platform of u-boot build
cd $1/

# Create the u-boot image and assemble the final binary
mkimage -n rk3288 -T rksd -d ./tpl/u-boot-tpl.bin idbloader.img
cat spl/u-boot-spl-dtb.bin >> idbloader.img
