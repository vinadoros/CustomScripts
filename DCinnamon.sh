#!/bin/bash

# Detect virtualbox.
if grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name"; then
	VBOXGUEST=1
	echo "Virtualbox Detected"
else
	VBOXGUEST=0
	echo "Physical Machine Detected"
fi

#This sets all of the settings in Cinnamon
xdg-mime default nemo.desktop inode/directory
#To find out default file manager:
#xdg-mime query default inode/directory
gsettings set org.cinnamon cinnamon-settings-advanced true
gsettings set org.cinnamon overview-corner "['expo:false:false', 'scale:false:false', 'scale:true:false', 'desktop:false:false']"
#gsettings set org.cinnamon enabled-applets "['panel1:left:0:menu@cinnamon.org:0', 'panel1:left:2:panel-launchers@cinnamon.org:2', 'panel1:right:0:notifications@cinnamon.org:4', 'panel1:right:0:multicore-sys-monitor@ccadeptic23:15', 'panel1:right:1:user@cinnamon.org:5', 'panel1:right:2:removable-drives@cinnamon.org:6', 'panel1:right:5:network@cinnamon.org:9', 'panel1:right:6:sound@cinnamon.org:10', 'panel1:right:7:power@cinnamon.org:11', 'panel1:right:8:systray@cinnamon.org:12', 'panel1:right:9:calendar@cinnamon.org:13', 'panel1:right:10:windows-quick-list@cinnamon.org:14', 'panel2:left:0:window-list@cinnamon.org:20']"
#gsettings set org.cinnamon favorite-apps "['google-chrome.desktop', 'evolution.desktop', 'nemo.desktop', 'gnome-terminal.desktop', 'banshee.desktop', 'virtualbox.desktop', 'vmware-workstation.desktop', 'cinnamon-settings.desktop']"
gsettings set org.cinnamon.desktop.interface clock-use-24h false
gsettings set org.cinnamon.desktop.screensaver lock-enabled false
gsettings set org.cinnamon.settings-daemon.peripherals.touchpad disable-while-typing true
gsettings set org.cinnamon.settings-daemon.peripherals.touchpad horiz-scroll-enabled true
gsettings set org.cinnamon.settings-daemon.plugins.power button-power 'shutdown'
gsettings set org.cinnamon.settings-daemon.plugins.power critical-battery-action 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power lid-close-ac-action 'blank'
gsettings set org.cinnamon.settings-daemon.plugins.power lid-close-battery-action 'blank'
if [ $VBOXGUEST = 0 ]; then
	gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 300
	gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-battery 300
else
	gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0
	gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-battery 0
fi
gsettings set org.nemo.desktop computer-icon-visible true
gsettings set org.nemo.desktop home-icon-visible true
gsettings set org.nemo.desktop network-icon-visible true
gsettings set org.nemo.desktop trash-icon-visible true
gsettings set org.nemo.desktop volumes-visible true
gsettings set org.nemo.preferences show-advanced-permissions true
gsettings set org.nemo.preferences show-hidden-files true
gsettings set org.nemo.icon-view captions "['size', 'none', 'none']"
gsettings set org.nemo.preferences quick-renames-with-pause-in-between true
gsettings set org.nemo.preferences show-open-in-terminal-toolbar true
gsettings set org.nemo.preferences show-reload-icon-toolbar true


gsettings set org.cinnamon.muffin tile-maximize true
gsettings set org.cinnamon.desktop.interface icon-theme 'Numix-Circle'


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
gsettings set org.gnome.FileRoller.UI view-sidebar true
gsettings set org.gnome.FileRoller.FileSelector show-hidden true
gsettings set org.gnome.FileRoller.General compression-level maximum
sudo gsettings set org.gtk.Settings.FileChooser show-hidden true

#This section enabled the custom keybindings, and creates the required turnoffscreen script.
#Reference: http://askubuntu.com/questions/425730/how-to-add-a-key-to-an-empty-schema
gsettings set org.cinnamon.desktop.keybindings custom-list "['custom0', 'custom1']"
if [ ! -f /usr/local/bin/turnoffscreen.sh ]; then
	echo -e '#!/bin/bash'"\n"'sleep 1s'"\n"'xset dpms force off' | sudo tee -a /usr/local/bin/turnoffscreen.sh
	sudo chmod 777 /usr/local/bin/turnoffscreen.sh
	sudo chmod +x /usr/local/bin/turnoffscreen.sh
fi
gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/ binding "['<Super>q']"
gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/ name 'Turn off screen'
gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/ command /usr/local/bin/turnoffscreen.sh

gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom1/ binding "['<Super>w']"
gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom1/ command 'cinnamon-settings display'
gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom1/ name 'Cinnamon Display Settings'

