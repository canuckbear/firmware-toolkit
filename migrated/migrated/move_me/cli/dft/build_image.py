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
#    Jean-Marc Lacroix  jeanmarc.lacroix@free.fr
#
#

""" This module provides functionnalities used to create a binary image of a media from
the rootfs and bootchain.
"""

import logging
import os
import tempfile
import shutil
from datetime import datetime
from distutils import file_util
import parted
from dft.cli_command import CliCommand
from dft.enumkey import Key
from dft import release

#
#    Class BuildImage
#
class BuildImage(CliCommand):
  """This class implements method needed to build the image which will be
  written in flash memory or on a SD card.
  """

  # -------------------------------------------------------------------------
  #
  # __init__
  #
  # -------------------------------------------------------------------------
  def __init__(self, dft, project):
    """Default constructor
    """

    # Initialize ancestor
    CliCommand.__init__(self, dft, project)

    # Defines the loopback device used for image building. Initialiy it is None
    # Its value is retrieved from a call to "losetup -f" and stored in this member
    # Once released the member is set back to None
    self.loopback_device = None

    # Defines the absolute filepath to the image file. Default value is none. Value
    # is set when configuration is checked, and never set back to None.
    self.image_path = None

    # Flag used to know if the image is mounted or not. Initial value is False
    self.image_is_mounted = False



  # -------------------------------------------------------------------------
  #
  # build_image
  #
  # -------------------------------------------------------------------------
  def build_image(self):
    """This method implement the business logic of image generation. Image
    is a file containing the dump of what will be copied on the target
    storage device (harddisk or flash for example). It calls dedicated
    method for each step. The main steps are :

    . Creating the empty image file
    . Setup the loopback device
    . Copy rootfs content to image
    . Install the boot sectors
    . Umount the image and release loopback
    . Compress image file if reuired
    """

    # Control configuration file, and search for any missing information that could be a showstopper
    self.check_configuration_file()

    # Create the image file
    self.create_image_storage()

    # Create the loopbck device and mount the image file
    self.setup_loopback()

    # Setup the partitions in the image
    self.create_partitions_inside_image()

    # Create and format the filesystems on the newly created partitions
    self.create_filesystems()

    # Label the filesystems on the newly created partitions
    self.label_filesystems()

    # Copy rootfs to the image
    if self.project.is_image_content_rootfs():
      self.install_rootfs_content()
    else:
      self.install_firmware_content()

    # Install the boot (either grub or uboot)
    self.install_boot()

    # Check partition file systems (fsck)
    self.check_partition_filesystems()

    # Umount the image and release the loopback device
    self.umount_loopback_image()

    # Compress the generated image
    self.compress_image()

    # Final information if the information is available
    if self.image_path is not None:
      self.project.logging.info("The image has been successfully generated in : " + self.image_path)



  # -------------------------------------------------------------------------
  #
  # build_partitions
  #
  # -------------------------------------------------------------------------
  def build_partitions(self):
    """This method implement the business logic of partitions generation in
    the case of seperat partition generation. This is different of generating
    partitions within an image since there is one file per partition instead
    of only only one image file containing the partition table and all the
    partitions structure and data.

    The generated fies are name according to the image file. A suffix is added
    based upon partition number (in sequential order) and .part suffix.

    The main steps are :

    . Creating one empty file per partition
    . Setup each loopback device
    . Create filesystem inside the loopback
    . Mount the partitions according to the filesystem layout
    . Copy rootfs content to tree of partitions
    . Install the boot chain (no grub or bootloader)
    . Umount the partitions and release loopback
    . Compress partition files if reuired
    """

    # Create the partitions files
    # self.create_partitions_storage()

    # # Create the loopbck device and mount the partitions
    # self.setup_loopback()

    # # Setup the partitions in the image
    # should be removed ?
    # self.create_partitions_inside_storage()

    # # Create and format the filesystems on the newly created partitions
    # self.create_filesystems()

    # # Copy rootfs to the image
    # self.install_image_content()

    # # Install the boot (either grub or uboot)
    # self.install_boot()

    # # Umount the image and release the loopback deice
    # self.umount_loopback_image()

    # # Compress the generated partitions
    # self.compress_partitions()

    # # Final information if the information is available
    # if self.image_path is not None:
    # self.project.logging.info("The image has been successfully generated in : " + self.image_path)
    pass


  # -------------------------------------------------------------------------
  #
  # create_image_storage
  #
  # -------------------------------------------------------------------------
  def create_image_storage(self):
    """This method is in charge of crating the empty image file. The image
    file will later be mounted as a loop device, receive partitions, boot and
    rootfs content.

    The image is defined by the following parameters:
    . Filename of the image
    . Image size
    . Fill method (used to create initial content
    """

    # Output current task to logs
    logging.info("Creating the target image file")

    # Continue to check everything needed is defined
    try:
      size = int(self.project.image[Key.DEVICES.value][Key.SIZE.value])
    except ValueError:
      self.project.logging.critical("Image size is not a number : " +
                                    self.project.image[Key.DEVICES.value][Key.SIZE.value])
      exit(1)

    # Continue to check everything needed is defined
    if Key.UNIT.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.warning("Image size unit is not defined, defaultig to MB.")
      unit = "mb"
    else:
      unit = self.project.image[Key.DEVICES.value][Key.UNIT.value].lower()

    # Compute the block size to use based on the unit
    if unit == "s":
      block_size = 512
    elif unit == "b":
      block_size = 1
    elif unit == "kb" or unit == "kib":
      block_size = 1024
    elif unit == "mb" or unit == "mib":
      block_size = 1024 * 1024
    elif unit == "gb" or unit == "gib":
      block_size = 1024 * 1024 * 1024
    elif unit == "tb" or unit == "tib":
      block_size = 1024 * 1024 * 1024 * 1024
    else:
      self.project.logging.critical("Unknwon unit '" + unit + "' . Aborting")
      exit(1)

    # Some logging :)
    self.project.logging.debug("Image size unit is '" + str(unit) + "', block size is " +
                               str(block_size))

    if Key.FILL_METHOD.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.warning("Image fill method is not defined, filling with zero.")
      fill_method = "zero"
    else:
      fill_method = self.project.image[Key.DEVICES.value][Key.FILL_METHOD.value]

    if fill_method != "zero" and fill_method != "random":
      self.project.logging.critical("Unknown fill method '" + fill_method + "' . Aborting")
      exit(1)

    # Some logging :)
    self.project.logging.debug("Image fill method is '" + fill_method + "'")

    # Ensure target rootfs mountpoint exists and is a dir
    if os.path.isfile(self.project.get_image_directory()):
      self.project.logging.critical("Image target directory aldredy exist but is a file !")
      exit(1)

    # Create the directory if needed
    os.makedirs(self.project.get_image_directory(), exist_ok=True)

    # Generate the path
    self.image_path = self.project.get_image_directory() + "/"
    self.image_path += self.project.image[Key.DEVICES.value][Key.FILENAME.value]

    # Check if timestamping is activated
    if Key.FILENAME_TIMESTAMP.value in self.project.image[Key.DEVICES.value] and \
      self.project.image[Key.DEVICES.value][Key.FILENAME_TIMESTAMP.value]:
      # Timestamping is activated, retrieve format
      if Key.FILENAME_TIMESTAMP_FORMAT.value in self.project.image[Key.DEVICES.value]:
        timestamp_format = self.project.image[Key.DEVICES.value]\
                                             [Key.FILENAME_TIMESTAMP_FORMAT.value]
      else:
        # Timestamp format is not defined, use default value
        timestamp_format = "%Y%m%d"

      # Add timestamp to filename
      self.image_path += "." + datetime.now().strftime(timestamp_format)

    # Check if suffix is activated
    if Key.FILENAME_SUFFIX.value in self.project.image[Key.DEVICES.value]:
      # Yes thus concatenante it, unless it is empty
      if len(self.project.image[Key.DEVICES.value][Key.FILENAME_SUFFIX.value]) > 0:
        self.image_path += "." + self.project.image[Key.DEVICES.value][Key.FILENAME_SUFFIX.value]
    else:
      # No suffix is defined, let's defqult to ".img"
      self.image_path += ".img"

    self.project.logging.debug("The image file is : " + self.image_path)

    # Check if the image already exist and is a dir
    if os.path.isdir(self.image_path):
      self.project.logging.critical("Image target file aldredy exist but is a directory !")
      exit(1)

    # Check if the image already exist
    if os.path.isfile(self.image_path):
      self.project.logging.debug("Image target aldredy exist, removing it")
      os.remove(self.image_path)

    # Create the fill command
    command = 'dd if=/dev/' + fill_method + ' of="' + self.image_path
    command += '" bs=' + str(block_size) + ' count=' + str(size)
    self.execute_command(command)



  # -------------------------------------------------------------------------
  #
  # setup_loopback
  #
  # -------------------------------------------------------------------------
  def setup_loopback(self):
    """This method is in charge of setting up the loopback device using the
    image created.

    There is two main step :
    . Find the next available loopback device
    . Mout the file in the loopbck device
    """

    # Retrieve the next available loopback device
    command = "/sbin/losetup -f"
    command_output = self.execute_command(command)

    # Parse the output to retrive the device and store it
    binaryline = command_output.splitlines()
    self.loopback_device = binaryline[0].decode(Key.UTF8.value)

    # Check that the image is not mounted and path is defined and exist
    if not self.image_is_mounted:
      if self.image_path is not None:
        if os.path.isfile(self.image_path):
          # Mount the image in the loopback device
          command = '/sbin/losetup "' + self.loopback_device + '" "'
          command += self.image_path + '"'
          command_output = self.execute_command(command)
          # Set the flag to True, if an error occured an exception has been raised, and this line
          # is not executed
          self.image_is_mounted = True
        else:
          logging.critical("Image file '" + self.image_path + "' does not exist. Aborting !")
          exit(1)
      else:
        logging.critical("Image file path is not defined. Aborting !")
        exit(1)
    else:
      logging.critical("Image is already mounted. Aborting !")
      exit(1)

    # Output current task to logs
    logging.info("Setting up the loopback device")



  # -------------------------------------------------------------------------
  #
  # create_partitions_inside_image
  #
  # -------------------------------------------------------------------------
  def create_partitions_inside_image(self):
    """This method creates the partition table and the different partitions
    in the loopback device. It first read the device definition, then iterate
    the list of partitions.

    Device operation are done using the pyparted library.
    """
