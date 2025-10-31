# Linux kernel comon functionnal configuration fragments

The common folder contains Linux kernel sets of defconfig options anabling functionnality support (such as IPV6 or iCRYPTO). Options activated in these fragments are chosen in order to be shared accross all boards regardless of hardware or kernel versions.

The *common* configurations should be seen as a mutual defconfig ancestor, used by Firmware Toolkit for Linux kernel production, when generating the kernel *.defconfig* configuration files.

Thus *common* is included first, before *hardware* or *functional* fragments in the kernel Makefiles.
