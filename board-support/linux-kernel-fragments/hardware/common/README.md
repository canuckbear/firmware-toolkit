# Linux kernel common configuration fragments

The common folder contains Linux kernel sets of defconfig options shared accros all boards regardless of board hardware or kernel versions.

The *common* configurations should be seen as the common defconfig ancestor, used by Firmware Toolkit for Linux kernel production, when generating configuration files.

Thus *common* should be included first, before *hardware* or *functional* fragments in the kernel Makefiles.
