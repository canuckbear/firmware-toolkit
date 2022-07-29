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
# Debian Firmware Toolkit is the new name of Linux Firmware From Scratch
# Copyright 2014 LFFS project (http://www.linuxfirmwarefromscratch.org).  
#
#
# Contributors list :
#
#    William Bonnet     wllmbnnt@gmail.com, wbonnet@theitmakers.com
#
#

# Fails on error
set -e

# Defines the working directories
workdir="./aufs-test"
configdir="${workdir}/config"
systemdir="${workdir}/system"
secretdir="${workdir}/secret"
varlogdir="${workdir}/varlog"
datadir="${workdir}/data"
volatiledir="${workdir}/volatile"
mountdir="${workdir}/mount"

# Make sure the directories exist
mkdir -p "${workdir}"
mkdir -p "${configdir}"
mkdir -p "${systemdir}"
mkdir -p "${secretdir}"
mkdir -p "${varlogdir}"
mkdir -p "${volatiledir}"
mkdir -p "${datadir}"

# Make sure the volatile directories exist
mkdir -p "${mountdir}"


# Mount the squashfs files to a loop device
sudo mount -t tmpfs -o size=1G,nr_inodes=10k,mode=700 tmpfs "${volatiledir}"
sudo mount -t squashfs config.fw "${configdir}" -o loop
sudo mount -t squashfs system.fw "${systemdir}" -o loop
sudo mount -t squashfs secret.fw "${secretdir}" -o loop

# Stacks the layers
sudo mount -t aufs -o br:${systemdir}=rr -o udba=reval none ${mountdir}
sudo mount -t aufs -o add:${configdir}=rr -o udba=reval none ${mountdir}/etc
sudo mount -t aufs -o remount,append:${secretdir}=rr -o udba=reval none ${mountdir}/etc/
sudo mount -t aufs -o remount,append:${varlogdir}=rw -o udba=reval none ${mountdir}/var/log
sudo mount -t aufs -o remount,append:${datadir}=rw -o udba=reval none ${mountdir}/mnt
sudo mount -t aufs -o remount,append:${volatiledir}=rw -o udba=reval none ${mountdir}
