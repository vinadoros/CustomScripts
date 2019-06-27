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
    subprocess.run(["docker", "stop", name])
    subprocess.run(["docker", "rm", name])


def docker_runcmd(cmd, chk=True):
    """Run a command in the named docker container"""
    subprocess.run(["docker", "exec", "-it", "--privileged", docker_name] + shlex.split(cmd), check=chk)
    # subprocess.run("docker exec -it --privileged {0} {1}".format(name, cmd), shell=True)


def chroot_runcmd(cmd, chk=True):
    """Run a command in the chroot in the docker container"""
    docker_runcmd("/opt/CustomScripts/zch.py -c '{0}' {1}".format(cmd, mountfolder_root), chk=chk)


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
    subprocess.run(["lsblk", blockdevice])
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
    docker_runcmd("apt-get install -y python3 debootstrap gdisk util-linux dosfstools e2fsprogs")

    rootdiskid = "usbubuntu"
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
    docker_runcmd("mkfs.ext4 -F -L '{1}' {0}3".format(blockdevice, rootdiskid))
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
    # docker_runcmd("debootstrap {0} {1}".format(args.release, mountfolder_root))
    # Install kernel and bootloader
    chroot_runcmd("apt-get install -y linux-image-generic grub-pc grub-efi-amd64-bin")
    chroot_runcmd('grub-install --modules="ext2 part_gpt" {0}'.format(blockdevice))
    chroot_runcmd("update-grub")
    chroot_runcmd("grub-install --target=x86_64-efi --boot-directory=/boot --efi-directory=/boot/efi --bootloader-id={0} --recheck --removable".format(rootdiskid))
    # Create and copy grub.cfg
    grubcfg_text = """search --label "{0}" --set prefix
configfile ($prefix)/boot/grub/grub.cfg""".format(rootdiskid)
    grubcfg_path = os.path.join(os.sep, "var", "tmp", "grub.cfg")
    with open(grubcfg_path, 'w') as fd:
        fd.write(grubcfg_text)
    subprocess.run(["docker", "cp", grubcfg_path, "{0}:/grub.cfg".format(docker_name)])
    if os.path.isfile(grubcfg_path):
        os.remove(grubcfg_path)
    chroot_runcmd("mv /grub.cfg /boot/efi/EFI/BOOT/grub.cfg")
    # Install extra software
    chroot_runcmd("apt-get install -y --no-install-recommends software-properties-common")
    chroot_runcmd("add-apt-repository main")
    chroot_runcmd("add-apt-repository restricted")
    chroot_runcmd("add-apt-repository universe")
    chroot_runcmd("add-apt-repository multiverse")

    # Cleanup
    # Final initram generation
    chroot_runcmd("update-initramfs -u -k all")
    # Clean environment
    chroot_runcmd("apt-get purge -y locales")
    chroot_runcmd("apt-get clean")
    # From https://git.launchpad.net/livecd-rootfs/tree/live-build/ubuntu-core/hooks/10-remove-documentation.binary
    chroot_runcmd("find /usr/share/doc -depth -type f ! -name copyright|xargs rm -f", chk=False)
    chroot_runcmd("find /usr/share/doc -empty|xargs rmdir", chk=False)
    chroot_runcmd("find /usr/share/doc -type f -exec gzip -9 {} \;", chk=False)
    chroot_runcmd("""rm -rf /usr/share/man \
        /usr/share/groff \
        /usr/share/info \
        /usr/share/lintian \
        /usr/share/linda \
        /var/cache/man""")
    chroot_runcmd("find /var/lib/apt/lists/ -type f | xargs rm -f")
    chroot_runcmd("rm -f /var/cache/apt/*.bin")
    # Unmount the disks
    print("Unmounting disks.")
    # docker_runcmd("umount -R {0}".format(mountfolder_root), chk=False)
    # docker_runcmd("umount -Rl {0}".format(mountfolder_root), chk=False)
    # docker_runcmd("umount -Rf {0}".format(mountfolder_root), chk=False)
# Cleanup the docker container
finally:
    print("Cleaning up docker images.")
    docker_destroy(docker_name)

print("\nScript ended successfully!")
