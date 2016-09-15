#!/bin/bash

if [ "$(id -u)" = "0" ]; then
	echo "Running as root. Please run the script with user privledges."
	exit 1;
fi

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Default variables
SSHPORT=61234
VBOXMEMORY=2048
LIVESSHUSER=root
LIVESSHPASS=asdf
USER=user
FULLNAME="User Name"
PASSWORD=asdf
COMMAND=1
# Detect CPUs
if [ $(nproc) -gt 4 ]; then
	NUMCPUS=4
else
	NUMCPUS=$(nproc)
fi
# Detect ssh key
if [ ~/.ssh/id_ed25519.pub ]; then
	ROOTSSHKEY="$(<~/.ssh/id_ed25519.pub)"
elif [ ~/.ssh/id_rsa.pub ]; then
	ROOTSSHKEY="$(<~/.ssh/id_rsa.pub)"
fi

usage () {
	echo "h - help"
	echo "a - Arch VM"
	echo "b - Debian Unstable VM"
  echo "c - Ubuntu VM"
	echo "d - Fedora VM"
  echo "f - Full Name (defualt is $FULLNAME)"
  echo "i - Path to live cd"
  echo "m - Memory for VM (default is $VBOXMEMORY)"
  echo "p - Path of Virtual Machine folders"
  echo "v - Root SSH Key (required, detected as $ROOTSSHKEY)"
  echo "w - Live SSH Username (default is $LIVESSHUSER)"
  echo "x - Live SSH Password (default is $LIVESSHPASS)"
  echo "y - VM Username (default is $USER)"
  echo "z - VM Password (default is $PASSWORD)"
	echo "n - Do not prompt to continue."
	exit 0;
}

# Get options
while getopts ":p:i:v:w:x:y:z:f:nhabcds" OPT
do
	case $OPT in
		h)
      echo "Select a valid option."
	    usage
			;;
		a)
			echo "Arch VM Selected"
      VMNAME="ArchTest"
      VBOXOSID="ArchLinux_64"
			;;
		b)
      echo "Debian Unstable VM Selected"
      VMNAME="DebianTest"
      VBOXOSID="Debian_64"
			;;
    c)
      echo "Ubuntu VM Selected"
      VMNAME="UbuntuTest"
      VBOXOSID="Ubuntu_64"
      ;;
		d)
			echo "Fedora VM Selected"
			VMNAME="FedoraTest"
			VBOXOSID="Fedora_64"
			;;
		s)
			echo "Not executing install commands."
			COMMAND=0
			;;
    f)
      FULLNAME="$OPTARG"
      ;;
    i)
      FULLPATHTOISO="$(readlink -f ${OPTARG})"
      ;;
    m)
      VBOXMEMORY="$OPTARG"
      ;;
    p)
      PATHTOVDI="$(readlink -f ${OPTARG%/})"
      ;;
    v)
      ROOTSSHKEY="$OPTARG"
      ;;
    w)
      LIVESSHUSER="$OPTARG"
      ;;
    x)
      LIVESSHPASS="$OPTARG"
      ;;
    y)
      USER="$OPTARG"
      ;;
    z)
      PASSWORD="$OPTARG"
      ;;
		n)
			NOPROMPT=1
			;;
		\?)
			echo "Invalid option: -$OPTARG" 1>&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument" 1>&2
			exit 1
			;;
	esac
done

# Variables most likely to change.
echo "Path to Live cd is $FULLPATHTOISO"
echo "VM Memory is $VBOXMEMORY"
echo "Path to VM Files is $PATHTOVDI"
echo "Live SSH user is $LIVESSHUSER"
echo "SSH Key is $ROOTSSHKEY"
echo "VM User is $USER"
if [[ -z "$VBOXOSID" || -z "$ROOTSSHKEY" ]]; then
  echo "Parameters are missing."
  usage
fi

# Variables less likely to change.
FULLPATHTOVDI="${PATHTOVDI}/${VMNAME}/${VMNAME}.vdi"
VDISIZE="32768"
STORAGECONTROLLER="SATA Controller"

function sshwait(){
  SSHUSER="$1"
  SSHPASS="$2"
  echo "Waiting for VM to boot."
  sleep 20
  until sshpass -p "$SSHPASS" ssh -q "$SSHUSER"@127.0.0.1 -p $SSHPORT "echo Connected"; do
    echo "Waiting for ssh..."
    sleep 3
  done
}

if [[ $NOPROMPT != 1 ]]; then
	read -p "Press any key to continue."
fi
set -u

# Delete the VM if it already exists
if [[ -f "$FULLPATHTOVDI" ]]; then
  VBoxManage storageattach "$VMNAME" --storagectl "$STORAGECONTROLLER" --port 0 --device 0 --type hdd --medium none
  VBoxManage closemedium "$FULLPATHTOVDI" --delete
fi
if VBoxManage list vms | grep -i "$VMNAME"; then
  VBoxManage unregistervm "$VMNAME" --delete
fi

