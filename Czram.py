#!/usr/bin/env python3
"""Create zram startup script"""

import argparse
import multiprocessing
import os
import subprocess
import sys

print("Running {0}".format(__file__))

# Get arguments
parser = argparse.ArgumentParser(description='Install zram script.')
parser.add_argument("-c", "--cputhreads", type=int, help='Number of zram partitions to create (0 is autodetect)', default="1")

# Save arguments.
args = parser.parse_args()

# Exit if not root.
CFunc.is_root(True)

# Autodetect cores if not specified above.
if args.cputhreads is 0:
    cpucores = multiprocessing.cpu_count() if multiprocessing.cpu_count() <= 4 else 4
else:
    cpucores = args.cputhreads

print("Zram threads:", cpucores)

# File variables
zramscript = "/usr/local/bin/zramscript"
systemdfolder = "/etc/systemd/system"
systemdservicename = "zram.service"
systemdservice = systemdfolder + "/" + systemdservicename
if os.path.isdir(systemdfolder):
    print("Creating {0}".format(zramscript))
    with open(zramscript, 'w') as zramscript_write:
        zramscript_write.write("""#!/bin/sh
### BEGIN INIT INFO
# Provides:          zram
# Required-Start:    $local_fs
# Required-Stop:     $local_fs
# Default-Start:     S
# Default-Stop:      0 1 6
# Short-Description: Use compressed RAM as in-memory swap
# Description:       Use compressed RAM as in-memory swap
### END INIT INFO

# Author: Antonio Galea <antonio.galea@gmail.com>
# Thanks to Przemysław Tomczyk for suggesting swapoff parallelization

FRACTION=150

MEMORY="$(free -tb | awk '/Mem\\:/ {{ print $2 }}')"
# CPUS=`nproc`
# If CPUs greater than 4, reduce to 4.
# [[ $CPUS -gt 4 ]] && CPUS=4
CPUS={0}

SIZE=$(( MEMORY * FRACTION / 100 / CPUS ))

case "$1" in
  "start")
    param=`modinfo zram|grep num_devices|cut -f2 -d:|tr -d ' '`
    modprobe zram $param=$CPUS
    for n in `seq $CPUS`; do
      i=$((n - 1))
      echo $SIZE > /sys/block/zram$i/disksize
      mkswap /dev/zram$i
      swapon /dev/zram$i -p 10
    done
    ;;
  "stop")
    for n in `seq $CPUS`; do
      i=$((n - 1))
      swapoff /dev/zram$i && echo "disabled disk $n of $CPUS" &
    done
    wait
    sleep .5
    modprobe -r zram
    ;;
  *)
    echo "Usage: `basename $0` (start | stop)"
    exit 1
    ;;
esac""".format(cpucores))
    os.chmod(zramscript, 0o777)

    print("Creating {0}".format(systemdservice))
    with open(systemdservice, 'w') as systemdservice_write:
        systemdservice_write.write("""[Unit]
Description=Zram-based swap (compressed RAM block devices)

[Service]
Type=simple
ExecStart={0} start
ExecStop={0} stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
""".format(zramscript))

    subprocess.run("""
systemctl daemon-reload
systemctl enable {0}
""".format(systemdservicename), shell=True)
