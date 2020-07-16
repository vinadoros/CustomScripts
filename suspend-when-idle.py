#!/usr/bin/env python3
"""Suspend on Network Inactivity"""

# Python includes.
import argparse
import datetime
import logging
import os
import re
import shutil
import subprocess
import sys
import time

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Suspend on Network Inactivity.')
parser.add_argument("-d", "--debug", help='Use Debug Logging', action="store_true")
parser.add_argument("-s", "--idletime", help='Number of minutes before sleeping (default: %(default)s)', type=int, default=30)
args = parser.parse_args()

# Enable logging
if args.debug:
    log_level = logging.DEBUG
else:
    log_level = logging.INFO

logging.basicConfig(level=log_level, format='%(asctime)s - %(levelname)s - %(message)s')

# Check if not running as root.
if os.geteuid() != 0:
    sys.exit("ERROR: Please run as root.")

# Ensure that certain commands exist.
cmdcheck = ["systemctl", "netstat", "iotop"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))


### Functions ###
def grep_in_variable(variable, re_pattern):
    """Search through a variable for a pattern."""
    was_found = False
    # The incoming input is expected to be raw bytes with newlines represented as \n. This uses splitlines to split the lines by newlines into an array.
    for line in variable.splitlines():
        # The lines are still bytes, so decode them into a string, so that line processing can occur.
        if re.search(re_pattern, line.decode()):
            was_found = True
    return was_found
def reset_timers():
    """Reset the initial timers"""
    global current_time
    global suspend_time
    current_time = datetime.datetime.now()
    suspend_time = current_time + datetime.timedelta(minutes=args.idletime)
def check_hd_used_once(throughput_threshold: float = 500.0):
    """Check if disks are being used."""
    disks_are_used = False
    iotop_output = subprocess.check_output("iotop --batch --kilobytes --iter 1 --only -qq", shell=True)
    iotop_parts = []
    for line in iotop_output.splitlines():
        # Split the fields using a space as the delimiter.
        iotop_parts += line.decode().rstrip("\n").split()
    # Save iotop numerical fields
    iotop_totalread = float(iotop_parts[4])
    iotop_totalwrite = float(iotop_parts[11])
    iotop_actualread = float(iotop_parts[16])
    iotop_actualwrite = float(iotop_parts[22])
    logging.debug("Disk Total Read: %s, Write: %s, Actual Read: %s, Write: %s", iotop_totalread, iotop_totalwrite, iotop_actualread, iotop_actualwrite)
    if iotop_totalread >= throughput_threshold or \
       iotop_totalwrite >= throughput_threshold or \
       iotop_actualread >= throughput_threshold or \
       iotop_actualwrite >= throughput_threshold:
        disks_are_used = True
    return disks_are_used
def check_hd_used_multiple(num_times: int = 5):
    """Check multiple times if disks are being used. This is cheap substitute for averaging."""
    disks_are_used = False
    disk_used_numtrue = 0
    # Loop through the list
    for l in range(0, num_times):
        # Wait before l in each sample.
        time.sleep(0.5)
        # Add one to the counter if it was used.
        if check_hd_used_once() is True:
            disk_used_numtrue += 1
    logging.debug("Disk Checks Idle: %s, Total: %s", disk_used_numtrue, num_times)
    # If the disk was used more than half the times checked, it was in use.
    if disk_used_numtrue >= (num_times / 2):
        disks_are_used = True
    return disks_are_used
def check_idle():
    """Check if network services are not being used."""
    status = False
    inhibit_string = ""
    # Get network information. Use the -n flag to speed up output, but lose the port names and instead must check using numbers.
    netstat_output = subprocess.check_output("netstat -tupan", shell=True)
    # Check ssh status
    ssh_status = grep_in_variable(netstat_output, r"ESTABLISHED.*sshd")
    inhibit_string += "SSH: {0}, ".format(ssh_status)
    # Check samba status
    samba_status = grep_in_variable(netstat_output, r"ESTABLISHED.*smbd")
    inhibit_string += "Samba: {0}, ".format(samba_status)
    # Check nfs status. NFS is usually served on port 2049.
    nfs_status = grep_in_variable(netstat_output, r":2049.*ESTABLISHED")
    inhibit_string += "NFS: {0}, ".format(nfs_status)
    # Check libvirt status. Inhibit suspend if any VM is running.
    libvirt_status = False
    libvirt_lines = 0
    if shutil.which("virsh"):
        libvirt_lines = int(subprocess.check_output("virsh list --state-running --name | wc -l", shell=True))
    # Libvirt outputs 1 line if no VMs are running. Will output 2 or more if VMs are running.
    if libvirt_lines >= 2:
        libvirt_status = True
    inhibit_string += "libvirt: {0}, ".format(libvirt_status)
    # Check if packer is running
    if subprocess.run("pgrep packer", shell=True, check=False, stdout=subprocess.DEVNULL).returncode == 0:
        packer_status = True
    else:
        packer_status = False
    inhibit_string += "Packer: {0}, ".format(packer_status)
    # HD Idle time
    if check_hd_used_multiple():
        hdidle_status = True
    else:
        hdidle_status = False
    inhibit_string += "HD Idle: {0}".format(hdidle_status)
    logging.info(inhibit_string)
    if samba_status is True or nfs_status is True or ssh_status is True or libvirt_status is True or packer_status is True or hdidle_status is True:
        status = True
    return status


### Begin Code ###
logging.info("Script Started")
reset_timers()
while True:
    # Check if services are being used.
    services_are_used = check_idle()
    # If services are being used, reset the suspend timer.
    if services_are_used is True:
        reset_timers()
    else:
        current_time = datetime.datetime.now()
    logging.info("Minutes until suspend: %s", ((suspend_time - current_time).total_seconds() / 60))
    # Suspend if the current time exceeds the suspend time.
    if current_time >= suspend_time:
        logging.info("Suspending.")
        # Suspend the system.
        # subprocess.run("systemctl suspend -i", shell=True, check=True)
        subprocess.run("systemctl start systemd-suspend.service", shell=True, check=True)
        # Sleep until the suspend cycle is finished.
        time.sleep(20)
        # If a suspend occurs, reset the timers to the startup values, and begin counting down again.
        reset_timers()
        logging.info("Came out of suspend.")
    # Wait one minute before checking the services again.
    time.sleep(60)

logging.info("Script Exited")
