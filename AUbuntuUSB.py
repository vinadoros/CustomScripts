#!/usr/bin/env python3
"""Create an Ubuntu Live USB."""

# Python includes.
import argparse
import os
import shlex
import signal
import shutil
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
    subprocess.run(["docker", "exec", "-i", "--privileged", docker_name] + shlex.split(cmd), check=chk)


def docker_chroot_runcmd(cmd, chk=True):
    """Run a command in the chroot in the docker container"""
    docker_runcmd("/opt/CustomScripts/zch.py -c '{0}' {1}".format(cmd, buildfolder), chk=chk)


def docker_umount_disks():
    """Unmount disks on host."""
    docker_runcmd("umount -R {0}".format(mountfolder_root))
    docker_runcmd("umount -Rl {0}".format(mountfolder_root))


def chroot_runcmd(cmd, chk=True):
    """Run a command in the chroot in the docker container"""
    subprocess.run(["{0}/zch.py".format(SCRIPTDIR), "-c", cmd, mountfolder_root], check=chk)


def umount_disks():
    """Unmount disks on host."""
    subprocess.run("umount -R {0}".format(mountfolder_root), shell=True, check=False)
    subprocess.run("umount -Rl {0}".format(mountfolder_root), shell=True, check=False)
    os.rmdir(mountfolder_root)


def workingfolder_clean():
    """Clean up and remove working folder."""
    shutil.rmtree(buildfolder)


def signal_handler(sig, frame):
    """Handle a SIGINT signal."""
    docker_destroy(docker_name)
    umount_disks()
    workingfolder_clean()
    print('Exiting due to SIGINT.')
    sys.exit(1)
######### End Functions #########


# Get arguments
parser = argparse.ArgumentParser(description='Build LiveCD.')
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-b", "--blockdevice", help='Block Device to use.')
parser.add_argument("-r", "--release", help='Release of LiveUSB', default="bionic")
parser.add_argument("-w", "--workfolder", help='Location of Working Folder')

# Save arguments.
args = parser.parse_args()

# Exit if not root.
CFunc.is_root(True)

# Process variables
print("Release: {0}".format(args.release))
if args.workfolder and os.path.isdir(args.workfolder):
    buildfolder = os.path.join(os.path.abspath(args.workfolder), "ubuntuusb_temp")
    print("Using work folder {0}.".format(buildfolder))
else:
    sys.exit("\nERROR, work folder {0} is invalid. Please specify a valid folder.".format(args.workfolder))
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
for root, dirs, files in os.walk("/dev"):
    for file in files:
        absfilepath = os.path.join(root, file)
        if absfilepath.startswith((blockdevice)):
            print("Unmounting {0}.".format(absfilepath))
            subprocess.run("umount {0}; umount -l {0}".format(absfilepath), shell=True, check=False)