# Create the new VM
VBoxManage createvm --name "$VMNAME" --register
VBoxManage modifyvm "$VMNAME" --ostype "$VBOXOSID" --ioapic on --rtcuseutc on --pae off
VBoxManage modifyvm "$VMNAME" --memory "$VBOXMEMORY"
VBoxManage modifyvm "$VMNAME" --vram 32
VBoxManage modifyvm "$VMNAME" --mouse usbtablet
VBoxManage modifyvm "$VMNAME" --cpus "$NUMCPUS"
VBoxManage modifyvm "$VMNAME" --clipboard bidirectional --draganddrop bidirectional --usbehci on
# Storage settings
VBoxManage createhd --filename "${FULLPATHTOVDI}" --size "$VDISIZE"
chattr +C "${FULLPATHTOVDI}"
VBoxManage storagectl "$VMNAME" --name "$STORAGECONTROLLER" --add sata --portcount 4
VBoxManage storageattach "$VMNAME" --storagectl "$STORAGECONTROLLER" --port 0 --device 0 --type hdd --medium "${FULLPATHTOVDI}"
VBoxManage storageattach "$VMNAME" --storagectl "$STORAGECONTROLLER" --port 1 --device 0 --type dvddrive --medium "$FULLPATHTOISO"
VBoxManage modifyvm "$VMNAME" --boot1 dvd --boot2 disk
# Network settings
VBoxManage modifyvm "$VMNAME" --nic1 nat --nictype1 82540EM --cableconnected1 on
VBoxManage modifyvm "$VMNAME" --natpf1 "ssh,tcp,127.0.0.1,$SSHPORT,,22"

# Start the virtual machine
VBoxManage startvm "$VMNAME"

# Wait for the VM to boot
sshwait $LIVESSHUSER $LIVESSHPASS

if [ $COMMAND = 1 ]; then
	# LiveCD Commands
	sshpass -p $LIVESSHPASS ssh 127.0.0.1 -p $SSHPORT -l $LIVESSHUSER "cd /CustomScripts/; git pull"
	sshpass -p $LIVESSHPASS ssh 127.0.0.1 -p $SSHPORT -l $LIVESSHUSER "/CustomScripts/ZSlimDrive.py -n"
	if [ "$VBOXOSID" = "ArchLinux_64" ]; then
	  sshpass -p $LIVESSHPASS ssh 127.0.0.1 -p $SSHPORT -l $LIVESSHUSER "/CustomScripts/BArchChroot.sh -n -p /mnt -c $VMNAME -u $USER -f \"$FULLNAME\" -v $PASSWORD -g 2"
	elif [ "$VBOXOSID" = "Debian_64" ]; then
	  sshpass -p $LIVESSHPASS ssh 127.0.0.1 -p $SSHPORT -l $LIVESSHUSER "/CustomScripts/BDeb_chroot.sh -n -p /mnt -a amd64 -b 2 -c $VMNAME -u $USER -f \"$FULLNAME\" -v $PASSWORD -g 2"
	elif [ "$VBOXOSID" = "Ubuntu_64" ]; then
	  sshpass -p $LIVESSHPASS ssh 127.0.0.1 -p $SSHPORT -l $LIVESSHUSER "/CustomScripts/BDeb_chroot.sh -n -p /mnt -a amd64 -b 3 -c $VMNAME -u $USER -f \"$FULLNAME\" -v $PASSWORD -g 2"
	elif [ "$VBOXOSID" = "Fedora_64" ]; then
		sshpass -p $LIVESSHPASS ssh 127.0.0.1 -p $SSHPORT -l $LIVESSHUSER "/CustomScripts/BFedora.py -n -c $VMNAME -u $USER -f \"$FULLNAME\" -q $PASSWORD -g 2 /mnt"
	fi
	sshpass -p $LIVESSHPASS ssh 127.0.0.1 -p $SSHPORT -l $LIVESSHUSER "mkdir -p /mnt/root/.ssh/; echo \"$ROOTSSHKEY\" >> /mnt/root/.ssh/authorized_keys"
	sshpass -p $LIVESSHPASS ssh 127.0.0.1 -p $SSHPORT -l $LIVESSHUSER "poweroff"
	while VBoxManage list runningvms | grep -i "$VMNAME"; do
	  echo "Waiting for shutdown..."
	  sleep 10
	done

	# Detach the iso
	sleep 2
	VBoxManage storageattach "$VMNAME" --storagectl "$STORAGECONTROLLER" --port 1 --device 0 --type dvddrive --medium none

	# Restart the VM
	sleep 2
	VBoxManage startvm "$VMNAME"
	sshwait "$USER" "$PASSWORD"
	ssh 127.0.0.1 -p $SSHPORT -l root "cd /opt/CustomScripts/; git pull"
	if [ "$VBOXOSID" = "ArchLinux_64" ]; then
	  ssh 127.0.0.1 -p $SSHPORT -l root "/opt/CustomScripts/MArch.sh -n -e 3 -m 3 -s $PASSWORD"
	elif [ "$VBOXOSID" = "Debian_64" ]; then
	  ssh 127.0.0.1 -p $SSHPORT -l root "/opt/CustomScripts/MDebUbu.sh -n -e 2 -d -s $PASSWORD"
	elif [ "$VBOXOSID" = "Ubuntu_64" ]; then
	  ssh 127.0.0.1 -p $SSHPORT -l root "/opt/CustomScripts/MDebUbu.sh -n -e 3 -u -s $PASSWORD"
	elif [ "$VBOXOSID" = "Fedora_64" ]; then
		echo "Future code here."
	fi

	ssh 127.0.0.1 -p $SSHPORT -l root "reboot"
fi
