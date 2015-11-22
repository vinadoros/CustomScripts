#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

if [ -z "$1" ]; then
	echo "Error, no interface selected. Exiting."
	exit 1;
else
	IFACE="$1"
	echo "Using ${IFACE} as interface."
fi

# Install ethtool if not present.
[[ ! $(type -P ethtool) && $(type -P pacman) ]] && pacman -Syu --needed --noconfirm ethtool

set -eu

ethtool ${IFACE}

echo ""
read -p "Press any key to create service and script."

echo "Creating /etc/systemd/system/wol${IFACE}.service"
cat >/etc/systemd/system/wol${IFACE}.service <<EOL
[Unit]
Description=Wake-on-LAN for enp2s0
Requires=network.target
After=network.target nss-lookup.target network-online.target graphical.target

[Service]
Type=simple
ExecStart=/usr/local/bin/wol${IFACE}.sh
Restart=on-failure

[Install]
RequiredBy=network.target
EOL
systemctl daemon-reload
systemctl enable wol${IFACE}.service

echo "Creating /usr/local/bin/wol${IFACE}.sh"
cat >/usr/local/bin/wol${IFACE}.sh <<EOL
#!/bin/bash

looptool () {
	sleep 10
	while ! ethtool ${IFACE} | grep -iq "Wake-on: g"; do
		sleep 5
		/usr/bin/ethtool -s ${IFACE} wol g
		sleep 10
		/usr/bin/ethtool -s ${IFACE} wol g
	done
	ethtool ${IFACE} | grep -i wake-on
	exit 0
}

nonlooptool () {
	/usr/bin/ethtool -s ${IFACE} wol g
	ethtool ${IFACE} | grep -i wake-on
	exit 0
}

case "\$1" in
  "pre")
	echo "Running pre-case for wol script."
	# This seems to freeze the network adapters, may need fixing later.
	#~ nonlooptool
    ;;
  "post")
	echo "Running post-case for wol script."
	#~ looptool
	systemctl restart wol${IFACE}.service
    ;;
  *)
	looptool
    ;;
esac

EOL
chmod a+rwx /usr/local/bin/wol${IFACE}.sh
if [ -d /usr/lib/systemd/system-sleep ]; then
	ln -sf /usr/local/bin/wol${IFACE}.sh /usr/lib/systemd/system-sleep/
fi