#TODO cleanup method to remove loopback

    # Output current task to logs
    logging.info("Creating the partitions in the image mounted in loopback")

    # Retrieve the partition type to create
    if Key.LABEL.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.warning("Partition table label is not defined, defaulting to dos.")
      label = "msdos"
    else:
      label = self.project.image[Key.DEVICES.value][Key.LABEL.value]

    # Check that the value is in the list of valid values
    if label not in "aix" "amiga" "bsd" "dvh" "gpt" "loop" "mac" "msdos" "pc98" "sun":
      self.project.logging.critical("Unknown partition label '" + label + "' . Aborting")
      exit(1)
    else:
      self.project.logging.debug("Using partition label '" + label + "'")

    # Retrieve the partition alignment
    if Key.ALIGNMENT.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.warning("Partition alignment is not defined, defaulting to none.")
      alignment = "none"
    else:
      alignment = self.project.image[Key.DEVICES.value][Key.ALIGNMENT.value]

    # TODO : handle partition alignment

    # Check that the value is in the list of valid values
    # if alignment == "none":
    #   parted_alignment = None
    # elif alignment == "optimal":
    #   parted_alignment = parted.OPTIMAL
    # elif alignment == "cylinder":
    #   parted_alignment = cylinder
    # elif alignment == "minimal":
    #   parted_alignment = minimal
    # else:
    #   self.project.logging.critical("Unknown partition alignment '" + alignment + "' . Aborting")
    #   exit(1)

    self.project.logging.debug("Using partition alignment '" + alignment + "'")

    # Starting from here we start to interact with parted binding. Thus it may fail and raise
    # an exception
    try:

      # Create the partition tabl on the device
      device = parted.getDevice(self.loopback_device)

      # Create a new disk object
      disk = parted.freshDisk(device, label)

      # Now iterate the partition table and create them
      for partition in self.project.image[Key.DEVICES.value][Key.PARTITIONS.value]:

        # Retrieve the partition name
        if Key.NAME.value in partition:
          part_name = partition[Key.NAME.value]
        else:
          part_name = ""

        self.project.logging.debug("Partition name =>  '" + part_name + "'")

        # Retrieve the partition type
        if Key.TYPE.value in partition:
          part_type = partition[Key.TYPE.value]
        else:
          part_type = "primary"

        # Check that the partition type is valid and convert in parted "define"
        if part_type == "primary":
          parted_type = parted.PARTITION_NORMAL
        elif part_type == "extended":
          parted_type = parted.PARTITION_EXTENDED
        elif part_type == "logical":
          parted_type = parted.PARTITION_LOGICAL
        else:
          self.project.logging.critical("Unknown partition type '" + part_type + "' . Aborting")
          exit(1)

        self.project.logging.debug("Partition type =>  '" + part_type + "'")

        # Retrieve the partition size
        if Key.SIZE.value not in partition:
          self.project.logging.critical("Partition size is not defined. Aborting")
          exit(1)
        else:
          # Retrieve the value and control it is an integer
          try:
            part_size = int(partition[Key.SIZE.value])
          except ValueError:
            self.project.logging.critical("Partition size is not a number : " +
                                          partition[Key.SIZE.value])
            exit(1)

        self.project.logging.debug("Partition size => '" + str(part_size) + "'")

        # Retrieve the partition unit
        if Key.UNIT.value not in partition:
          self.project.logging.warning("Partition size unit is not defined, defaultig to MB.")
          part_unit = "MB"
        else:
          part_unit = partition[Key.UNIT.value]

        # Compute the block size to use based on the unit
        if part_unit not in "s" "B" "KB" "KiB" "MB" "MiB" "GB" "GiB" "TB" "TiB":
          self.project.logging.critical("Unknwon unit '" + part_unit + "' . Aborting")
          exit(1)
        else:
          self.project.logging.debug("Partition unit => '" + part_unit + "'")

        # Retrieve the partition start sector
        if Key.START_SECTOR.value not in partition:
          self.project.logging.warning("Partition start_sector is not defined. " +
                                       "Using next available in sequence")
          part_start_sector = -1
        else:
          # Retrieve the value and control it is an integer
          try:
            part_start_sector = int(partition[Key.START_SECTOR.value])
          except ValueError:
            self.project.logging.critical("Partition start_sector is not a number : " +
                                          partition[Key.START_SECTOR.value])
            exit(1)

        self.project.logging.debug("Partition start sector => '" + str(part_start_sector) + "'")

        # Retrieve the partition flags
        if Key.FLAGS.value not in partition:
          self.project.logging.debug("Partition flags are not defined. Skipping...")
          part_flags = None
        else:
          part_flags = partition[Key.FLAGS.value]
          self.project.logging.debug("Partition flags => '" + part_flags + "'")

        # Retrieve the partition file system type
        if Key.FILESYSTEM.value not in partition:
          self.project.logging.debug("File system to create on the partition is not defined.")
          part_filesystem = None
        else:
          part_filesystem = partition[Key.FILESYSTEM.value].lower()
          # Check that the value is in the list of valid values
          if part_filesystem not in parted.fileSystemType:
            self.project.logging.critical("Unknown filesystem type '" + part_filesystem +
                                          "' . Aborting")
            exit(1)
          else:
            self.project.logging.debug("Filesystem type =>  '" + part_filesystem + "'")

        # Retrieve the partition format flag
        if Key.FORMAT.value not in partition:
          self.project.logging.debug("File system format flag is not defined. Defaulting to True")
          part_format = True
        else:
          part_format = partition[Key.FORMAT.value]
          self.project.logging.debug("File system format flag => '" + str(part_format) + "'")

        #
        # All information have been parsed,now let's create the partition in the loopback device
        #

        # Compute the sector count based on size and unit. Need for parted
        sector_count = parted.sizeToSectors(part_size, part_unit, device.sectorSize)
        self.project.logging.debug("Partition " + part_name + " sectors count is " + str(sector_count))

        # Compute the geometry for this device
        geometry = parted.Geometry(start=part_start_sector, length=sector_count, device=device)

        # Create the parted filesystem object
        if part_filesystem is not None:
          filesys = parted.FileSystem(type=part_filesystem, geometry=geometry)

        # Create the partition object in the loopback device
        new_partition = parted.Partition(disk=disk, type=parted_type, geometry=geometry, fs=filesys)

        # Setting the name of the partitionis not yet supported / fixed in pyparted.
        # It should be done here, but since it is not working an extra loop is added after
        # commiting changes to the disk. The loop will iterate once again the partition loop and
        # call the program in charge of setting the partition name, according to the filesystem
        # below.
        # if ( part_name != ""):
        #  new_partition.set_name(name

        # Create the constraint object for alignment, etc.
        # constraint = parted.Constraint(startAlign=parted_alignment, endAlign=parted_alignment, \
        #              startRange=start, endRange=end, minSize=min_size, maxSize=max_size)
        constraint = parted.Constraint(exactGeom=new_partition.geometry)

        # Add the partition to the disk
        disk.addPartition(partition=new_partition, constraint=constraint)

      # Make modification persistent to disk
      disk.commit()

    except parted.PartitionException as exception:
      self.cleanup()
      self.project.logging.critical("Error occured : %s", exception)
      exit(1)



  # -------------------------------------------------------------------------
  #
  # install_rootfs_content
  #
  # -------------------------------------------------------------------------
  def install_rootfs_content(self):
    """This method installs the content from the generated rootfs into the
    partition previously created and formwated.

    The method execute several iterations of the partitions lists from the
    device entry.

    . First iteration compute the list of partition to mount, sort them and
      push mounts to a list
    . Second iteration is on the list of mounts, remove mount points one by
      one, creates, under a temporary directory, the path need to execute the
      mount command, then do the mount and push the path to the list of
      directories to umount
    . Copy recursivly the rootfs to the mounted partitions
    . Iterate the umount list and cleanup things
    """

    # Output current task to logs
    logging.info("Installating rootfs image content")

    # Defines a primary partition counter. Starts at zero and is incremented at each iteration
    # beginning. It means first partition is 1.
    primary_part_index = 0

    # Defines a cwlogical partition counter. Starts at four and is incremented at each iteration
    # beginning. It means first partition is 5.
    logical_part_index = 4

    # Defines the current partition which can be either primary (or extended) or logical.
    part_index = 0

    # Get a temporary directory used as root for image mounting
    image_mount_root = tempfile.mkdtemp(dir=self.project.get_image_directory())

    # Define the list of path to mount and umount which is are empty list at start
    # We need these list to sort path before mounting to prevent false order of declaration
    path_to_mount = []
    path_to_umount = []

    # Now iterate the partition tables and create them
    for partition in self.project.image[Key.DEVICES.value][Key.PARTITIONS.value]:

      # Check if current partition is logical, then increase the counter and set
      # current partition index
      if partition[Key.TYPE.value] == Key.LOGICAL.value:
        logical_part_index += 1
        part_index = logical_part_index
      else:
        # If partition is not logicial, then increase the other index and use it
        primary_part_index += 1
        part_index = primary_part_index

      # Retrieve the partition format flag
      if Key.FORMAT.value not in partition:
        self.project.logging.debug("File system format flag is not defined. Defaulting to True")
        part_format = True
      else:
        part_format = partition[Key.FORMAT.value]
        self.project.logging.debug("File system format flag => '" + str(part_format) + "'")

      # Process only if the partition has been formatted and mapping is defined
      if part_format and Key.CONTENT_PARTITION_MAPPING.value in partition:

        # Generate the mount point for the given partition
        path = {}
        path["device"] = self.loopback_device + "p" + str(part_index)
        path["path"] = image_mount_root + partition[Key.CONTENT_PARTITION_MAPPING.value]
        path_to_mount.append(path)

    #
    # All the partitions have been identified, now let's sot them in mount order and do mount
    #

    # Sort the list usingpath as the key, in reverse order sinc path will be popped
    path_to_mount.sort(key=lambda p: p["path"], reverse=True)
    while len(path_to_mount) > 0:
      # Get the next item to mount
      path = path_to_mount.pop()

      # Create the local mount point if needed
      os.makedirs(path["path"], exist_ok=True)

      # Generate the ount command
      command = 'mount "' + path["device"] + '" "' + path["path"] + '"'
      self.execute_command(command)

      # Mount was successful, thus push the path in the umount list
      path_to_umount.append(path["path"])

    #
    # All the partitions have been mounted now let's copy the data
    #
    logging.debug("Starting to copy rootfs image content")

    # Iterate the list of files in the rootfs and copy them to image
    for copy_target in os.listdir(self.project.get_rootfs_mountpoint()):
      copy_source_path = os.path.join(self.project.get_rootfs_mountpoint(), copy_target)
      copy_target_path = os.path.join(image_mount_root, copy_target)
      command = "cp -fra " + copy_source_path + " " + copy_target_path
      self.execute_command(command)

    # Generate the bootscript
    self.generate_bootscript(image_mount_root)

    #
    # Data have been copied, lets unmount all the partitions before teardown the loopback
    #

    # First let's sort the list to umount in the same order as the fs have been mounted
    # (never umout /var before /var/log). Sort is in normal order since we pop the list
    path_to_umount.sort()
    while len(path_to_umount) > 0:
      # Generate the uount command
      self.umount_mountpoint(path_to_umount.pop())

    # Remove the temporary mount point before exiting
    shutil.rmtree(image_mount_root)



  # -------------------------------------------------------------------------
  #
  # install_boot
  #
  # -------------------------------------------------------------------------
  def install_boot(self):
    """This method installs in the generated rootfs the tools needed to update
    (or generate) theinitramfs. The kernel is not installed, it is the job of
    the install_bootchain target. The kernel to use is defined in the BSP
    used by this target.

    Operations executed by this method run in a chrooted environment in the
    generated rootfs.
    """

    # Check if a BSP section is defined. It should be, or we certainly have failed before anyways
    if Key.BSP.value in self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value][0]:

      # And that it contains a uboot section. Otherwise it may be a grub section
      if Key.UBOOT.value in self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value]\
                                              [0][Key.BSP.value]:

        # Is there somepackages to install ?
        target = self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value][0]\
                                     [Key.BSP.value][Key.UBOOT.value]

        if Key.PACKAGES.value in target:
          logging.info("Installing the boot support packages (uboot or grub)")

          # Check if we are working with foreign arch, then ...
          if self.use_qemu_static:
            # QEMU is used, and we have to install it into the target
            self.setup_qemu()

          # Setup the packages sources
          self.setup_kernel_apt_sources(target, self.project.project[Key.PROJECT_DEFINITION.value]\
                                                                    [Key.TARGETS.value][0]\
                                                                    [Key.VERSION.value])

          # Install the kernel packages
          self.install_kernel_apt_packages(target)

          # Remove QEMU if it has been isntalled. It has to be done in the end
          # since some cleanup tasks could need QEMU
          if self.use_qemu_static:
            self.cleanup_qemu()

      else:
        logging.debug("No u-boot entry in the BSP. Nothing to do...")
    else:
      logging.warning("The '" + Key.BSP.value + "' key is not defined for target '" +
                      self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value][0]\
                                          [Key.BOARD.value] + "'")

    # Output current task to logs
    logging.info("Installing the boot (uboot or grub)")

    # Check if a BSP section is defined. It should be, or we certainly have failed before anyways
    if Key.BSP.value in self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value][0]:

      # And that it contains a uboot section. Otherwise it may be a grub section
      if Key.UBOOT.value in self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value]\
                                              [0][Key.BSP.value]:

        if Key.INSTALLATION.value in self.project.project[Key.PROJECT_DEFINITION.value]\
                                                         [Key.TARGETS.value][0]\
                                                         [Key.BSP.value][Key.UBOOT.value]:
          # Iterate the list of actions. An action is a dd call to copy binary data to the image
          for action in self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value][0]\
                                            [Key.BSP.value][Key.UBOOT.value]\
                                            [Key.INSTALLATION.value]:

            # Check that the source is defined. Otherwise it will not be able to call dd
            if Key.SOURCE.value not in action:
              logging.critical("No source defined in the uboot installation action. Aborting.")
              exit(1)
            else:
              # Copy the source
              source = self.project.get_rootfs_mountpoint() + "/" + action[Key.SOURCE.value]

              # If the source is an absolute path, then use it "as is", otherwise prefix with
              # the bsp root
              if not os.path.isabs(source):
                logging.critical("Source is not an absolute path. Meaning roootfs_base is not \
                                 neither. Aborting.")
                exit(1)

            # Check if options is defined, if not default to an empty string, many "jut call dd
            # without options"
            if Key.OPTIONS.value not in action:
              logging.debug("No options defined.")
              options = ""
            else:
              options = action[Key.OPTIONS.value]

            # Let's run dd to copy to the image
            command = 'dd if="' + source + '" of="' + self.loopback_device + '" ' + options
            self.execute_command(command)
      else:
        logging.debug("No UBOOT defined, skipping.")
    else:
      logging.warning("No BSP defined, skipping. The generated image will may not be able to boot")



    # ][Key.KERNEL.value][Key.ORIGIN.value] not in \
    #   "devuan" "debian" "armbian":
    #   logging.error("Unknown kernel provider '" + target[Key.BSP.value][Key.ORIGIN.value] + "'")
    #   exit(1)


    # if Key.DEVICES.value not in self.project.image:
    #   self.project.logging.critical("The image devices is not defined in configuration file")
    #   exit(1)

    # # Check that the filename is available from the devices section in the configuration file
    # if Key.UBOOT.value in self.project.image[Key.DEVICES.value]:
    #   self.project.logging.debug("Installing uboot")
    #   exit(1)



  # -------------------------------------------------------------------------
  #
  # check_partition_filesystems
  #
  # -------------------------------------------------------------------------
  def check_partition_filesystems(self):
    """This method is in charge of checking partition file systems once content
    has been writtent. Basicaly it does a fsck.
    """

    # Output current task to logs
    logging.info("Checking partitions filesystems")

    # Defines a primary partition counter. Starts at zero and is incremented at each iteration
    # beginning. It means first partition is 1.
    primary_part_index = 0

    # Defines a cwlogical partition counter. Starts at four and is incremented at each iteration
    # beginning. It means first partition is 5.
    logical_part_index = 4

    # Defines the current partition which can be either primary (or extended) or logical.
    part_index = 0

    # Now iterate the partition tables and create them
    for partition in self.project.image[Key.DEVICES.value][Key.PARTITIONS.value]:

      # Check if current partition is logical, then increase the counter and set
      # current partition index
      if partition[Key.TYPE.value] == Key.LOGICAL.value:
        logical_part_index += 1
        part_index = logical_part_index
      else:
        # If partition is not logicial, then increase the other index and use it
        primary_part_index += 1
        part_index = primary_part_index

      # Retrieve the partition format flag
      if Key.FORMAT.value not in partition:
        self.project.logging.debug("File system format flag is not defined. Defaulting to True")
        part_format = True
      else:
        part_format = partition[Key.FORMAT.value]
        self.project.logging.debug("File system format flag => '" + str(part_format) + "'")

      # Process only if the partition has been formatted and mapping is defined
      if part_format and Key.CONTENT_PARTITION_MAPPING.value in partition:
        # Generate the command to check the device
        command = 'fsck -f -y ' + self.loopback_device + "p" + str(part_index)
        self.project.logging.debug("Checking partition : " + command)
        self.execute_command(command)



  # -------------------------------------------------------------------------
  #
  # umount_loopback_image
  #
  # -------------------------------------------------------------------------
  def umount_loopback_image(self):
    """This method is in charge of cleaning the environment once image content
    is written.

    The main steps are :
    . umounting the image
    . release the loopback device
    """

    # Check that the loopback device is defined
    if self.loopback_device is not None:
      # Copy the stacking script to /tmp in the rootfs
      command = 'losetup -d ' + self.loopback_device
      self.execute_command(command)

      # Loopback has been released, set the member to None
      self.loopback_device = None

      # Image has been umounted, set the member flag to None
      self.image_is_mounted = False
    else:
      logging.debug("Loopback device is not defined")

    # Output current task to logs
    logging.info("Umounting the image and releasing the loopback devices")

  # -------------------------------------------------------------------------
  #
  # create_filesystes
  #
  # -------------------------------------------------------------------------
  def create_filesystems(self):
    """This method creates the file systems on the partition created by the
    create_partitions_inside_image method. It uses the same configuration file.

    File system creation is implemented in a different method since it has tp
    be done after partition creation and commit. It can't be done on the fly.

    This code has been separated to make it more easy to read and maintain.

    Since it is executed in sequence after partition creation, configuration
    file is not checked again for the same parameters. Only parameters
    specific to filesystems are checked.
    """

    # Output current task to logs
    logging.info("Creating the filesystems in the newly created partitions")

    # Defines a primary partition counter. Starts at zero and is incremented at each iteration
    # beginning. It means first partition is 1.
    primary_part_index = 0

    # Defines a cwlogical partition counter. Starts at four and is incremented at each iteration
    # beginning. It means first partition is 5.
    logical_part_index = 4

    # Defines the current partition which can be either primary (or extended) or logical.
    part_index = 0

    # Nox iterate the partitiontables and create them
    for partition in self.project.image[Key.DEVICES.value][Key.PARTITIONS.value]:

      # Check if current partition is logical, then increase the counter and set
      # current partition index
      if partition[Key.TYPE.value] == Key.LOGICAL.value:
        logical_part_index += 1
        part_index = logical_part_index
      else:
        # If partition is not logicial, then increase the other index and use it
        primary_part_index += 1
        part_index = primary_part_index

      # Retrieve the partition format flag
      if Key.FORMAT.value not in partition:
        self.project.logging.debug("File system format flag is not defined. Defaulting to False")
        part_format = False
      else:
        part_format = partition[Key.FORMAT.value]
        self.project.logging.debug("File system format flag => '" + str(part_format) + "'")

      # Check if the flag is true, if not there is nothing to do
      if not part_format:
        self.project.logging.debug("The format flag is deactivated for martition " \
                                   + str(part_index))
      else:
        # Retrieve the partition file system type
        if Key.FILESYSTEM.value not in partition:
          self.project.logging.debug("File system to create on the partition is not defined.")
          part_filesystem = None
        else:
          part_filesystem = partition[Key.FILESYSTEM.value].lower()

        # Default is having no format nor tunefs tool. It will be checked after fs type
        # control and tool command guessing
        format_tool = None
        tune_tool = None

        # Check that the value is in the list of valid values
        if part_filesystem == "ext2":
          format_tool = "mkfs.ext2"
          tune_tool = "tune2fs"
        elif part_filesystem == "ext3":
          format_tool = "mkfs.ext3"
          tune_tool = "tune2fs"
        elif part_filesystem == "ext4":
          format_tool = "mkfs.ext4"
          tune_tool = "tune2fs"
        elif part_filesystem == "fat12":
          format_tool = "mkfs.vfat -F 12"
        elif part_filesystem == "fat16":
          format_tool = "mkfs.vfat -F 16"
        elif part_filesystem == "fat32":
          format_tool = "mkfs.vfat -F 32"
        elif part_filesystem == "linux-swap(v0)" or part_filesystem == "linux-swap(v1)":
          format_tool = "mkswap"

        # Creation du file fystem sur a prtition
        if part_filesystem is not None and format_tool is not None:
          command = format_tool + ' ' + self.loopback_device + 'p' + str(part_index)
          self.execute_command(command)

        # Check if some ext filesystems options should be applied (accord to man tune2fs)
        if Key.EXT_FS_TUNE.value in partition and tune_tool is not None:
          command = tune_tool + ' ' + partition[Key.EXT_FS_TUNE.value]
          command += ' ' + self.loopback_device + 'p' + str(part_index)
          self.execute_command(command)



  # -------------------------------------------------------------------------
  #
  # label_filesystes
  #
  # -------------------------------------------------------------------------
  def label_filesystems(self):
    """This method set the file systems labels on the partition created by the
    create_partitions_inside_image method. It uses the same configuration file.
    """

    # Output current task to logs
    logging.info("Labeling the filesystems in the newly created partitions")

    # Defines a primary partition counter. Starts at zero and is incremented at each iteration
    # beginning. It means first partition is 1.
    primary_part_index = 0

    # Defines a cwlogical partition counter. Starts at four and is incremented at each iteration
    # beginning. It means first partition is 5.
    logical_part_index = 4

    # Defines the current partition which can be either primary (or extended) or logical.
    part_index = 0

    # Now iterate once again the partition tables to set labels
    for partition in self.project.image[Key.DEVICES.value][Key.PARTITIONS.value]:

      # Check if current partition is logical, then increase the counter and set
      # current partition index
      if partition[Key.TYPE.value] == Key.LOGICAL.value:
        logical_part_index += 1
        part_index = logical_part_index
      else:
        # If partition is not logicial, then increase the other index and use it
        primary_part_index += 1
        part_index = primary_part_index

      # Retrieve the partition name, and process only if there is a name
      if Key.NAME.value in partition:
        part_name = partition[Key.NAME.value]

        # Retrieve the partition file system type. It should be defined or we can't label it
        if Key.FILESYSTEM.value not in partition:
          self.project.logging.error("Partition label is defined but there is no filesystem set" \
                                     " for partition " + str(part_index))
        else:
          part_filesystem = partition[Key.FILESYSTEM.value].lower()

          # Retrieve the partition format flag. It should be formatted or we can't label it.
          if Key.FORMAT.value in partition and not partition[Key.FORMAT.value]:
            self.project.logging.error("Partition label is defined, but partition " + \
                                       str(part_index) + " is not formatted")
          else:
            # Go so far, thus all checks are ok we can label and select tool according to FS
            label_tool = None

            # Check that the value is in the list of valid values
            if part_filesystem == "ext2" or part_filesystem == "ext3" or part_filesystem == "ext4":
              label_tool = "e2label"
            elif part_filesystem == "fat32":
              label_tool = "fatlabel"

            # If the label tool is defined let's call it
            if label_tool:
              command = label_tool + ' ' + self.loopback_device + 'p' + str(part_index)
              command += ' ' + part_name
              self.execute_command(command)
            else:
              self.project.logging.error("No labelling tool is defined for partition " + \
                                         str(part_index) + " with file system " + part_filesystem)



  # -------------------------------------------------------------------------
  #
  # compress_image
  #
  # -------------------------------------------------------------------------
  def compress_image(self):
    """This method is in charge of checking compression configuration and
    options, and if needed to run the compression tools on the iage.

    The compression is done by running the selected compression tool as a
    subpress. The python compression library is not (yet?) called since the
    compressor usage is really basic.
    """

    # Output current task to logs
    logging.info("Compressing the image")

    # Check that the compression tool is defined
    if Key.COMPRESSION.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.info("No compression mode is defined. Skipping image copmpression")
      return

    # Retrieve the compression tool and check its vaidity
    compression_tool = self.project.image[Key.DEVICES.value][Key.COMPRESSION.value].lower()
    if compression_tool == "" or compression_tool == "none":
      self.project.logging.info("Compression is deactivated. Skipping image copmpression")
      return
    # Check for lzma format
    elif compression_tool == Key.LZMA.value:
      compression_tool = "/usr/bin/env xz -z --format=lzma"
      compression_suffix = ".lzma"
    # Check for xz format
    elif compression_tool == Key.XZ.value:
      compression_tool = "/usr/bin/env xz -z"
      compression_suffix = ".xz"
    # Check for bzip2 format
    elif compression_tool == Key.BZIP2.value:
      compression_tool = "/usr/bin/env bzip2"
      compression_suffix = ".bz2"
    # Check for gzip format
    elif compression_tool == Key.GZIP.value:
      compression_tool = "/usr/bin/env gzip"
      compression_suffix = ".gz"
    else:
      self.project.logging.error("Unknow compression method '" + compression_tool +
                                 "'. Skipping image copmpression")
      return

    # Check that the filename is available from the devices section in the configuration file
    if Key.COMPRESSION_OPTIONS.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.debug("Compression options are not defined. Defaulting to empty string")
      compression_options = ""
    else:
      compression_options = self.project.image[Key.DEVICES.value][Key.COMPRESSION_OPTIONS.value]

    # Test for compressed image existence and remove it if needed
    if os.path.isfile(self.image_path + compression_suffix):
      self.project.logging.debug("Compressed image aldredy exist, removing it")
      os.remove(self.image_path + compression_suffix)

    # Let's run dd to copy to the image
    command = compression_tool + ' ' + compression_options + '"' + self.image_path + '"'
    self.execute_command(command)

    # Update the image file name
    self.image_path = self.image_path + compression_suffix



  # -------------------------------------------------------------------------
  #
  # cleanup
  #
  # -------------------------------------------------------------------------
  def cleanup(self):
    """This method is in charge of cleaning the environment in cqse of errors
    It is mainly umounting the image and removing the losetup mount.
    The generated image is left for post mortem anaysis.
    """
    self.project.logging.info("starting to cleanup")

    # Umount the image and remove the losetup mount
    self.umount_loopback_image()

    # Finally umount all the chrooted environment
    self.teardown_chrooted_environment()



  # -------------------------------------------------------------------------
  #
  # install_firmware_content
  #
  # -------------------------------------------------------------------------
  def install_firmware_content(self):
    """This method installs the content from the generated firmware into the
    partition previously created and formwated.

    The method execute several iterations of the partitions lists from the
    device entry.

    . Scan the firmware parameter to identify the list of banks to mount
    . Mount each activated banks
    . Copy either the firmware to bank_0 and 1 if activated
    . Generate and copy the boot script to current bank for each bank
    . Copy the rescue firmware if activated
    """

    # Output current task to logs
    logging.info("Installating firmware image content")

    # ---------------------------------------------------------------------------------------------
    #
    # Populate bank 0 partitions (mandatory)
    #
    # ---------------------------------------------------------------------------------------------

    # Get a temporary directory used as root for image mounting
    image_mount_root = tempfile.mkdtemp(dir=self.project.get_image_directory())

    # Bank 0 has to be defined (already checked for), mount it under bank_0
    bank_0_mountpoint = image_mount_root + "/" + Key.BANK_0.value

    # Create the local mount point if needed
    os.makedirs(bank_0_mountpoint, exist_ok=True)

    # Generate the device string based upon partitions information
    # And no part index as it is done for rootfs
    device = self.loopback_device + "p" + str(self.project.firmware[Key.RESILIENCE.value]\
                                                                   [Key.PARTITIONS.value]\
                                                                   [Key.BANK_0.value]\
                                                                   [Key.PARTITION.value])

    # Mount the device
    command = 'mount "' + device + '" "' + bank_0_mountpoint + '"'
    self.execute_command(command)

    # Iterate the list of files in the rootfs and copy them to image
    for copy_target in os.listdir(self.project.get_firmware_content_directory()):
      copy_source_path = os.path.join(self.project.get_firmware_content_directory(), copy_target)
      copy_target_path = os.path.join(bank_0_mountpoint, copy_target)
      command = "cp -fra " + copy_source_path + " " + copy_target_path
      self.execute_command(command)

    # Generate the boootscript into the current bank partition
    self.generate_bootscript(bank_0_mountpoint)

    # Copy is done, let's umount the device
    self.umount_mountpoint(bank_0_mountpoint)


    # ---------------------------------------------------------------------------------------------
    #
    # Populate bank 1 partition (optional)
    #
    # ---------------------------------------------------------------------------------------------

    # Check if Bank 1 is activated. If yes, it is mounted under bank_1
    if Key.DUAL_BANKS.value in self.project.firmware[Key.RESILIENCE.value] and \
                               self.project.firmware[Key.RESILIENCE.value][Key.DUAL_BANKS.value]:
      # Generate mount point
      bank_1_mountpoint = image_mount_root + "/" + Key.BANK_1.value

      # Create the local mount point if needed
      os.makedirs(bank_1_mountpoint, exist_ok=True)

      # Generate the device string based upon partitions information
      # And no part index as it is done for rootfs
      device = self.loopback_device + "p" + str(self.project.firmware[Key.RESILIENCE.value]\
                                                                     [Key.PARTITIONS.value]\
                                                                     [Key.BANK_1.value]\
                                                                     [Key.PARTITION.value])

      # Mount the device
      command = 'mount "' + device + '" "' + bank_1_mountpoint + '"'
      self.execute_command(command)

      # Iterate the list of files in the rootfs and copy them to image
      for copy_target in os.listdir(self.project.get_firmware_content_directory()):
        copy_source_path = os.path.join(self.project.get_firmware_content_directory(), copy_target)
        copy_target_path = os.path.join(bank_1_mountpoint, copy_target)
        command = "cp -fra " + copy_source_path + " " + copy_target_path
        self.execute_command(command)

      # Generate the boootscript into the current bank partition
      self.generate_bootscript(bank_1_mountpoint)

      # Copy is done, let's umount the device
      self.umount_mountpoint(bank_1_mountpoint)

    # ---------------------------------------------------------------------------------------------
    #
    # Populate rescue partition (optional)
    #
    # ---------------------------------------------------------------------------------------------

    # Check if rescue image is activated
    if Key.RESCUE_IMAGE.value in self.project.firmware[Key.RESILIENCE.value] and \
                                 self.project.firmware[Key.RESILIENCE.value]\
                                                      [Key.RESCUE_IMAGE.value]:
      # Generate mount point
      rescue_mountpoint = image_mount_root + "/" + Key.RESCUE.value

      # Create the local mount point if needed
      os.makedirs(rescue_mountpoint, exist_ok=True)

      # Generate the device string based upon partitions information
      # And no part index as it is done for rootfs
      device = self.loopback_device + "p" + str(self.project.firmware[Key.RESILIENCE.value]\
                                                                     [Key.PARTITIONS.value]\
                                                                     [Key.RESCUE.value]\
                                                                     [Key.PARTITION.value])

      # Mount the device
      command = 'mount "' + device + '" "' + rescue_mountpoint + '"'
      self.execute_command(command)


      # Not yet implemented...
      self.project.logging.info("Rescue firmware copy is not yet implemented")

      # Generate the boootscript into the current bank partition
      self.generate_bootscript(rescue_mountpoint)

      # Copy is done, let's umount the device
      self.umount_mountpoint(rescue_mountpoint)


    # ---------------------------------------------------------------------------------------------
    #
    # Populate update partition (optional)
    #
    # ---------------------------------------------------------------------------------------------

    # Check if update partition is activated
    if Key.UPDATE_PARTITION.value in self.project.firmware[Key.RESILIENCE.value] and \
                                     self.project.firmware[Key.RESILIENCE.value]\
                                                          [Key.UPDATE_PARTITION.value]:
      # Generate mount point
      update_mountpoint = image_mount_root + "/" + Key.UPDATE.value

      # Create the local mount point if needed
      os.makedirs(update_mountpoint, exist_ok=True)

      # Generate the device string based upon partitions information
      # And no part index as it is done for rootfs
      device = self.loopback_device + "p" + str(self.project.firmware[Key.RESILIENCE.value]\
                                                                     [Key.PARTITIONS.value]\
                                                                     [Key.UPDATE.value]\
                                                                     [Key.PARTITION.value])

      # Mount the device
      command = 'mount "' + device + '" "' + update_mountpoint + '"'
      self.execute_command(command)

      # Not yet implemented...
      self.project.logging.info("Update partition copy is not yet implemented. Nothing to do ?")

      # Copy is done, let's umount the device
      self.umount_mountpoint(update_mountpoint)

    #
    # Data have been copied, lets unmount all the partitions before teardown the loopback
    #

    # Remove the temporary mount point before exiting
    shutil.rmtree(image_mount_root)


  # -------------------------------------------------------------------------
  #
  # check_configuration_file
  #
  # -------------------------------------------------------------------------
  def check_configuration_file(self):
    """This method check the configuration file for any missing information
    that would stop the process. All the missing keys are output, then the
    execution fails.
    """

    # Flag if an error has bee found
    missing_configuration_found = False

    # Check that there is an image configuration file first
    if self.project.image is None:
      self.project.logging.critical("The image configuration file is not defined in project file")
      missing_configuration_found = True

    # Check that the devices is available from the configuration file
    if Key.DEVICES.value not in self.project.image:
      self.project.logging.critical("The image devices is not defined in configuration file")
      missing_configuration_found = True

    # Check that the filename is available from the devices section in the configuration file
    if Key.FILENAME.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.critical("The filename is not defined in the configuration file")
      missing_configuration_found = True

    # Continue to check everything needed is defined
    if Key.SIZE.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.critical("Image size is not defined in the devices section. Aborting.")
      missing_configuration_found = True

    # Partitions table must be defined
    if Key.PARTITIONS.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.error("Partition table is not defined, nothing to do. Aborting")
      missing_configuration_found = True

    # Check for mandatory information in firmware mode
    if self.project.is_image_content_firmware():
      # Resilience has to be defined
      if Key.RESILIENCE.value not in self.project.firmware:
        self.project.logging.critical("Resilience section is not defined firmware")
        missing_configuration_found = True

      # Partition section has to be defined
      if Key.PARTITIONS.value not in self.project.firmware[Key.RESILIENCE.value]:
        self.project.logging.critical("Partitions section is not defined firmware resilience")
        missing_configuration_found = True

      # At least bank0 has to be defiend
      if Key.BANK_0.value not in self.project.firmware[Key.RESILIENCE.value]\
                                                      [Key.PARTITIONS.value]:
        self.project.logging.critical("Partitions section is not defined firmware partitions")
        missing_configuration_found = True
      else:
        # Device type must be defined for bank 0
        if not Key.DEVICE_TYPE.value in self.project.firmware[Key.RESILIENCE.value]\
                                                             [Key.PARTITIONS.value]\
                                                             [Key.BANK_0.value]:
          self.project.logging.critical("Device type for bank 0 is not defined in partitions")
          missing_configuration_found = True

        # Device number must be defined for bank 0
        if not Key.DEVICE_NUMBER_UBOOT.value in self.project.firmware[Key.RESILIENCE.value]\
                                                                     [Key.PARTITIONS.value]\
                                                                     [Key.BANK_0.value]:
          self.project.logging.critical("u-boot device number for bank 0 is not defined")
          missing_configuration_found = True

        # Device number must be defined for bank 0
        if not Key.DEVICE_NUMBER_LINUX.value in self.project.firmware[Key.RESILIENCE.value]\
                                                                     [Key.PARTITIONS.value]\
                                                                     [Key.BANK_0.value]:
          self.project.logging.critical("Linux device number for bank 0 is not defined")
          missing_configuration_found = True

        # Device partition must be defined for bank 0
        if not Key.PARTITION.value in self.project.firmware[Key.RESILIENCE.value]\
                                                           [Key.PARTITIONS.value][Key.BANK_0.value]:
          self.project.logging.critical("Device partition for bank 0 is not defined in partitions")
          missing_configuration_found = True

      # Check if dual banks are activated, and bank_1 is defined
      if Key.DUAL_BANKS.value in self.project.firmware[Key.RESILIENCE.value] and \
                                 self.project.firmware[Key.RESILIENCE.value][Key.DUAL_BANKS.value]:
        # If dual bank is activated, then bank 1 must be defined
        if not Key.BANK_1.value in self.project.firmware[Key.RESILIENCE.value]\
                                                        [Key.PARTITIONS.value]:
          self.project.logging.critical("Dual bank is activated, but bank 1 is not defined in the "
                                        "partitions section")
          missing_configuration_found = True
        else:
          # Device type must be defined for bank 1
          if not Key.DEVICE_TYPE.value in self.project.firmware[Key.RESILIENCE.value]\
                                                               [Key.PARTITIONS.value]\
                                                               [Key.BANK_1.value]:
            self.project.logging.critical("Device type for bank 1 is not defined in partitions")
            missing_configuration_found = True

          # Device number must be defined for bank 1
          if not Key.DEVICE_NUMBER_UBOOT.value in self.project.firmware[Key.RESILIENCE.value]\
                                                                 [Key.PARTITIONS.value]\
                                                                 [Key.BANK_1.value]:
            self.project.logging.critical("u-boot device number for bank 1 is not defined")
            missing_configuration_found = True

          # Device number must be defined for bank 1
          if not Key.DEVICE_NUMBER_LINUX.value in self.project.firmware[Key.RESILIENCE.value]\
                                                                       [Key.PARTITIONS.value]\
                                                                       [Key.BANK_1.value]:
            self.project.logging.critical("Linux device number for bank 1 is not defined")
            missing_configuration_found = True

          # Device partition must be defined for bank 1
          if not Key.PARTITION.value in self.project.firmware[Key.RESILIENCE.value]\
                                                             [Key.PARTITIONS.value]\
                                                             [Key.BANK_1.value]:
            self.project.logging.critical("Device partition for bank 1 is not defined")
            missing_configuration_found = True

      # Check if dual banks are activated, and bank_1 is defined
      if Key.RESCUE_IMAGE.value in self.project.firmware[Key.RESILIENCE.value] and \
                                   self.project.firmware[Key.RESILIENCE.value]\
                                                        [Key.RESCUE_IMAGE.value]:
        # If dual bank is activated, then bank 1 must be defined
        if not Key.RESCUE.value in self.project.firmware[Key.RESILIENCE.value]\
                                                        [Key.PARTITIONS.value]:
          self.project.logging.critical("Rescue image is activated, but rescue is not"
                                        " defined in the partitions section")
          missing_configuration_found = True
        else:
          # Device type must be defined for rescue bank
          if not Key.DEVICE_TYPE.value in self.project.firmware[Key.RESILIENCE.value]\
                                                               [Key.PARTITIONS.value]\
                                                               [Key.RESCUE.value]:
            self.project.logging.critical("Device type for rescue is not defined")
            missing_configuration_found = True

          # Device number must be defined for rescue bank
          if not Key.DEVICE_NUMBER_UBOOT.value in self.project.firmware[Key.RESILIENCE.value]\
                                                                       [Key.PARTITIONS.value]\
                                                                       [Key.RESCUE.value]:
            self.project.logging.critical("u-boot device number for rescue is not defined")
            missing_configuration_found = True

          # Device number must be defined for rescue bank
          if not Key.DEVICE_NUMBER_LINUX.value in self.project.firmware[Key.RESILIENCE.value]\
                                                                       [Key.PARTITIONS.value]\
                                                                       [Key.RESCUE.value]:
            self.project.logging.critical("Linux device number for rescue is not defined")
            missing_configuration_found = True

          # Device partition must be defined for rescue bank
          if not Key.PARTITION.value in self.project.firmware[Key.RESILIENCE.value]\
                                                             [Key.PARTITIONS.value]\
                                                             [Key.RESCUE.value]:
            self.project.logging.critical("Device partition for rescue is not defined")
            missing_configuration_found = True

      # Check if dual banks are activated, and bank_1 is defined
      if Key.UPDATE_PARTITION.value in self.project.firmware[Key.RESILIENCE.value] and \
                                       self.project.firmware[Key.RESILIENCE.value]\
                                                            [Key.UPDATE_PARTITION.value]:
        # If dual bank is activated, then bank 1 must be defined
        if not Key.UPDATE.value in self.project.firmware[Key.RESILIENCE.value]\
                                                        [Key.PARTITIONS.value]:
          self.project.logging.critical("Update partition is activated, but update is not"
                                        " defined in the partitions section")
          missing_configuration_found = True
        else:
          # Device type must be defined for update bank
          if not Key.DEVICE_TYPE.value in self.project.firmware[Key.RESILIENCE.value]\
                                                               [Key.PARTITIONS.value]\
                                                               [Key.UPDATE.value]:
            self.project.logging.critical("Device type for update is not defined")
            missing_configuration_found = True

          # Device number must be defined for update bank
          if not Key.DEVICE_NUMBER_UBOOT.value in self.project.firmware[Key.RESILIENCE.value]\
                                                                       [Key.PARTITIONS.value]\
                                                                       [Key.UPDATE.value]:
            self.project.logging.critical("u-boot device number for update is not defined")
            missing_configuration_found = True

          # Device number must be defined for update bank
          if not Key.DEVICE_NUMBER_LINUX.value in self.project.firmware[Key.RESILIENCE.value]\
                                                                       [Key.PARTITIONS.value]\
                                                                       [Key.UPDATE.value]:
            self.project.logging.critical("Linux device number for update is not defined")
            missing_configuration_found = True

          # Device partition must be defined for update bank
          if not Key.PARTITION.value in self.project.firmware[Key.RESILIENCE.value]\
                                                             [Key.PARTITIONS.value]\
                                                             [Key.UPDATE.value]:
            self.project.logging.critical("Device partition for update is not defined")
            missing_configuration_found = True

    # Is there any missing information ?
    if missing_configuration_found:
      self.project.logging.critical("Some information are missing please fix configuration files.")
      self.project.logging.critical("Aborting.")
      exit(1)


  # -------------------------------------------------------------------------
  #
  # generate_bootscript
  #
  # -------------------------------------------------------------------------
  def generate_bootscript(self, target):
    """This method generate the bootscript, either for rootfs or firmware
    mode. target is the path under which the file file be generated. target
    is a directory. The filename will be boot.scr.
    """

    # Check if we have to generate a bootscript in the image
    if Key.GENERATE_BOOTSCR.value in self.project.image[Key.CONTENT.value] and \
       not self.project.image[Key.CONTENT.value][Key.GENERATE_BOOTSCR.value]:
      # Generation is deactivated, just log it
      logging.debug("boot.scr generation was deactivated by configuration")
    else:
      # Generate the board specific boot script filename
      script = "../buildsystem/bootscripts/"
      script += self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value][0]\
                                    [Key.BOARD.value]
      script += ".boot."

      if self.project.is_image_content_rootfs():
        script += "rootfs"
      else:
        script += "firmware"

      # Finally concatenate file extension
      script += ".scr"


    # Test the specific script does not existe replace file path to use with the generic script filename
      if not os.path.isfile(script):
        # Board specific bootscript template does not exist, use the generic script instead
        logging.info("The board specific boot script (" + script + ") does not exist. Using the generic script to boot")
        script = "../buildsystem/bootscripts/generic-board.boot."
        if self.project.is_image_content_rootfs():
          script += "rootfs"
        else:
          script += "firmware"

        # finally concatenate file extension
        script += ".scr"

      # Create a temp file in with the script template is copied in text format. Then we do
      # variables expansion, before generating the binary script into the target file system.
      output_file = tempfile.mktemp()
      file_util.copy_file(script, output_file)
      logging.debug("Using bootscript template : " + script + " instanciated into " + output_file)

      # Replace the generation date, the dft version, the filesystem
      filesys = self.project.image[Key.DEVICES.value][Key.PARTITIONS.value][0]\
                                  [Key.FILESYSTEM.value].lower()
      timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

      command = 'sed -i -e "s/__FILESYSTEM_TYPE__/' + filesys + '/g" '
      command += ' -e "s/__DFT_VERSION__/' + release.__version__ + '/g" '
      command += ' -e "s/__GENERATION_DATE__/' + timestamp + '/g" '


      # ----- These keys have to be processed only in case of firmware -----------------------------
      if self.project.is_image_content_firmware():
        # ----- Replace DUAL_BANKS FLAG ------------------------------------------------------------
        command += ' -e "s/__DFT_DUAL_BANKS__/'
        if Key.DUAL_BANKS.value in self.project.firmware[Key.RESILIENCE.value] and \
                                   self.project.firmware[Key.RESILIENCE.value]\
                                                        [Key.DUAL_BANKS.value]:
          # Flag is activate
          command += '1'
        else:
          # Flag is deactivated
          command += '0'

        # Complete the sed command generation
        command += '/g" '

        # ----- Replace DUAL_BANKS FLAG ------------------------------------------------------------
        command += ' -e "s/__DFT_USE_RESCUE__/'
        if Key.RESCUE_IMAGE.value in self.project.firmware[Key.RESILIENCE.value] and \
                                     self.project.firmware[Key.RESILIENCE.value]\
                                                          [Key.RESCUE_IMAGE.value]:
          # Flag is activated
          command += '1'
        else:
          # Flag is deactivated
          command += '0'

        # Complete the sed command generation
        command += '/g" '

        # ----- Replace STORAGE_DEFAULT_BANK  ------------------------------------------------------
        # defqult bank at first boot is alzays bank_0
        command += ' -e "s/__DFT_STORAGE_DEFAULT_BANK__/0/g" '

        # ----- Replace STORAGE_DEFAULT_TYPE  ------------------------------------------------------
        command += ' -e "s/__DFT_STORAGE_DEFAULT_TYPE__/'
        command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                            [Key.BANK_0.value][Key.DEVICE_TYPE.value])
        command += '/g" '

        # ----- Replace STORAGE_DEFAULT_DEVICE_UBOOT  ----------------------------------------------
        # Linux and uboot devices have separated values since the kernel can change numbering once
        # booting. This happens on i.MX^
        command += ' -e "s/__DFT_STORAGE_DEFAULT_DEVICE_UBOOT__/'
        command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                            [Key.BANK_0.value][Key.DEVICE_NUMBER_UBOOT.value])
        command += '/g" '

        # ----- Replace STORAGE_DEFAULT_DEVICE_LINUX  ----------------------------------------------
        command += ' -e "s/__DFT_STORAGE_DEFAULT_DEVICE_LINUX__/'
        command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                            [Key.BANK_0.value][Key.DEVICE_NUMBER_LINUX.value])
        command += '/g" '

        # ----- Replace STORAGE_DEFAULT_PARTITION  -------------------------------------------------
        command += ' -e "s/__DFT_STORAGE_DEFAULT_PARTITION__/'
        command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                            [Key.BANK_0.value][Key.PARTITION.value])
        command += '/g" '

        # ----- Replace DFT_BANK0_TYPE  ------------------------------------------------------------
        command += ' -e "s/__DFT_BANK0_TYPE__/'
        command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                            [Key.BANK_0.value][Key.DEVICE_TYPE.value])
        command += '/g" '

        # ----- Replace DFT_BANK0_DEVICE_UBOOT  ----------------------------------------------------
        command += ' -e "s/__DFT_BANK0_DEVICE_UBOOT__/'
        command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                            [Key.BANK_0.value][Key.DEVICE_NUMBER_UBOOT.value])
        command += '/g" '
        # ----- Replace DFT_BANK0_DEVICE_LINUX  ----------------------------------------------------
        command += ' -e "s/__DFT_BANK0_DEVICE_LINUX__/'
        command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                            [Key.BANK_0.value][Key.DEVICE_NUMBER_LINUX.value])
        command += '/g" '

        # ----- Replace DFT_BANK0_PARTITION  -------------------------------------------------------
        command += ' -e "s/__DFT_BANK0_PARTITION__/'
        command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                            [Key.BANK_0.value][Key.PARTITION.value])
        command += '/g" '

        # Generate sed commands only if option is activated
        if Key.DUAL_BANKS.value in self.project.firmware[Key.RESILIENCE.value] and \
                             self.project.firmware[Key.RESILIENCE.value][Key.DUAL_BANKS.value]:
          # ----- Replace DFT_BANK1_TYPE  ----------------------------------------------------------
          command += ' -e "s/__DFT_BANK1_TYPE__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.BANK_1.value][Key.DEVICE_TYPE.value])
          command += '/g" '

          # ----- Replace DFT_BANK1_DEVICE_BOOT  ---------------------------------------------------
          command += ' -e "s/__DFT_BANK1_DEVICE_UBOOT__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.BANK_1.value][Key.DEVICE_NUMBER_UBOOT.value])
          command += '/g" '

          # ----- Replace DFT_BANK1_DEVICE_LINNUX --------------------------------------------------
          command += ' -e "s/__DFT_BANK1_DEVICE_LINUX_/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.BANK_1.value][Key.DEVICE_NUMBER_LINUX.value])
          command += '/g" '

          # ----- Replace DFT_BANK1_PARTITION  -----------------------------------------------------
          command += ' -e "s/__DFT_BANK1_PARTITION__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.BANK_1.value][Key.PARTITION.value])
          command += '/g" '

        # Generate sed commands only if option is activated
        if Key.RESCUE_IMAGE.value in self.project.firmware[Key.RESILIENCE.value] and \
                             self.project.firmware[Key.RESILIENCE.value][Key.RESCUE_IMAGE.value]:
          # ----- Replace DFT_RESCUE_TYPE  ---------------------------------------------------------
          command += ' -e "s/__DFT_RESCUE_TYPE__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.RESCUE.value][Key.DEVICE_TYPE.value])
          command += '/g" '

          # ----- Replace DFT_RESCUE_DEVICE_UBOOT  -------------------------------------------------
          command += ' -e "s/__DFT_RESCUE_DEVICE_UBOOT__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.RESCUE.value][Key.DEVICE_NUMBER_UBOOT.value])
          command += '/g" '

          # ----- Replace DFT_RESCUE_DEVICE_LINUX  -------------------------------------------------
          command += ' -e "s/__DFT_RESCUE_DEVICE_LINUX__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.RESCUE.value][Key.DEVICE_NUMBER_LINUX.value])
          command += '/g" '

          # ----- Replace DFT_RESCUE_PARTITION  ----------------------------------------------------
          command += ' -e "s/__DFT_RESCUE_PARTITION__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.RESCUE.value][Key.PARTITION.value])
          command += '/g" '

        # Generate sed commands only if option is activated
        if Key.UPDATE_PARTITION.value in self.project.firmware[Key.RESILIENCE.value] and \
                             self.project.firmware[Key.RESILIENCE.value]\
                                                  [Key.UPDATE_PARTITION.value]:
          # ----- Replace DFT_UPDATE_TYPE  ---------------------------------------------------------
          command += ' -e "s/__DFT_UPDATE_TYPE__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.UPDATE.value][Key.DEVICE_TYPE.value])
          command += '/g" '

          # ----- Replace DFT_UPDATE_DEVICE_UBOOT --------------------------------------------------
          command += ' -e "s/__DFT_UPDATE_DEVICE__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.UPDATE.value][Key.DEVICE_NUMBER_UBOOT.value])
          command += '/g" '

          # ----- Replace DFT_UPDATE_DEVICE_LINUX  -------------------------------------------------
          command += ' -e "s/__DFT_UPDATE_DEVICE_LINUX__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.UPDATE.value][Key.DEVICE_NUMBER_LINUX.value])
          command += '/g" '

          # ----- Replace DFT_UPDATE_PARTITION  ----------------------------------------------------
          command += ' -e "s/__DFT_UPDATE_PARTITION__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.UPDATE.value][Key.PARTITION.value])
          command += '/g" '

        # Generate sed commands only if option is activated. Failover is needed only for dual bank
        # or rescue
        if (Key.DUAL_BANKS.value in self.project.firmware[Key.RESILIENCE.value] and \
                                    self.project.firmware[Key.RESILIENCE.value]\
                                                         [Key.DUAL_BANKS.value]) or \
           (Key.RESCUE_IMAGE.value in self.project.firmware[Key.RESILIENCE.value] and \
                                      self.project.firmware[Key.RESILIENCE.value]\
                                                           [Key.RESCUE_IMAGE]):
          # ----- Replace DFT_FAILOVER_TYPE  -------------------------------------------------------
          command += ' -e "s/__DFT_FAILOVER_TYPE__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.FAILOVER.value][Key.DEVICE_TYPE.value])
          command += '/g" '

          # ----- Replace DFT_FAILOVER_DEVICE_LINUX  -----------------------------------------------
          command += ' -e "s/__DFT_FAILOVER_DEVICE_LINUX__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.FAILOVER.value][Key.DEVICE_NUMBER_LINUX.value])
          command += '/g" '

          # ----- Replace DFT_FAILOVER_DEVICE  -----------------------------------------------------
          command += ' -e "s/__DFT_FAILOVER_DEVICE_UBOOT__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.FAILOVER.value][Key.DEVICE_NUMBER_UBOOT.value])
          command += '/g" '

          # ----- Replace DFT_FAILOVER_PARTITION  --------------------------------------------------
          command += ' -e "s/__DFT_FAILOVER_PARTITION__/'
          command += str(self.project.firmware[Key.RESILIENCE.value][Key.PARTITIONS.value]\
                                              [Key.FAILOVER.value][Key.PARTITION.value])
          command += '/g" '

     # Command has been generated, let's execute the replacement with sed
      command += " " + output_file
      self.execute_command(command)

      # Generate the boot script on the fly with macro expension
      arch = self.project.get_mkimage_arch()
      command = "mkimage -A " + arch + " -C none -T script -d " + output_file
      command += " " + target + "/boot.scr"
      self.execute_command(command)

      # Remove temp file once binary boot.scr has been generated
      os.remove(output_file)

      # Copy kernel_cmdline_extra_parameters templates to /boot
      os.makedirs(target + "/boot/", exist_ok=True)
      src = self.project.get_dft_base() + "/cli/scripts/kernel_cmdline_extra_parameters.txt"
      dest = target + "/boot/kernel_cmdline_extra_parameters.txt"
      self.project.logging.debug("Copying " + src + " to " + dest)
      shutil.copyfile(src, dest)

      # Copy uEnv.txt templates to /boot
      src = self.project.get_dft_base() + "/cli/scripts/uEnv.txt"
      dest = target + "/boot/uEnv.txt"
      self.project.logging.debug("Copying " + src + " to " + dest)
      shutil.copyfile(src, dest)
