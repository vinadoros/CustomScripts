#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Enable error halting.
set -eu

if [ -f /etc/ssh/sshd_config ]; then
	sed -i 's/#X11Forwarding no/X11Forwarding yes/g' /etc/ssh/sshd_config
	sed -i 's/#AllowAgentForwarding yes/AllowAgentForwarding yes/g' /etc/ssh/sshd_config
	sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config
fi

if [ -f /etc/ssh/ssh_config ]; then
	sed -i 's/#   ForwardX11 no/    ForwardX11 yes/g' /etc/ssh/ssh_config
	sed -i 's/# Host \*/    Host \*/g' /etc/ssh/ssh_config
	sed -i 's/#   StrictHostKeyChecking ask/    StrictHostKeyChecking no/g' /etc/ssh/ssh_config
	if ! grep -i "Compression yes" /etc/ssh/ssh_config; then
		echo '    Compression yes' | tee -a /etc/ssh/ssh_config
	fi
	if ! grep -i "UserKnownHostsFile /dev/null" /etc/ssh/ssh_config; then
		echo '    UserKnownHostsFile /dev/null' | tee -a /etc/ssh/ssh_config
	fi
fi
