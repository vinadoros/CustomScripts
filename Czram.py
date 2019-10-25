#!/usr/bin/env python3
"""Create zram startup script"""

import os
import subprocess
import shutil
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

memory = CFunc.subpout("free -tb | awk '/Mem:/ {{ print $2 }}'")
zram_memory = int(int(memory) * 1.5)

### Begin Code ###
# Add zram to loaded startup modules.
moduleload_path = os.path.join(os.sep, "etc", "modules-load.d", "zram.conf")
if os.path.isdir(os.path.dirname(moduleload_path)):
    with open(moduleload_path, 'w') as f:
        f.write("zram")

# Add zram module options.
modprobe_path = os.path.join(os.sep, "etc", "modprobe.d", "zram.conf")
if os.path.isdir(os.path.dirname(modprobe_path)):
    with open(modprobe_path, 'w') as f:
        f.write("options zram num_devices=1")

# Create udev rule
zram_blockdevicename = os.path.join(os.sep, "dev", "zram0")
udevrule_path = os.path.join(os.sep, "etc", "udev", "rules.d", "99-zram.rules")
if os.path.isdir(os.path.dirname(udevrule_path)):
    with open(udevrule_path, 'w') as f:
        f.write('KERNEL=="zram0", ATTR{{disksize}}="{0}" RUN="{1} {2}", TAG+="systemd"'.format(zram_memory, shutil.which("mkswap"), zram_blockdevicename))

# Add zram to fstab
fstab_path = os.path.join(os.sep, "etc", "fstab")
fstab_text = "{0}\tnone\tswap\tdefaults\t0\t0".format(zram_blockdevicename)
if not CFunc.Fstab_CheckStringInFile(os.path.join(os.sep, "etc", "fstab"), zram_blockdevicename):
    CFunc.Fstab_AddLine(os.path.join(os.sep, "etc", "fstab"), fstab_text)

# Cleanup old scripts
# TODO: Remove later
if os.path.exists("/etc/systemd/system/zram.service"):
    subprocess.run("systemctl stop zram", shell=True)
    subprocess.run("systemctl disable zram", shell=True)
    os.remove("/etc/systemd/system/zram.service")

if os.path.exists("/usr/local/bin/zramscript"):
    os.remove("/usr/local/bin/zramscript")
