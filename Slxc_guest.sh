#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Add general functions if they don't exist.
type -t grepadd &> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

if [ "$(id -u)" != "0" ]; then
	echo "Not running as root. Please run the script with sudo or root privledges."
	exit 1;
fi

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR=$SUDO_USER
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR=$USER
	else
		export USERNAMEVAR=$(id 1000 -un)
	fi
fi
export USERGROUP=$(id $USERNAMEVAR -gn)
export USERHOME=/home/$USERNAMEVAR

# Variables for Script
LXCCONFFILE="/etc/lxc/lxc.conf"

# Set LXC Path if lxc.conf file does not have a valid folder path.
if [ -f $LXCCONFFILE ]; then
	LXCVMPATH="$(sed -n -e 's/^lxc.lxcpath = \(.*\)/\1/p' /etc/lxc/lxc.conf)"
fi
while [ ! -d "$LXCVMPATH" ]; do
	echo "Input an LXC VM Path (i.e. \"/mnt/Storage/VMs\")"
	read -r LXCVMPATH
	if [ ! -d "$LXCVMPATH"]; then
		echo "$LXCVMPATH is not a folder. Please input a new path."
	else
		echo "Writing ${LXCVMPATH} to ${LXCCONFFILE}."
		echo "lxc.lxcpath = ${LXCVMPATH}" >> ${LXCCONFFILE}
	fi
done

# Set the VM choice
[ -z "$LXCVMCHOICE" ] && LXCVMCHOICE="0"
while [[ "${LXCVMCHOICE}" -le "0" || "${LXCVMCHOICE}" -gt "2" ]]; do
	read -p "Enter 1 to install a downloaded container, 2 to install arch. (1/2): " LXCVMCHOICE
done
echo "VM choice is $LXCVMCHOICE"

# Set the VM name
while [ -z $LXCVMNAME ]; do
	read -p "Enter a name for the VM:" LXCVMNAME
	# Scrub name to eliminate invalid characters
	LXCVMNAME=${LXCVMNAME//[^a-zA-Z0-9_-]/}
done
echo "VM name is $LXCVMNAME"

# Set IP of VM
[ -z "$LXCVMIP" ] && LXCVMIP="0"
while [[ "${LXCVMIP}" -le "0" || "${LXCVMIP}" -gt "254" ]]; do
	read -p "Enter the last number for the ip of the VM (i.e. input \"2\", to have an IP of 10.0.3.2): " LXCVMIP
done
echo "VM IP is $LXCVMIP"

# Set bridge adapter.
while [ -z "$LXCVMNETADAPTER" ]; do
	echo "Printing adapter information."
	ip a
	echo "Input a network adapter to share internet with the VM (i.e. \"enp3s0\")"
	read -r LXCVMNETADAPTER
	if [ -z "$LXCVMNETADAPTER" ]; then
		echo "Network Adapter is not set. Please input a network adapter."
	fi
done
echo "VM bridge adpater is $LXCVMNETADAPTER"

echo "Script will install a VM ${LXCVMNAME} to ${LXCVMPATH} with an IP of 10.0.3.${LXCVMIP}."
read -p "Press any key to continue."

set -eu

# Set more Variables
LXCVMTOPLEVELPATH="${LXCVMPATH}/${LXCVMNAME}"
LXCVMCONFIG="${LXCVMTOPLEVELPATH}/config"
LXCVMSCRIPT="${LXCVMTOPLEVELPATH}/script.sh"
LXCVMROOT="${LXCVMTOPLEVELPATH}/rootfs"

# Install the container
case $LXCVMCHOICE in
[1] )
	lxc-create -t download -n "${LXCVMNAME}"
;;
[2] )
	if [ -f /usr/share/lxc/templates/lxc-archlinux ]; then
		lxc-create -n "${LXCVMNAME}" -t /usr/share/lxc/templates/lxc-archlinux
		"$SCRIPTDIR/BArchChroot.sh" "${LXCVMROOT}"
	else
		echo "Arch template not found. Exiting."
	fi
;;
esac

# Add scripts
chmod a+rwx "${LXCVMTOPLEVELPATH}"
chmod a+rwx "${LXCVMCONFIG}"
chmod a+rwx "${LXCVMROOT}"
multilinereplace "${LXCVMSCRIPT}" <<EOLXYZ
#!/bin/bash

# Enable verbose printing
set -x

# Start bridge networking for guest
systemctl start lxc-net

# Enable NAT routing for guest
iptables -t nat -A POSTROUTING -o ${LXCVMNETADAPTER} -j MASQUERADE

# Forward port 80 to host's port 80
iptables -t nat -A PREROUTING -i ${LXCVMNETADAPTER} -p tcp --dport 80 -j DNAT --to 10.0.3.${LXCVMIP}:80
EOLXYZ

# Uncomment and change lines
if [ -f "${LXCVMCONFIG}" ]; then
	sed -i '/^#lxc.network.ipv4=.*/s/^#//g' "${LXCVMCONFIG}"
	sed -i "s/^lxc.network.ipv4=.*/lxc.network.ipv4=10.0.3."$LXCVMIP"/" "${LXCVMCONFIG}"
	sed -i '/^#lxc.network.ipv4.gateway=.*/s/^#//g' "${LXCVMCONFIG}"
	sed -i '/^#lxc.hook.pre-start=.*/s/^#//g' "${LXCVMCONFIG}"
fi

cd "${LXCVMROOT}/opt"
git clone https://github.com/vinadoros/CustomScripts.git
