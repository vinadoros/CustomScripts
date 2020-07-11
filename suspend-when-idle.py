#!/usr/bin/env python3
"""Suspend on Network Inactivity"""

# Python includes.
import argparse
import datetime
import logging
import os
import re
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
    log_level = logging.CRITICAL

logging.basicConfig(level=log_level, format='%(asctime)s - %(levelname)s - %(message)s')

# Check if not running as root.
if os.geteuid() != 0:
    sys.exit("ERROR: Please run as root.")


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
def check_idle():
    """Check if network services are not being used."""
    status = False
    # Get network information.
    netstat_output = subprocess.check_output("netstat -tupa", shell=True)
    # Check samba status
    samba_status = grep_in_variable(netstat_output, r"ESTABLISHED.*smbd")
    # Check nfs status
    nfs_status = grep_in_variable(netstat_output, r"nfs.*ESTABLISHED")
    logging.debug("Samba Status: %s, NFS Status: %s", samba_status, nfs_status)
    if samba_status is True or nfs_status is True:
        status = True
    return status


### Begin Code ###
logging.critical("Script Started")
reset_timers()
while True:
    # Check if services are being used.
    services_are_used = check_idle()
    # If services are being used, reset the suspend timer.
    if services_are_used is True:
        reset_timers()
    else:
        current_time = datetime.datetime.now()
    logging.debug("Before suspend, Current Time: %s, Suspend Time: %s", current_time, suspend_time)
    # Suspend if the current time exceeds the suspend time.
    if current_time >= suspend_time:
        logging.critical("Suspending.")
        # Suspend the system.
        # subprocess.run("systemctl suspend -i", shell=True, check=True)
        subprocess.run("systemctl start systemd-suspend.service", shell=True, check=True)
        # Sleep until the suspend cycle is finished.
        time.sleep(20)
        # If a suspend occurs, reset the timers to the startup values, and begin counting down again.
        reset_timers()
        logging.critical("Came out of suspend.")
    # Wait one minute before checking the services again.
    time.sleep(60)

logging.critical("Script Exited")
