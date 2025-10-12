# Linux kernel common hardware configuration fragments

The common folder contains Linux kernel sets of defconfig options anabling functionnality support (such as Video acceleration, USB peripheral drivers or NPU support). Options activated in these fragments are chosen in order to be shared accroiss all boards regardless of its software generic or high level functionalities.

The *common* configurations should be seen as a mutual defconfig ancestor, used by Firmware Toolkit for Linux kernel production, when generating the kernel *.defconfig* configuration files.

Thus *common* is included first, before *hardware* or *functional* fragments in the kernel Makefiles.
