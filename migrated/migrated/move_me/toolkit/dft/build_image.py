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
# Copyright 2016 DFT project (http://www.debianfirmwaretoolkit.org).
# All rights reserved. Use is subject to license terms.
#
# Debian Firmware Toolkit is the new name of Linux Firmware From Scratch
# Copyright 2014 LFFS project (http://www.linuxfirmwarefromscratch.org).
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
import parted
from dft.cli_command import CliCommand
from dft.model import Key

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
    self.install_image_content()

    # Install the boot (either grub or uboot)
    self.install_boot()

    # Umount the image and release the loopback deice
    self.umount_image()

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
    # self.umount_image()

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

    # Check that there is an image configuration file first
    if self.project.image is None:
      self.project.logging.critical("The image configuration file is not defined in project file")
      exit(1)

    # Check that the devices is available from the configuration file
    if Key.DEVICES.value not in self.project.image:
      self.project.logging.critical("The image devices is not defined in configuration file")
      exit(1)

    # Check that the filename is available from the devices section in the configuration file
    if Key.FILENAME.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.critical("The filename is not defined in the configuration file")
      exit(1)

    # Continue to check everything needed is defined
    if Key.SIZE.value not in self.project.image[Key.DEVICES.value]:
      self.project.logging.critical("Image size is not defined in the devices section. Aborting.")
      exit(1)
    else:
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

      # Check that there is a partition table inthe configuration file. If not it will fail later,
      # thus better fail now.
      if Key.PARTITIONS.value not in self.project.image[Key.DEVICES.value]:
        self.project.logging.error("Partition table is not defined, nothing to do. Aborting")
        exit(1)

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
          if part_filesystem not in  parted.fileSystemType:
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

        # Compute the geometry for this device
        geometry = parted.Geometry(start=part_start_sector, length=sector_count, device=device)

        # Create the arted filesystem object
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
  # install_image_content
  #
  # -------------------------------------------------------------------------
  def install_image_content(self):
    """This method installs the content from the generated rootfs or firmware
    into the partition previously created and formwated.

    The method execute several iterations of the partitions lists from the
    device entry.

    . First iteration compute the list of partition to mount, sort them and
      push mounts to a list
    . Second iteration is on the list of mounts, remove mount points one by
      one, creates, under a temporary directory, the path need to execute the
      mount command, then do the mount and push the path to the list of
      directories to umount
    . Copy either the rootfs or the firmware to the mounted partitions
    . Iterate the umount list and cleanup things
    """

    # Output current task to logs
    logging.info("Installating image content")

    # Defines a partition counter. Starts at zero and is incremented at each iteration
    # beginning. It means first partition is 1.
    part_index = 0

    # Get a temporary directory used as root for image mounting
    image_mount_root = tempfile.mkdtemp(dir=self.project.get_image_directory())

    # Define the list of path to mount and umount which is are empty list at start
    # We need these list to sort path before mounting to prevent false order of declaration
    path_to_mount = []
    path_to_umount = []
    device_to_fsck = []

    # Nox iterate the partitiontables and create them
    for partition in self.project.image[Key.DEVICES.value][Key.PARTITIONS.value]:

      # Increase partition index
      part_index += 1

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
        device_to_fsck.append(path["device"])

    #
    # All the partitions have been identified, now let's sot them in mount order and do mount
    #

    # Sort the list usingpath as the key, in reverse order sinc path will be popped
    path_to_mount.sort(key=lambda p: p["path"], reverse=True)
    while len(path_to_mount) > 0:
      # Get the next item to mount
      path = path_to_mount.pop()

      # Create the local mount point if needed
      command = 'mkdir -p "' + path["path"] + '"'
      self.execute_command(command)

      # Generate the ount command
      command = 'mount "' + path["device"] + '" "' + path["path"] + '"'
      self.execute_command(command)

      # Mount was successful, thus push the path in the umount list
      path_to_umount.append(path["path"])

    #
    # All the partitions have been mounted now let's copy the data
    #

    # Defines the default behavior, to copy the rootfs. True means rootfs, thus false means firmware
    copy_rootfs = True

    # Test if we should copy the firmware or the rootfs
    if not Key.CONTENT.value in self.project.image:
      logging.info("No content section in image configuration file. Defaulting to copy rootfs")
    else:
      if self.project.image[Key.CONTENT.value] is None or \
         not Key.TYPE.value in self.project.image[Key.CONTENT.value]:
        logging.info("No type defined in content section of image configuration file. Defaulting " +
                     " to copy rootfs")
      else:
        logging.debug("Image content : " + self.project.image[Key.CONTENT.value][Key.TYPE.value])
        if self.project.image[Key.CONTENT.value][Key.TYPE.value].lower() == "rootfs":
          copy_rootfs = True
        elif self.project.image[Key.CONTENT.value][Key.TYPE.value].lower() == "firmware":
          copy_rootfs = False
        else:
          logging.critical("Unknown image content : " + self.project.image[Key.CONTENT.value]\
                           [Key.TYPE.value] + ". Aborting.")

          # Remove the temporary mount point before exiting
          shutil.rmtree(image_mount_root)

          # And now exit program
          exit(1)

    # Switch between firmware and rootfs copy
    if copy_rootfs:
      # Iterate the list of files in the rootfs and copy them to image
      for copy_target in os.listdir(self.project.get_rootfs_mountpoint()):
        copy_source_path = os.path.join(self.project.get_rootfs_mountpoint(), copy_target)
        copy_target_path = os.path.join(image_mount_root, copy_target)
        command = "cp -fra " + copy_source_path + " " + copy_target_path
        self.execute_command(command)
    else:
      logging.error("Firmware copy is not yet available. Doing nothing")

    #
    # Data have been copied, lets unmount all the partitions before teardown the loopback
    #

    # First let's sort the list to umount in the same order as the fs have been mounted
    # (never umout /var before /var/log). Sort is in normal order since we pop the list
    path_to_umount.sort()
    while len(path_to_umount) > 0:
      # Generate the uount command
      command = 'umount "' + path_to_umount.pop() + '"'
      self.execute_command(command)

    # Remove the temporary mount point before exiting
    shutil.rmtree(image_mount_root)

    # Content have been copied and partition umount, now let's control the filesystems
    # It is done by calling fsck on evey path from the device_to_fsck list
    while len(device_to_fsck) > 0:
      # Generate the umount command
      command = 'fsck -f -y ' + device_to_fsck.pop()
      self.execute_command(command)



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

    # Output current task to logs
    logging.info("Installing the boot (uboot or grub)")

    # Check if a BSP section is defined. It should be, or we certainly have failed before anyways
    if Key.BSP.value in self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value][0]:

      # And that it contains a uboot section. Otherwise it may be a grub section
      if Key.UBOOT.value in self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value]\
                                              [0][Key.BSP.value]:

        # Iterate the list of actions. An action is a dd call to copy binary data to the image
        for action in self.project.project[Key.PROJECT_DEFINITION.value][Key.TARGETS.value]\
                                          [0][Key.BSP.value][Key.UBOOT.value]:

          # Check that the source is defined. Otherwise it will not be able to call dd
          if Key.SOURCE.value not in action:
            logging.critical("No source defined in the uboot installation action. Aborting.")
            exit(1)
          else:
            # Copy the source
            source = action[Key.SOURCE.value]

            # If the source is an absolute path, then use it "as is", otherwise prefix with
            # the bsp root
            if not os.path.isabs(source):
              source = self.project.get_bsp_base() + "/uboot/" + source

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
  # umount_image
  #
  # -------------------------------------------------------------------------
  def umount_image(self):
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

    # Defines a partition counter. Starts at zerp and is incremented at each iteration
    # beginning. It means first partition is 1.
    part_index = 0

    # Nox iterate the partitiontables and create them
    for partition in self.project.image[Key.DEVICES.value][Key.PARTITIONS.value]:

      # Increase partition index
      part_index += 1

      # Retrieve the partition format flag
      if Key.FORMAT.value not in partition:
        self.project.logging.debug("File system format flag is not defined. Defaulting to True")
        part_format = True
      else:
        part_format = partition[Key.FORMAT.value]
        self.project.logging.debug("File system format flag => '" + str(part_format) + "'")

      # Check if the flag is true, if not there is nothing to do
      if not part_format:
        self.project.logging.debug("The format flag is deactivated for martition " + part_index)
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
        elif part_filesystem == "fat32":
          format_tool = "mkfs.vfat"
        elif part_filesystem == "linux-swap(v0)" or part_filesystem == "linux-swap(v1)":
          format_tool = "mkswap"

        # Creation du file fystem sur a prtition
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

    # Defines a partition counter. Starts at zero and is incremented at each iteration
    # beginning. It means first partition is 1.
    part_index = 0

    # Now iterate once again the partition tables to set labels
    for partition in self.project.image[Key.DEVICES.value][Key.PARTITIONS.value]:

      # Increase partition index
      part_index += 1

      # Retrieve the partition name, and process only if there is a name
      if Key.NAME.value in partition:
        part_name = partition[Key.NAME.value]

        # Retrieve the partition file system type. It should be defined or we can't label it
        if Key.FILESYSTEM.value not in partition:
          self.project.logging.error("Partition label is defined but there is no filesystem set \
                                     for partition " + part_index)
        else:
          part_filesystem = partition[Key.FILESYSTEM.value].lower()

          # Retrieve the partition format flag. It should be formatted or we can't label it.
          if Key.FORMAT.value in partition and not partition[Key.FORMAT.value]:
            self.project.logging.error("Partition label is defined, but partition " + part_index + \
                                       " is not formatted")
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
                                         part_index + " with file system " + part_filesystem)



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
    elif compression_tool == "lzma":
      compression_tool = "/usr/bin/env xz -z --format=lzma"
      compression_suffix = ".lzma"
    # Check for xz format
    elif compression_tool == "xz":
      compression_tool = "/usr/bin/env xz -z"
      compression_suffix = ".xz"
    # Check for bzip2 format
    elif compression_tool == "bzip2":
      compression_tool = "/usr/bin/env bzip2"
      compression_suffix = ".bz2"
    # Check for gzip format
    elif compression_tool == "gzip":
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
    self.umount_image()

    # Finally umount all the chrooted environment
    self.teardown_chrooted_environment()
