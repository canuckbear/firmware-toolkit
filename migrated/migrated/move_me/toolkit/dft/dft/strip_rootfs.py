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
#
#

""" This modules implements the functionnalities used to strip a roootfs (or rootfs)
according to the rules defined in a Yaml configuration file. Stripping a rootfs is made
of removing files and packages.
"""

from cli_command import CliCommand

#
#    Class StripRootFS
#
class StripRootFS(CliCommand):
  """This class implements the methods needed to strip the base OS

  Stripping the base OS is the task to remove extra packages and files
  that should not be included inthe firmware. These files may come from
  different sources (istalled packages, manual creation, etc.)
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

    # Initialize a dictionnary to hold the list of installed packages
    self.installed_packages = {}

    # Flag to used to keep track of the need to uninstall APT in case wehad to install it
    self.need_to_strip_apt = False



  # -------------------------------------------------------------------------
  #
  # strip_rootfs
  #
  # -------------------------------------------------------------------------
  def strip_rootfs(self):
    """This method implement the business logic of rootfs stripping.

    It calls dedicated method for each step. The main steps are :
    . strip_packages      This step will remove each package marked as absent
    . strip_files         This step will remove each file marked as absent
    . empty_files         This step will truncate each file marked as empty
    . empty_directories   This step will remove content of each directory
                          marked as empty
    """

    # Check if we are working with foreign arch, then ...
    if self.use_qemu_static:
      # QEMU is used, and we have to install it into the target
      self.setup_qemu()

    # Check that there is a stripping definition
    if self.project.stripping_def is None:
      self.project.logging.info("The project has no stripping information defined")
      return

    #
    # Strip the packages
    #

    # Check that the stripping definition includes packages
    if "packages" in self.project.stripping_def:
      # Check that the stripping definition includes a status absent
      if "absent" in self.project.stripping_def["packages"]:
        # Retrieve the list of installed packages
        sudo_command = "LANG=C sudo chroot " + self.project.rootfs_mountpoint
        sudo_command += " dpkg -l | tail -n +6 | awk '{ print $2 }'"
        pkglist = self.execute_command(sudo_command)

        # Transform the binary outputinto text
        for binaryline in pkglist.splitlines():
          # Each fields is stored into a variable to easy manipulation and
          # simplify code. First get the array of words converted to UTF-8
          self.installed_packages[binaryline.decode('utf-8').split()[0]] = True

        # Iterate the list packages to remove
        for pkg in self.project.stripping_def["packages"]["absent"]:
          # If the package is installed
          if pkg in self.installed_packages:
            # First chck if we h&ve to add APT
            filepath = self.project.rootfs_mountpoint + "/usr/bin/apt-get"

            # Test if the binary exists
            if not os.path.isfile(filepath):
              # No thus install, and set the flag to mark it has to be removed in the end
              self.project.logging.debug("apt packag is needed for tripping, installing it")
              self.install_package("apt")
              self.need_to_strip_apt = True

            # Then remove the package since it is in the kill list !
            self.remove_package(pkg)
      else:
        self.project.logging.debug("The stripping definition does not include packages to remove")
    else:
      self.project.logging.debug("The stripping definition does not include packages section")

    # Package stripping is done, we no longer apt package (if we had to install it)
    # It is now time to remove it. It has to do done before files and directories stripping
    # In case the next stripping stages breaks APT
    if self.need_to_strip_apt == True:
      self.project.logging.debug("apt packag has been installed during stripping, now removing it")
      self.remove_package("apt")

    #
    # Strip the files
    #

    # Check that the stripping definition includes files
    if "files" in self.project.stripping_def:
      # Check that the stripping definition includes a status absent
      if "absent" in self.project.stripping_def["files"]:
        for working_file in self.project.stripping_def["files"]["absent"]:
          self.remove_file(working_file)
      else:
        self.project.logging.debug("The stripping definition does not include files to remove")

      # Check that the stripping definition includes a status empty
      if "empty" in self.project.stripping_def["files"]:
        for working_file in self.project.stripping_def["files"]["empty"]:
          self.empty_file(working_file)
      else:
        self.project.logging.debug("Stripping definition does not include files to truncate")

    else:
      self.project.logging.debug("Stripping definition does not include files section")

    #
    # Strip the directories
    #

    # Check that the stripping definition includes directories
    if "directories" in self.project.stripping_def:
      # Check that the stripping definition includes a status absent
      if "absent" in self.project.stripping_def["directories"]:
        for directory in self.project.stripping_def["directories"]["absent"]:
          self.remove_directory(directory)
      else:
        self.project.logging.debug("Stripping definition does not include directories to remove")

      # Check that the stripping definition includes a status empty
      if "empty" in self.project.stripping_def["directories"]:
        for directory in self.project.stripping_def["directories"]["empty"]:
          self.empty_directory(directory)
      else:
        self.project.logging.debug("The stripping definition does not include files to empty")

    else:
      self.project.logging.debug("The stripping definition does not include directories section")

    # Remove QEMU if it has been isntalled. It has to be done in the end
    # since some cleanup tasks could need QEMU
    if self.use_qemu_static:
      self.cleanup_qemu()

# Then strip the symlinks ??? check it is in unit test



  # -------------------------------------------------------------------------
  #
  # remove_file
  #
  # -------------------------------------------------------------------------
  def remove_file(self, target):
    """This method removes a file from the target rootfs.

    For safety reasons, this command is executed inside the chrooted
    environment and may need to have qemu installed.
    """

    self.project.logging.debug("Remove file : " + target)
    sudo_command = "sudo chroot " + self.project.rootfs_mountpoint
    sudo_command += " rm -f " + target
    self.execute_command(sudo_command)



  # -------------------------------------------------------------------------
  #
  # empty_file
  #
  # -------------------------------------------------------------------------
  def empty_file(self, target):
    """This method makes 'empty' a file from the target rootfs. The operation
    is a file truncate.

    For safety reasons, this command is executed inside the chrooted
    environment and may need to have qemu installed.
    """

    self.project.logging.debug("Empty file : " + target)

    # Test if the fileexist before trying to trucate it
    sudo_command = "sudo chroot " + self.project.rootfs_mountpoint
    sudo_command += " bash -c '[ -f " + target + " ] && truncate " + target
    sudo_command += " --size 0 || true'"
    self.execute_command(sudo_command)



  # -------------------------------------------------------------------------
  #
  # remove_directory
  #
  # -------------------------------------------------------------------------
  def remove_directory(self, target):
    """This method removes  a directory from the target rootfs.

    This operation also rmoves recursivly the directory content (thus you'd
    better not remove / ...).

    For safety reasons, this command is executed inside the chrooted
    environment and may need to have qemu installed.
    """

    self.project.logging.debug("Remove directory : " + target)
    sudo_command = "sudo chroot " + self.project.rootfs_mountpoint
    sudo_command += " rm -fr " + target
    self.execute_command(sudo_command)



  # -------------------------------------------------------------------------
  #
  # empty_directory
  #
  # -------------------------------------------------------------------------
  def empty_directory(self, target):
    """This method removes a dirctory content recursivly. Only files and
    symlinks are remove. The sub dirctories structure is not mdified.

    For safety reasons, this command is executed inside the chrooted
    environment and may need to have qemu installed.
    """

    self.project.logging.debug("Empty directory : " + target)
    sudo_command = "sudo chroot " + self.project.rootfs_mountpoint
    sudo_command += " bash -c '[ -d " + target + " ] && find " + target
    sudo_command += " -type f | xargs rm -f || true'"
    self.execute_command(sudo_command)
