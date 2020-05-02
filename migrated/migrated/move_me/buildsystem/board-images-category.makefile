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

# Do not recurse the following subdirs
MAKE_FILTERS  := Makefile workdir README.md .

# Simple target forwarder
list-images:
	@echo "DEBUG list-images in board-images-category.makdefile"
	@echo "DEBUG list-images is stil IP TODO"
	@for v in $(filter-out $(MAKE_FILTERS),$(shell find .  -mindepth 1 -maxdepth 1 -type d -printf '%P\n')) ; do \
		if [ -f ${CURDIR}/$$v/Makefile ] ; then \
                	$(MAKE) --directory=$$v $@ ; \
		fi ; \
	done

# ------------------------------------------------------------------------------
#
# Target that prints the help
#
help:
	@echo "DEBUG help in board-images-category.makdefile"
	@echo "Available targets are :"
	@echo "   list-images             Display the liste of images available in this category."
	@echo "                           The following filters can be used to display only matching images : "
	@echo "                           arch=(armv7l,aarch64,x86_64 or any valid arch from uname -m)."
	@echo "                           type=(rootfs or firmware)."
	@echo "   sanity-check            Check the availability of required items (files, symlinks, directories)"
	@echo "                           In the following subdirs $(CHECK_FOR_SANITY)."
	@echo "                           This target only warns you and do not make any change to the tree content."
	@echo "   help                    Display this help"
	@echo ""
	@echo "The existing local targets are the following. Local targets are executed only at this"
	@echo "level in the category, without recursion nor walk down the tree of board categories"
