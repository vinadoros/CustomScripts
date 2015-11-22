#!/bin/bash
set -eu

# Used following links for this:
# http://atterer.org/mythtv-xmbc-remote-control-without-lirc#edit
# http://ubuntuforums.org/showthread.php?t=2205263
# https://forum.manjaro.org/index.php?topic=2029.0
# Can use "/usr/bin/ir-keytable -t -w /etc/rc_keymaps/rc6_mce -p RC6" to test the key map.

if [ ! -d /etc/udev/rules.d/ ]; then
	exit 1;
fi

if [ ! -d /etc/rc_keymaps/ ]; then
	exit 1;
fi

sudo bash -c "cat >/etc/rc_keymaps/rc6_mce" <<'EOL'
# table rc6_mce, type: RC6
0x800f0400 KEY_NUMERIC_0
0x800f0401 KEY_NUMERIC_1
0x800f0402 KEY_NUMERIC_2
0x800f0403 KEY_NUMERIC_3
0x800f0404 KEY_NUMERIC_4
0x800f0405 KEY_NUMERIC_5
0x800f0406 KEY_NUMERIC_6
0x800f0407 KEY_NUMERIC_7
0x800f0408 KEY_NUMERIC_8
0x800f0409 KEY_NUMERIC_9
0x800f040a KEY_DELETE
0x800f040b KEY_ENTER
0x800f040c KEY_SLEEP
0x800f040d KEY_MEDIA
0x800f040e KEY_MUTE
#0x800f040f KEY_INFO
0x800f040f KEY_F
0x800f0410 KEY_VOLUMEUP
0x800f0411 KEY_VOLUMEDOWN
0x800f0412 KEY_CHANNELUP
0x800f0413 KEY_CHANNELDOWN
0x800f0414 KEY_FASTFORWARD
0x800f0415 KEY_REWIND
0x800f0416 KEY_PLAY
0x800f0417 KEY_RECORD
0x800f0418 KEY_PAUSE
0x800f0419 KEY_STOP
0x800f041a KEY_NEXT
0x800f041b KEY_PREVIOUS
0x800f041c KEY_NUMERIC_POUND
0x800f041d KEY_NUMERIC_STAR
0x800f041e KEY_UP
0x800f041f KEY_DOWN
0x800f0420 KEY_LEFT
0x800f0421 KEY_RIGHT
#0x800f0422 KEY_OK
0x800f0422 KEY_SPACE
0x800f0423 KEY_EXIT
0x800f0424 KEY_DVD
0x800f0425 KEY_TUNER
0x800f0426 KEY_EPG
0x800f0427 KEY_ZOOM
0x800f0432 KEY_MODE
0x800f0433 KEY_PRESENTATION
0x800f0434 KEY_EJECTCD
0x800f043a KEY_BRIGHTNESSUP
0x800f0446 KEY_TV
0x800f0447 KEY_AUDIO
0x800f0448 KEY_PVR
0x800f0449 KEY_CAMERA
0x800f044a KEY_VIDEO
0x800f044c KEY_LANGUAGE
0x800f044d KEY_TITLE
0x800f044e KEY_PRINT
0x800f0450 KEY_RADIO
0x800f045a KEY_SUBTITLE
0x800f045b KEY_RED
0x800f045c KEY_GREEN
0x800f045d KEY_YELLOW
0x800f045e KEY_BLUE
0x800f0465 KEY_POWER2
0x800f046e KEY_PLAYPAUSE
0x800f046f KEY_PLAYER
0x800f0480 KEY_BRIGHTNESSDOWN
0x800f0481 KEY_PLAYPAUSE
EOL
	
if [ ! -f /etc/rc_keymaps/rc6_mce ]; then
	echo "Error."
	exit 1;
fi
sudo chmod 644 /etc/rc_keymaps/rc6_mce

#Command to find info from udev (in bash): udevadm info -a -p $(udevadm info -q path -n /dev/sdX)
sudo bash -c "cat >/etc/udev/rules.d/99-mceusb.rules" <<'EOL'
KERNEL=="event[0-9]*", SUBSYSTEM=="input", SUBSYSTEMS=="usb", ATTRS{idVendor}=="0609", ATTRS{serial}=="SM007hKs", ACTION=="add", RUN+="/usr/local/bin/ir.sh"
EOL

if [ ! -f /etc/udev/rules.d/99-mceusb.rules ]; then
	echo "Error."
	exit 1;
fi
sudo chmod 644 /etc/udev/rules.d/99-mceusb.rules

sudo bash -c "cat >/usr/local/bin/ir.sh" <<'EOL'
#!/bin/bash
( sleep 5 && /usr/bin/ir-keytable -w /etc/rc_keymaps/rc6_mce -p RC6 ) &
exit
EOL

if [ ! -f /usr/local/bin/ir.sh ]; then
	echo "Error."
	exit 1;
fi
sudo chmod +x /usr/local/bin/ir.sh

sudo udevadm control --reload
sudo udevadm trigger
echo "Script Completed Successfully."
