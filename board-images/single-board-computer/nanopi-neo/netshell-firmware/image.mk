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
# Image global parameters
#

# The image type (supported types are rootfs and firmware)
IMAGE_TYPE = firmware

# The image name (XXX)
IMAGE_NAME ?= $(BOARD_NAME)-$(IMAGE_TYPE)-netshell

