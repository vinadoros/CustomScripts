#!/usr/bin/env python3
"""Create an Ubuntu Live USB."""

# Python includes.
import argparse
import os
import shlex
import signal
import stat
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]


######### Begin Functions #########
def docker_destroy(name):
    """Destroy the named docker container"""
    print("Destroying docker container {0}.".format(name))
    subprocess.run("docker stop {0}".format(name), shell=True)
    subprocess.run("docker rm {0}".format(name), shell=True)
    return


def docker_runcmd(cmd, chk=True):
    """Run a command in the named docker container"""
    subprocess.run(["docker", "exec", "-it", "--privileged", docker_name] + shlex.split(cmd), check=chk)
    # subprocess.run("docker exec -it --privileged {0} {1}".format(name, cmd), shell=True)
    return


def signal_handler(sig, frame):
    """Handle a SIGINT signal."""
    docker_destroy(docker_name)
    print('Exiting due to SIGINT.')
    sys.exit(1)
######### End Functions #########


# Get arguments
parser = argparse.ArgumentParser(description='Build LiveCD.')
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-b", "--blockdevice", help='Block Device to use.')
parser.add_argument("-r", "--release", help='Release of LiveUSB', default="bionic")

# Save arguments.
args = parser.parse_args()

# Exit if not root.
CFunc.is_root(True)

# Process variables
print("Release: {0}".format(args.release))
if args.blockdevice is not None and os.path.exists(args.blockdevice) is True and stat.S_ISBLK(os.stat(args.blockdevice).st_mode) is True:
    blockdevice = args.blockdevice
    print("\nWARNING: All information on {0} will be deleted!!!".format(blockdevice))
    print("Some information about the device:")
    subprocess.run("lsblk {0}".format(blockdevice), shell=True)
else:
    sys.exit("\nERROR, no block device detected. Please specify one.")

if args.noprompt is False:
    input("Press Enter to continue.")

# Attach signal handler.
signal.signal(signal.SIGINT, signal_handler)

######### Begin Code #########

# Unmount all partitions on the block device, if they are mounted.

# Create the docker container.
docker_name = "ubuusb"
docker_image = "ubuntu:latest"
docker_options = '-v /opt/CustomScripts:/opt/CustomScripts -v "{0}":"{0}" -e DEBIAN_FRONTEND=noninteractive'.format(blockdevice)
docker_destroy(docker_name)
print("Creating docker container {0}.".format(docker_name))
subprocess.run("docker run -dt --privileged --name {0} {1} {2} bash".format(docker_name, docker_options, docker_image), shell=True)
try:
    # Provision the docker container with the correct utilities.
    docker_runcmd("apt-get update")
    docker_runcmd("apt-get install -y debootstrap gdisk util-linux dosfstools e2fsprogs")

    print("\n--- Disk layout for {0} before formatting. ---".format(blockdevice))
    docker_runcmd("gdisk -l {0}".format(blockdevice))
    # Destroy current disk layout.
    docker_runcmd("sgdisk -Z {0}".format(blockdevice))
    docker_runcmd('dd if=/dev/zero of="{0}" bs=1M count=4 conv=notrunc'.format(blockdevice))
    # Create new partition table.
    docker_runcmd("""
    sgdisk --clear \
        --new 1::+1M --typecode=1:ef02 --change-name=1:'BIOS boot partition' \
        --new 2::+50M --typecode=2:ef00 --change-name=2:'EFI System' \
        --new 3::-0 --typecode=3:8300 --change-name=3:'Linux root filesystem' {0}""".format(blockdevice))
    # Format partitions.
    docker_runcmd("mkfs.fat -F32 -n efi {0}2".format(blockdevice))
    docker_runcmd("mkfs.ext4 -F -L 'usbubuntu' {0}3".format(blockdevice))
    print("\n--- Disk layout for {0} after formatting. ---".format(blockdevice))
    docker_runcmd("gdisk -l {0}".format(blockdevice))

    # Mount new disks
    print("Mounting disks.")
    mountfolder_root = os.path.join(os.sep, "var", "tmp", "mountfld")
    mountfolder_efi = os.path.join(os.sep, "var", "tmp", "mountfld", "boot", "efi")
    blockdevice_root = "{0}3".format(blockdevice)
    blockdevice_efi = "{0}2".format(blockdevice)
    docker_runcmd("mkdir -p {0}".format(mountfolder_root))
    docker_runcmd("mount {0} {1}".format(blockdevice_root, mountfolder_root))
    docker_runcmd("mkdir -p {0}".format(mountfolder_efi))
    docker_runcmd("mount {0} {1}".format(blockdevice_efi, mountfolder_efi))
    # Run debootstrap
    print("\nRunning debootstrap.")
    docker_runcmd("debootstrap {0} {1}".format(args.release, mountfolder_root))
    # Install kernel and bootloader

    # Unmount the disks
    print("Unmounting disks.")
    docker_runcmd("umount -R {0}; umount -Rl {0}; umount -Rf {0}".format(mountfolder_root), chk=False)
# Cleanup the docker container
finally:
    docker_destroy(docker_name)

print("\nScript ended successfully!")
