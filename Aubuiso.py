#!/usr/bin/env python3
"""Create an Ubuntu live-cd."""

# Python includes.
import argparse
from datetime import datetime
import logging
import os
from pathlib import Path
import subprocess
import signal
import sys
import time
import traceback
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]


### Functions ###
def chroot_start():
    """Mount important chroot folders."""
    subprocess.run("""
    mount --rbind /dev {0}/dev
    mount --make-rslave {0}/dev
    mount -t proc /proc {0}/proc
    mount --rbind /sys {0}/sys
    mount --make-rslave {0}/sys
    mount --rbind /tmp {0}/tmp
    cp /etc/resolv.conf {0}/etc/resolv.conf
    """.format(rootfsfolder), shell=True)
    return
def chroot_command(cmd):
    """Run a command inside of the chroot."""
    CFunc.subpout_logger("chroot {0} {1}".format(rootfsfolder, cmd))
    return
def chroot_end():
    """Unmount important chroot folders."""
    logging.info("Unmounting chroot folders.")
    subprocess.run("""
    umount -l {0}/dev > /dev/null &
    umount -l {0}/proc > /dev/null &
    umount -l {0}/sys > /dev/null &
    umount -l {0}/tmp > /dev/null &
    """.format(rootfsfolder), shell=True)
    return
def signal_handler(sig, frame):
    if os.path.isdir(rootfsfolder):
        chroot_end()
    print('Exiting due to SIGINT.')
    sys.exit(1)


# Exit if not root.
CFunc.is_root(True)
# Attach signal handler.
signal.signal(signal.SIGINT, signal_handler)

# Get the root user's home folder.
USERHOME = os.path.expanduser("~root")
workfolder_default = os.path.join(USERHOME, "ubulive")

# Get arguments
parser = argparse.ArgumentParser(description='Build LiveCD.')
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-w", "--workfolder", help='Location of Working Folder (i.e. {0})'.format(workfolder_default), default=workfolder_default)
parser.add_argument("-r", "--release", help='Ubuntu Release', default="bionic")

# Save arguments.
args = parser.parse_args()

# Process variables
buildfolder = os.path.abspath(args.workfolder)
rootfsfolder = os.path.join(buildfolder, "chroot")
print("Using work folder {0}.".format(buildfolder))
print("Ubuntu Release: {0}".format(args.release))

if args.noprompt is False:
    input("Press Enter to continue.")


# Create the work folder
if os.path.isdir(buildfolder):
    print("Work folder {0} already exists.".format(buildfolder))
else:
    print("Creating work folder {0}.".format(buildfolder))
    os.mkdir(buildfolder, 0o777)

# Save start time.
beforetime = datetime.now()
# Isoname
currentdatetime = time.strftime("%Y-%m-%d_%H%M")
isoname = "Ubuntu-CustomLive-{0}.iso".format(currentdatetime)

# Initiate logger
buildlog_path = os.path.join(buildfolder, "{0}.log".format(isoname))
CFunc.log_config(buildlog_path)

### Build LiveCD ###

CFunc.aptupdate()
CFunc.aptinstall("debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools")
CFunc.subpout_logger("debootstrap --arch=amd64 --include linux-image-generic {0} {1}  http://us.archive.ubuntu.com/ubuntu/".format(args.release, rootfsfolder))

# Create chroot script.
with open(os.path.join(rootfsfolder, "chrootscript.sh"), 'w') as cs_handle:
    cs_handle.write("""#!/bin/bash -e
apt-get update
apt-get install -y --no-install-recommends casper software-properties-common
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
# Install software
apt-get install -y network-manager net-tools wireless-tools curl openssh-client xserver-xorg-core xserver-xorg nano lightdm mate-desktop-environment
# Install VM software
apt-get install -y dkms spice-vdagent qemu-guest-agent open-vm-tools open-vm-tools-desktop virtualbox-guest-utils virtualbox-guest-dkms virtualbox-guest-x11 build-essential
apt-get clean
sed -i 's/managed=.*/managed=true/g' /etc/NetworkManager/NetworkManager.conf
touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
passwd -u root
chpasswd <<<"root:asdf"
""")
os.chmod(os.path.join(rootfsfolder, "chrootscript.sh"), 0o777)

# Commands to run inside chroot
try:
    # Mount the chroot filesystems.
    chroot_start()
    chroot_command(os.path.join("/", "chrootscript.sh"))
    # Unmount the chroot filesystems when done.
    chroot_end()
    os.remove(os.path.join(rootfsfolder, "chrootscript.sh"))
except Exception:
    logging.error("ERROR: Chroot command failed.")
    logging.error(traceback.format_exc())
    # Unmount the chroot filesystems upon error.
    chroot_end()
    sys.exit()

os.makedirs(os.path.join(buildfolder, "scratch"), exist_ok=True)
os.makedirs(os.path.join(buildfolder, "image", "casper"), exist_ok=True)

# Create squashfs
CFunc.subpout_logger("mksquashfs {0} {1}/image/casper/filesystem.squashfs -noappend -e boot".format(rootfsfolder, buildfolder))
# Copy kernel and initrd
CFunc.subpout_logger("cp {0}/boot/vmlinuz-* {1}/image/vmlinuz".format(rootfsfolder, buildfolder))
CFunc.subpout_logger("cp {0}/boot/initrd.img-* {1}/image/initrd".format(rootfsfolder, buildfolder))

# Grub config file.
with open(os.path.join(buildfolder, "scratch", "grub.cfg"), 'w') as grubcfg_handle:
    grubcfg_handle.write("""
search --set=root --file /DEBIAN_CUSTOM

insmod all_video

set default="0"
set timeout=1

menuentry "Ubuntu Live" {
    linux /vmlinuz boot=casper noprompt
    # Add "earlyprintk serial=tty0 console=ttyS0,115200n8" for debugging
    initrd /initrd
}
""")

debcustom_path = Path(os.path.join(buildfolder, "image", "DEBIAN_CUSTOM"))
debcustom_path.touch(exist_ok=True)
CFunc.subpout_logger('''grub-mkstandalone \
    --format=x86_64-efi \
    --output={0}/scratch/bootx64.efi \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg={0}/scratch/grub.cfg"'''.format(buildfolder))
CFunc.subpout_logger("""cd {0}/scratch && \
    dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
    mkfs.vfat efiboot.img && \
    mmd -i efiboot.img efi efi/boot && \
    mcopy -i efiboot.img ./bootx64.efi ::efi/boot/""".format(buildfolder))
CFunc.subpout_logger('''grub-mkstandalone \
    --format=i386-pc \
    --output={0}/scratch/core.img \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
    --modules="linux normal iso9660 biosdisk search" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg={0}/scratch/grub.cfg"'''.format(buildfolder))
CFunc.subpout_logger("cat /usr/lib/grub/i386-pc/cdboot.img {0}/scratch/core.img > {0}/scratch/bios.img".format(buildfolder))
CFunc.subpout_logger("""xorriso \
    -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "DEBIAN_CUSTOM" \
    -eltorito-boot \
        boot/grub/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog boot/grub/boot.cat \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
        -e EFI/efiboot.img \
        -no-emul-boot \
    -append_partition 2 0xef {0}/scratch/efiboot.img \
    -output "{0}/{1}" \
    -graft-points \
        "{0}/image" \
        /boot/grub/bios.img={0}/scratch/bios.img \
        /EFI/efiboot.img={0}/scratch/efiboot.img""".format(buildfolder, isoname))