### Docker Section ###
# Global variables
rootdiskid = "usbubuntu"
mountfolder_root = os.path.join(os.sep, "var", "tmp", "mountfld")
mountfolder_efi = os.path.join(mountfolder_root, "boot", "efi")
blockdevice_root = "{0}3".format(blockdevice)
blockdevice_efi = "{0}2".format(blockdevice)
# Create temporary folder.
os.makedirs(buildfolder, exist_ok=True)
# Create the docker container.
docker_name = "ubuusb"
docker_image = "ubuntu:latest"
docker_options = '-v /opt/CustomScripts:/opt/CustomScripts -v "{0}":"{0}" -v "{1}":"{1}" -e DEBIAN_FRONTEND=noninteractive'.format(blockdevice, buildfolder)
docker_destroy(docker_name)
print("Creating docker container {0}.".format(docker_name))
subprocess.run("docker run -dt --privileged --name {0} {1} {2} bash".format(docker_name, docker_options, docker_image), shell=True)
try:
    # Provision the docker container with the correct utilities.
    docker_runcmd("apt-get update")
    docker_runcmd("apt-get install -y python3 debootstrap gdisk util-linux dosfstools e2fsprogs")

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
    docker_runcmd("mkdir -p {0}".format(mountfolder_root))
    docker_runcmd("mount {0} {1}".format(blockdevice_root, mountfolder_root))
    docker_runcmd("mkdir -p {0}".format(mountfolder_efi))
    docker_runcmd("mount {0} {1}".format(blockdevice_efi, mountfolder_efi))
    # Run debootstrap
    print("\nRunning debootstrap.")
    docker_runcmd("debootstrap {0} {1}".format(args.release, buildfolder), chk=False)
    docker_chroot_script = """#!/bin/bash
set -eu
# Install kernel and bootloader
apt-get update
apt-get install -y linux-image-generic grub-efi
sed -i "/^#GRUB_TIMEOUT=.*/s/^#//g" /etc/default/grub
sed -i "/GRUB_HIDDEN_TIMEOUT/ s/^#*/#/" /etc/default/grub
sed -i "/GRUB_HIDDEN_TIMEOUT_QUIET/ s/^#*/#/" /etc/default/grub
sed -i "s/GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/g" /etc/default/grub
sed -i "s/GRUB_HIDDEN_TIMEOUT=.*$/GRUB_HIDDEN_TIMEOUT=1/g" /etc/default/grub
chmod a-x /etc/grub.d/30_os-prober

apt-get install -y --no-install-recommends software-properties-common
add-apt-repository main && add-apt-repository restricted && add-apt-repository universe && add-apt-repository multiverse
apt-get update
# Install locales
apt-get install -y locales
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo 'LANG="en_US.UTF-8"'>/etc/default/locale
locale-gen --purge en_US en_US.UTF-8
dpkg-reconfigure --frontend=noninteractive locales
update-locale
# Locale fix for gnome-terminal.
echo "LANG=en_US.UTF-8" > /etc/locale.conf
# Set keymap for Ubuntu
echo "console-setup	console-setup/charmap47	select	UTF-8" | debconf-set-selections

# Install CLI Software
apt-get install -y \
btrfs-progs \
chntpw \
clonezilla \
curl \
debootstrap \
dmraid \
efibootmgr \
f2fs-tools \
fsarchiver \
git \
iotop \
less \
lvm2 \
mdadm \
nano \
rsync \
screen \
ssh \
tmux \
whois \
xfsprogs

# Install GUI software
apt-get install -y \
avahi-daemon \
avahi-discover \
caja-open-terminal \
chromium-browser \
dconf-cli \
gnome-keyring \
gnome-disk-utility \
gparted \
gvfs \
leafpad \
lightdm \
mate-desktop-environment \
network-manager \
network-manager-gnome \
net-tools \
wireless-tools \
xserver-xorg

# Install VM software
apt-get install -y \
dkms \
spice-vdagent \
qemu-guest-agent \
open-vm-tools \
open-vm-tools-desktop \
virtualbox-guest-utils \
virtualbox-guest-dkms \
virtualbox-guest-x11 \
build-essential

# Final initram generation
update-initramfs -u -k all

# Clean environment
apt-get purge -y locales
apt-get clean
# From https://git.launchpad.net/livecd-rootfs/tree/live-build/ubuntu-core/hooks/10-remove-documentation.binary
echo "I: Remove unneeded files from /usr/share/doc "
find /usr/share/doc -depth -type f ! -name copyright|xargs rm -f || true
find /usr/share/doc -empty|xargs rmdir || true
find /usr/share/doc -type f -exec gzip -9 {} \;

echo "I: Remove man/info pages"
rm -rf /usr/share/man \
       /usr/share/groff \
       /usr/share/info \
       /usr/share/lintian \
       /usr/share/linda \
       /var/cache/man

echo "I: Removing /var/lib/apt/lists/*"
find /var/lib/apt/lists/ -type f | xargs rm -f

echo "I: Removing /var/cache/apt/*.bin"
rm -f /var/cache/apt/*.bin
"""
    docker_chroot_scriptpath = os.path.join(buildfolder, "a.sh")
    with open(docker_chroot_scriptpath, 'w') as fd:
        fd.write(docker_chroot_script)
    docker_runcmd("chmod a+x {0}".format(docker_chroot_scriptpath))
    docker_runcmd("/opt/CustomScripts/zch.py -c '/a.sh' {0}".format(buildfolder))
    # Unmount the disks
    print("Unmounting disks.")
    docker_runcmd("umount -R {0}".format(mountfolder_root), chk=False)
    docker_runcmd("umount -Rl {0}".format(mountfolder_root), chk=False)
    docker_runcmd("umount -Rf {0}".format(mountfolder_root), chk=False)
# Cleanup the docker container
finally:
    print("Cleaning up docker images.")
    docker_destroy(docker_name)

### Direct Chroot ###
# Mount disks.
os.makedirs(mountfolder_root, exist_ok=True)
subprocess.run("mount {0} {1}".format(blockdevice_root, mountfolder_root), shell=True)
os.makedirs(mountfolder_efi, exist_ok=True)
subprocess.run("mount {0} {1}".format(blockdevice_efi, mountfolder_efi), shell=True)
try:
    # Rsync the folder to the drive.
    subprocess.run('rsync -axHAX --info=progress2 --numeric-ids --del "{0}/" "{1}/"'.format(buildfolder, mountfolder_root), shell=True, check=True)
    subprocess.run('sync', shell=True)
    # Generate fstab
    fstab_uuid_p2 = CFunc.subpout("blkid -s UUID -o value {0}".format(blockdevice_efi))
    fstab_uuid_p3 = CFunc.subpout("blkid -s UUID -o value {0}".format(blockdevice_root))
    fstab_text = """
# /dev/sdd3
UUID={0}	/	ext4	rw,relatime	0	1

# /dev/sdd2
UUID={1}	/boot/efi	vfat	defaults,rw,errors=remount-ro	0	2
""".format(fstab_uuid_p3, fstab_uuid_p2)
    fstab_path = os.path.join(mountfolder_root, "etc", "fstab")
    with open(fstab_path, 'w') as fd:
        fd.write(fstab_text)
    chroot_runcmd("grub-install --target=x86_64-efi --boot-directory=/boot --efi-directory=/boot/efi --bootloader-id={0} --recheck --removable".format(rootdiskid))
    chroot_runcmd("update-grub")
    # Create and copy grub.cfg
    grubcfg_text = """search --label {0} --set prefix
configfile ($prefix)/boot/grub/grub.cfg""".format(rootdiskid)
    grubcfg_path = os.path.join(mountfolder_efi, "EFI", "BOOT", "grub.cfg")
    with open(grubcfg_path, 'w') as fd:
        fd.write(grubcfg_text)
    # Final initram generation
    chroot_runcmd("update-initramfs -u -k all")
    # Rerun some cleanup
    chroot_runcmd("apt-get clean")
    chroot_runcmd("rm -f /var/cache/apt/*.bin")
finally:
    umount_disks()
    workingfolder_clean()

print("\nScript ended successfully!")
