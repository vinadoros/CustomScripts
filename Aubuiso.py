#!/usr/bin/env python3
"""Create an Ubuntu live-cd."""

# Python includes.
import argparse
from datetime import datetime
import logging
import os
import subprocess
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
    CFunc.subpout_logger("PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/local/bin chroot {0} {1}".format(rootfsfolder, cmd))
    return
def chroot_end():
    """Unmount important chroot folders."""
    subprocess.run("""
    echo "Unmounting chroot folders."
    umount -l {0}/dev > /dev/null &
    umount -l {0}/proc > /dev/null &
    umount -l {0}/sys > /dev/null &
    umount -l {0}/tmp > /dev/null &
    """.format(rootfsfolder), shell=True)
    return


# Exit if not root.
CFunc.is_root(True)

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

# Commands to run inside chroot
try:
    # Mount the chroot filesystems.
    chroot_start()
    chroot_command("apt update")
    chroot_command("apt-get install -y --no-install-recommends casper software-properties-common")
    chroot_command("add-apt-repository main && add-apt-repository restricted && add-apt-repository universe && add-apt-repository multiverse")
    chroot_command("apt update")
    chroot_command("apt-get install -y --no-install-recommends network-manager net-tools wireless-tools curl openssh-client xserver-xorg-core xserver-xorg xinit openbox xterm nano")
    chroot_command("apt-get clean")
    # Set up NetworkManager
    chroot_command("sed -i 's/managed=.*/managed=true/g' /etc/NetworkManager/NetworkManager.conf")
    chroot_command("touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf")
    # Set root password
    chroot_command("passwd -u root")
    chroot_command('chpasswd <<<"root:asdf"')
    # Unmount the chroot filesystems when done.
    chroot_end()
except Exception:
    logging.error("ERROR: Chroot command failed.")
    logging.error(traceback.format_exc())
    # Unmount the chroot filesystems upon error.
    chroot_end()
    sys.exit()

os.makedirs(os.path.join(buildfolder, "scratch"), exist_ok=True)
os.makedirs(os.path.join(buildfolder, "image", "casper"), exist_ok=True)

# Create squashfs
squashfs_file = os.path.join(buildfolder, "image", "casper", "filesystem.squash")
if os.path.isfile(squashfs_file):
    logging.info("Remove existing {0}.".format(squashfs_file))
    os.remove(squashfs_file)
CFunc.subpout_logger("mksquashfs {0}/chroot {1}/image/casper/filesystem.squashfs -e boot".format(rootfsfolder, buildfolder))
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

debcustom_path = os.path.join(buildfolder, "image", "DEBIAN_CUSTOM")
debcustom_path.touch(exist_ok=True)
CFunc.subpout_logger('''grub-mkstandalone \
    --format=i386-pc \
    --output={0}/scratch/core.img \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
    --modules="linux normal iso9660 biosdisk search" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg={0}/scratch/grub.cfg"'''.format(buildfolder))
CFunc.subpout_logger("""cd {0}/scratch && \
    dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
    mkfs.vfat efiboot.img && \
    mmd -i efiboot.img efi efi/boot && \
    mcopy -i efiboot.img ./bootx64.efi ::efi/boot/""".format(buildfolder))
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
