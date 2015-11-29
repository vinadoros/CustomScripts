#!/bin/bash

# Detect virtualbox.
if grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name"; then
	VBOXGUEST=1
	echo "Virtualbox Detected"
else
	VBOXGUEST=0
	echo "Physical Machine Detected"
fi

#This sets all of the settings in Gnome Shell
if [[ $(type -p geany) ]]; then
	xdg-mime default geany.desktop text/x-shellscript
else
	xdg-mime default org.gnome.gedit.desktop text/x-shellscript
fi
xdg-mime default org.gnome.gedit.desktop text/plain
xdg-mime default org.gnome.Nautilus.desktop inode/directory
gsettings set org.gnome.gedit.preferences.editor create-backup-copy false
sudo gsettings set org.gnome.gedit.preferences.editor create-backup-copy false
gsettings set org.gnome.gedit.preferences.editor display-line-numbers true
sudo gsettings set org.gnome.gedit.preferences.editor display-line-numbers true
gsettings set org.gnome.gedit.preferences.editor highlight-current-line true
gsettings set org.gnome.gedit.preferences.editor bracket-matching true
gsettings set org.gnome.gedit.preferences.editor auto-indent true
gsettings set org.gnome.gedit.preferences.editor tabs-size 4
sudo gsettings set org.gnome.gedit.preferences.editor tabs-size 4
gsettings set org.gtk.Settings.FileChooser show-hidden true
sudo gsettings set org.gtk.Settings.FileChooser show-hidden true
gsettings set org.gnome.nautilus.preferences sort-directories-first true
gsettings set org.gnome.nautilus.preferences executable-text-activation ask
gsettings set org.gnome.nautilus.preferences click-policy double
gsettings set org.gnome.nautilus.list-view use-tree-view true
gsettings set org.gnome.nautilus.list-view default-zoom-level small
gsettings set org.gnome.nautilus.icon-view default-zoom-level small
gsettings set org.gnome.nautilus.list-view use-tree-view true
gsettings set org.gnome.nautilus.icon-view captions "['size', 'none', 'none']"
gsettings set org.gnome.desktop.peripherals.touchpad scroll-method edge-scrolling
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
#~ gsettings set org.gnome.settings-daemon.plugins.power critical-battery-action nothing
#~ gsettings set org.gnome.settings-daemon.plugins.power button-power shutdown
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 3600
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
gsettings set org.gnome.desktop.screensaver lock-enabled false
#This code was to change the idle time depending on the display manager (lightdm vs gdm). Right now it does nothing, but I have left it here for future use.
if ls -l /etc/systemd/system/display-manager.service | grep -iq gdm; then
	gsettings set org.gnome.desktop.session idle-delay 300
else
	gsettings set org.gnome.desktop.session idle-delay 300
fi
if [ $VBOXGUEST = 1 ]; then
	gsettings set org.gnome.desktop.session idle-delay 0
fi
gsettings set org.gnome.settings-daemon.plugins.xsettings antialiasing rgba
gsettings set org.gnome.settings-daemon.plugins.xsettings hinting full
gsettings set org.gnome.desktop.interface text-scaling-factor 0.9
gsettings set org.gnome.desktop.interface clock-show-date true
gsettings set org.gnome.shell enabled-extensions "['places-menu@gnome-shell-extensions.gcampax.github.com', 'window-list@gnome-shell-extensions.gcampax.github.com', 'activities-config@nls1729', 'dash-to-dock@micxgx.gmail.com', 'AdvancedVolumeMixer@harry.karvonen.gmail.com', 'GPaste@gnome-shell-extensions.gnome.org', 'mediaplayer@patapon.info', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'shell-volume-mixer@derhofbauer.at', 'topIcons@adel.gadllah@gmail.com']"
gsettings set org.gnome.desktop.wm.preferences button-layout :minimize,maximize,close
gsettings set org.gnome.settings-daemon.peripherals.mouse locate-pointer false
gsettings set org.gnome.desktop.background show-desktop-icons true
gsettings set org.gnome.desktop.datetime automatic-timezone true
gsettings set org.gnome.desktop.interface clock-format 12h
gsettings set org.gnome.desktop.interface clock-show-date true
gsettings set org.gnome.desktop.interface gtk-theme Adwaita
gsettings set org.gnome.desktop.wm.preferences theme Adwaita
gsettings set org.gnome.desktop.interface icon-theme Numix-Circle
gsettings set org.gnome.desktop.thumbnail-cache maximum-size 100
gsettings set org.gnome.desktop.thumbnail-cache maximum-age 90
gsettings set org.gnome.shell.overrides workspaces-only-on-primary false
gsettings set org.gnome.FileRoller.UI view-sidebar true
gsettings set org.gnome.FileRoller.FileSelector show-hidden true
gsettings set org.gnome.FileRoller.General compression-level maximum
gsettings set org.gnome.gnome-system-monitor show-whose-processes all
gsettings set org.freedesktop.Tracker.Miner.Files crawling-interval -2
gsettings set org.freedesktop.Tracker.Miner.Files enable-monitors false
dconf write /org/gnome/shell/extensions/dash-to-dock/intellihide "true"
dconf write /org/gnome/shell/extensions/dash-to-dock/intellihide-mode 'ALL_WINDOWS'
dconf write /org/gnome/shell/extensions/window-list/show-on-all-monitors "true"

#This section enabled the custom keybindings, and creates the required turnoffscreen script.
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>e'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'gnome-control-center display'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Gnome Display Settings'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ binding '<Super>q'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ name 'Turn off screen'
if [ ! -f /usr/local/bin/turnoffscreen.sh ]; then
	echo -e '#!/bin/bash'"\n"'sleep 1s'"\n"'xset dpms force off' | sudo tee -a /usr/local/bin/turnoffscreen.sh
	sudo chmod a+rwx /usr/local/bin/turnoffscreen.sh
fi
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ command /usr/local/bin/turnoffscreen.sh
