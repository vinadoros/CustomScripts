#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Set machine architecture
[ -z "$MACHINEARCH" ] && MACHINEARCH=$(uname -m)

# Enable error halting.
set -eu

# Systemd-swap
if [[ -f /etc/systemd-swap.conf && "${MACHINEARCH}" != "armv7l" ]]; then
	echo "Modifying /etc/systemd-swap.conf."
	sed -i 's/# zram\[size\]=$\[${sys\[ram_size\]}\/4\]K # This is 1\/4 of ram size by default\./zram\[size\]=$\[${sys\[ram_size\]}\/4\]K # This is 1\/4 of ram size by default\./g' /etc/systemd-swap.conf
	sed -i 's/\# zram\[streams\]\=${sys\[cpu_count\]}/zram\[streams\]\=${sys\[cpu_count\]}/g' /etc/systemd-swap.conf
	sed -i 's/# zram\[alg\]=lz4/zram\[alg\]=lz4/g' /etc/systemd-swap.conf
	sed -i 's/# swapf\[size\]=${sys\[ram_size\]}K # Size of swap file\./swapf\[size\]=${sys\[ram_size\]}K # Size of swap file\./g' /etc/systemd-swap.conf
	sed -i 's/# swapf\[path\]=\/var\/swap/swapf\[path\]=\/var\/swap/g' /etc/systemd-swap.conf
fi


# Install Zswap if no systemd-swap
SYSTEMDPATH="$(readlink -f "/lib/systemd")"
ZRAMSCRIPT="/usr/local/bin/zramscript"
ZRAMSERVICE="${SYSTEMDPATH}/system/zram.service"
if [[ ! -f /etc/systemd-swap.conf ]]; then
	echo "Creating ${ZRAMSCRIPT}."
	bash -c "cat >${ZRAMSCRIPT}" <<"EOLXYZ"
#!/bin/sh
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

FRACTION=75

MEMORY=`perl -ne'/^MemTotal:\s+(\d+)/ && print $1*1024;' < /proc/meminfo`
CPUS=`grep -c processor /proc/cpuinfo`
# Alternative: CPUS=`nproc`
# If CPUs greater than 4, reduce to 4.
[[ $CPUS -gt 4 ]] && CPUS=4

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
esac
EOLXYZ
	chmod a+rwx "${ZRAMSCRIPT}"

	echo "Creating ${ZRAMSERVICE}."
	bash -c "cat >${ZRAMSERVICE}" <<EOLXYZ
[Unit]
Description=Zram-based swap (compressed RAM block devices)

[Service]
Type=oneshot
ExecStart=${ZRAMSCRIPT} start
ExecStop=${ZRAMSCRIPT} stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOLXYZ
	systemctl daemon-reload
	systemctl enable "$(basename ${ZRAMSERVICE})"

	# Swap file setup
	SWAPFILE="/var/swap"
	if [ ! -f "$SWAPFILE" ] && ! swapon | grep -i [s/v]d[a-z][0-9]; then
		if ! grep -q "$SWAPFILE" /etc/fstab && ! grep -i "/ " /etc/fstab | grep -iq "btrfs"; then
			echo "Creating $SWAPFILE."
			fallocate -l 1GiB "$SWAPFILE"
			chmod 600 "$SWAPFILE"
			mkswap "$SWAPFILE"
			if [ ! -z "$(tail -1 /etc/fstab)" ]; then echo "" >> /etc/fstab ; fi
			echo -e "$SWAPFILE\tnone\tswap\tdefaults\t0\t0" >> /etc/fstab
		elif ! grep -q "$SWAPFILE" /etc/fstab && grep -i "/ " /etc/fstab | grep -iq "btrfs"; then
			echo "Not creating swap file, rootfs is btrfs."
		fi
	else
		echo "Swap detected on $(swapon | grep -i [s/v]d[a-z][0-9]), not creating."
	fi

fi
