#!/usr/bin/env python3
"""Suspend on Network Inactivity"""

# Python includes.
import argparse
import datetime
import logging
import os
import subprocess
import sys
import time

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Suspend on Network Inactivity.')
parser.add_argument("-d", "--debug", help='Use Debug Logging', action="store_true")
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

### Global Variables ###
# Suspend Timeout (in minutes)
suspend_idle_minutes = 20

### Functions ###
def subpout(cmd, error_on_fail=True):
    """Get output from subprocess"""
    output = subprocess.run("{0}".format(cmd), shell=True, stdout=subprocess.PIPE, universal_newlines=True, check=error_on_fail).stdout.strip()
    return output
def reset_timers():
    """Reset the initial timers"""
    global current_time
    global suspend_time
    current_time = datetime.datetime.now()
    suspend_time = current_time + datetime.timedelta(minutes=suspend_idle_minutes)
def check_idle():
    """Check if network services are not being used."""
    status = False
    # Wait one minute before checking the services.
    time.sleep(60)
    # Check samba status. Use the brief output, and check the number of lines emitted by smbstatus.
    smbstatus_lines = subpout("smbstatus -b | wc -l")
    # The output of smbstatus brief will be 4 lines if nobody is connected. If more than 4 lines come out, it is likely someone is connected to the server.
    if int(smbstatus_lines) > 4:
        status = True
    # TODO: Check nfs status
    # nfs_status = subpout("nfsstat -s -l")
    logging.debug("Samba lines: {0}".format(smbstatus_lines))
    return status


### Begin Code ###
reset_timers()
while True:
    # Check if services are being used.
    services_are_used = check_idle()
    # If services are being used, reset the suspend timer.
    if services_are_used is True:
        reset_timers()
    else:
        current_time = datetime.datetime.now()

    logging.debug("Before suspend, Current Time: {0}, Suspend Time: {1}".format(current_time, suspend_time))
    # Suspend if the current time exceeds the suspend time.
    if current_time >= suspend_time:
        logging.critical("Suspending.")
        # Insert suspend command here.
        subprocess.run("systemctl suspend -i", shell=True, check=True)
        # Sleep for 1 minute.
        time.sleep(60)
        # If a suspend occurs, reset the timers to the startup values, and begin counting down again.
        reset_timers()

logging.critical("\nScript Exited")
