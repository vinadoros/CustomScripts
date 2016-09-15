#!/bin/bash

# Detect virtualbox.
if grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name"; then
	VBOXGUEST=1
	echo "Virtualbox Detected"
else
	VBOXGUEST=0
	echo "Physical Machine Detected"
fi

#This sets all of the settings in MATE
xdg-mime default caja-browser.desktop inode/directory
if [[ $(type -p atom) ]]; then
	xdg-mime default atom.desktop text/x-shellscript
elif [[ $(type -p geany) ]]; then
	xdg-mime default geany.desktop text/x-shellscript
else
	xdg-mime default pluma.desktop text/x-shellscript
fi
xdg-mime default pluma.desktop text/plain
gsettings set org.mate.pluma create-backup-copy false
sudo gsettings set org.mate.pluma create-backup-copy false
gsettings set org.mate.pluma display-line-numbers true
sudo gsettings set org.mate.pluma display-line-numbers true
gsettings set org.mate.pluma highlight-current-line true
gsettings set org.mate.pluma bracket-matching true
gsettings set org.mate.pluma auto-indent true
gsettings set org.mate.pluma tabs-size 4
sudo gsettings set org.mate.pluma tabs-size 4
gsettings set org.gtk.Settings.FileChooser show-hidden true
sudo gsettings set org.gtk.Settings.FileChooser show-hidden true
gsettings set org.mate.caja.preferences sort-directories-first true
gsettings set org.mate.caja.preferences executable-text-activation ask
gsettings set org.mate.caja.preferences enable-delete true
gsettings set org.mate.caja.preferences click-policy double
gsettings set org.mate.caja.list-view default-zoom-level smaller
gsettings set org.mate.caja.preferences preview-sound 'never'
gsettings set org.mate.caja.preferences show-advanced-permissions true
sudo gsettings set org.mate.caja.preferences show-advanced-permissions true
gsettings set org.mate.caja.preferences show-hidden-files true
sudo gsettings set org.mate.caja.preferences show-hidden-files true
gsettings set org.mate.caja.preferences use-iec-units true
gsettings set org.mate.peripherals-touchpad scroll-method 1
gsettings set org.mate.peripherals-touchpad disable-while-typing true
gsettings set org.mate.peripherals-touchpad tap-to-click true
gsettings set org.mate.peripherals-touchpad horiz-scroll-enabled true
gsettings set org.mate.power-manager idle-dim-ac false
gsettings set org.mate.power-manager button-lid-ac blank
gsettings set org.mate.power-manager button-lid-battery blank
gsettings set org.mate.power-manager button-power shutdown
gsettings set org.mate.power-manager button-suspend suspend
if [ $VBOXGUEST = 1 ]; then
	gsettings set org.mate.power-manager sleep-display-ac 0
else
	gsettings set org.mate.power-manager sleep-display-ac 300
fi
gsettings set org.mate.power-manager sleep-display-battery 300
#~ gsettings set org.mate.power-manager spindown-enable-battery true
gsettings set org.mate.power-manager action-critical-battery nothing
gsettings set org.mate.screensaver idle-activation-enabled false
gsettings set org.mate.screensaver lock-enabled false
gsettings set org.mate.screensaver mode blank-only
gsettings set org.mate.font-rendering antialiasing grayscale
gsettings set org.mate.font-rendering hinting slight
gsettings set org.mate.peripherals-mouse middle-button-enabled true
dconf write /org/mate/panel/objects/clock/prefs/format "'12-hour'"
dconf write /org/mate/panel/objects/clock/position "0"
dconf write /org/mate/panel/objects/clock/panel-right-stick "true"
dconf write /org/mate/panel/objects/clock/locked "true"
dconf write /org/mate/panel/objects/notification-area/position "10"
dconf write /org/mate/panel/objects/notification-area/panel-right-stick "true"
dconf write /org/mate/panel/objects/notification-area/locked "true"
#~ gsettings set org.mate.Marco.general compositing-manager true
gsettings set org.mate.Marco.general side-by-side-tiling true
if [ ! -f /usr/local/bin/turnoffscreen.sh ]; then
	echo -e '#!/bin/bash'"\n"'sleep 1s'"\n"'xset dpms force off' | sudo tee -a /usr/local/bin/turnoffscreen.sh
	sudo chmod 777 /usr/local/bin/turnoffscreen.sh
	sudo chmod +x /usr/local/bin/turnoffscreen.sh
fi
BINDING="custom2"
dconf write /org/mate/desktop/keybindings/$BINDING/action "'/usr/local/bin/turnoffscreen.sh'"
dconf write /org/mate/desktop/keybindings/$BINDING/binding "'<Mod4>q'"
dconf write /org/mate/desktop/keybindings/$BINDING/name "'turnoffscreen'"

# Icon theme
gsettings set org.mate.interface icon-theme "Numix-Circle-Light"
