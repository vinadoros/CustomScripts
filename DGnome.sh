#!/bin/bash

# Detect virtualbox.
[ -z $VBOXGUEST ] && grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=1
[ -z $VBOXGUEST ] && ! grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=0
[ -z $QEMUGUEST ] && grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=1
[ -z $QEMUGUEST ] && ! grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=0
[ -z $VMWGUEST ] && grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=1
[ -z $VMWGUEST ] && ! grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=0

#This sets all of the settings in Gnome Shell
if [[ $(type -p atom) ]]; then
	xdg-mime default atom.desktop text/x-shellscript
elif [[ $(type -p geany) ]]; then
	xdg-mime default geany.desktop text/x-shellscript
else
	xdg-mime default org.gnome.gedit.desktop text/x-shellscript
fi
xdg-mime default org.gnome.gedit.desktop text/plain
xdg-mime default org.gnome.Nautilus.desktop inode/directory
gsettings set org.gnome.gedit.preferences.editor create-backup-copy false
gsettings set org.gnome.gedit.preferences.editor display-line-numbers true
gsettings set org.gnome.gedit.preferences.editor highlight-current-line true
gsettings set org.gnome.gedit.preferences.editor bracket-matching true
gsettings set org.gnome.gedit.preferences.editor auto-indent true
gsettings set org.gnome.gedit.preferences.editor tabs-size 4
gsettings set org.gtk.Settings.FileChooser show-hidden true
gsettings set org.gtk.Settings.FileChooser sort-directories-first true
gsettings set org.gnome.nautilus.preferences sort-directories-first true
gsettings set org.gnome.nautilus.preferences executable-text-activation ask
gsettings set org.gnome.nautilus.preferences click-policy double
gsettings set org.gnome.nautilus.preferences automatic-decompression false
gsettings set org.gnome.nautilus.list-view use-tree-view true
gsettings set org.gnome.nautilus.list-view default-zoom-level small
gsettings set org.gnome.nautilus.icon-view default-zoom-level small
gsettings set org.gnome.nautilus.list-view use-tree-view true
gsettings set org.gnome.nautilus.icon-view captions "['size', 'none', 'none']"
gsettings set org.gnome.desktop.peripherals.touchpad scroll-method edge-scrolling
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 3600
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
gsettings set org.gnome.desktop.screensaver lock-enabled false
if [[ $VBOXGUEST = 1 || $QEMUGUEST = 1 || $VMWGUEST = 1 ]]; then
	gsettings set org.gnome.desktop.session idle-delay 0
else
	gsettings set org.gnome.desktop.session idle-delay 300
fi
gsettings set org.gnome.settings-daemon.plugins.xsettings antialiasing grayscale
gsettings set org.gnome.settings-daemon.plugins.xsettings hinting slight
gsettings set org.gnome.desktop.interface text-scaling-factor 1.0
gsettings set org.gnome.desktop.interface clock-show-date true
gsettings set org.gnome.shell enabled-extensions "['places-menu@gnome-shell-extensions.gcampax.github.com', 'window-list@gnome-shell-extensions.gcampax.github.com', 'activities-config@nls1729', 'dash-to-dock@micxgx.gmail.com', 'AdvancedVolumeMixer@harry.karvonen.gmail.com', 'GPaste@gnome-shell-extensions.gnome.org', 'mediaplayer@patapon.info', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'shell-volume-mixer@derhofbauer.at', 'TopIcons@phocean.net']"
gsettings set org.gnome.desktop.wm.preferences button-layout :minimize,maximize,close
gsettings set org.gnome.settings-daemon.peripherals.mouse locate-pointer false
gsettings set org.gnome.desktop.background show-desktop-icons true
gsettings set org.gnome.desktop.datetime automatic-timezone true
gsettings set org.gnome.desktop.interface clock-format 12h
gsettings set org.gnome.desktop.interface clock-show-date true
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
dconf write /org/gnome/shell/extensions/dash-to-dock/intellihide-mode "'ALL_WINDOWS'"
dconf write /org/gnome/shell/extensions/window-list/show-on-all-monitors "true"
# Set gnome-terminal scrollback
dconf write /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/scrollback-unlimited true
# Set Fonts
gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans 11'
gsettings set org.gnome.desktop.interface font-name 'Ubuntu 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Liberation Mono 11'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Ubuntu Bold 11'

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
