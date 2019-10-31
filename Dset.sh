#!/bin/bash

if [ "$(id -u)" = "0" ]; then
	echo "Running with root. Please run the script as a normal user."
	exit 1;
fi

# Detect virtualbox.
[ -z $VBOXGUEST ] && grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=1
[ -z $VBOXGUEST ] && ! grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=0
[ -z $QEMUGUEST ] && grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=1
[ -z $QEMUGUEST ] && ! grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=0
[ -z $VMWGUEST ] && grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=1
[ -z $VMWGUEST ] && ! grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=0

# Common settings
if type code; then
	xdg-mime default code.desktop text/x-shellscript
	xdg-mime default code.desktop text/plain
elif type atom; then
	xdg-mime default atom.desktop text/x-shellscript
	xdg-mime default atom.desktop text/plain
fi

# Commented statements to set default text editor
# xdg-mime default pluma.desktop text/plain
# Commented statements to set default file manager
# xdg-mime default nemo.desktop inode/directory
# xdg-mime default caja-browser.desktop inode/directory
# xdg-mime default org.gnome.Nautilus.desktop inode/directory
#To find out default file manager:
#xdg-mime query default inode/directory

# If /usr/local/bin is not writeable by this user, make it writeable.
if ! test -w /usr/local/bin/; then
	sudo chmod a+rwx /usr/local/bin/
fi
if [ ! -f /usr/local/bin/turnoffscreen.sh ]; then
	echo -e '#!/bin/bash'"\n"'sleep 1s'"\n"'xset dpms force off' | sudo tee /usr/local/bin/turnoffscreen.sh
	sudo chmod a+x /usr/local/bin/turnoffscreen.sh
fi

# Tilix configuration
if type tilix; then
	gsettings set com.gexperts.Tilix.Settings warn-vte-config-issue false
	gsettings set com.gexperts.Tilix.Settings terminal-title-style 'small'
	dconf write /com/gexperts/Tilix/profiles/2b7c4080-0ddd-46c5-8f23-563fd3ba789d/login-shell true
	dconf write /com/gexperts/Tilix/profiles/2b7c4080-0ddd-46c5-8f23-563fd3ba789d/scrollback-unlimited true
	dconf write /com/gexperts/Tilix/profiles/2b7c4080-0ddd-46c5-8f23-563fd3ba789d/terminal-bell "'icon'"
	dconf write /com/gexperts/Tilix/profiles/2b7c4080-0ddd-46c5-8f23-563fd3ba789d/use-theme-colors false
	dconf write /com/gexperts/Tilix/profiles/2b7c4080-0ddd-46c5-8f23-563fd3ba789d/background-color "'#263238'"
	dconf write /com/gexperts/Tilix/profiles/2b7c4080-0ddd-46c5-8f23-563fd3ba789d/foreground-color "'#A1B0B8'"
	dconf write /com/gexperts/Tilix/profiles/2b7c4080-0ddd-46c5-8f23-563fd3ba789d/palette "['#252525', '#FF5252', '#C3D82C', '#FFC135', '#42A5F5', '#D81B60', '#00ACC1', '#F5F5F5', '#708284', '#FF5252', '#C3D82C', '#FFC135', '#42A5F5', '#D81B60', '#00ACC1', '#F5F5F5']"
	# Fish config for tilix
	if type fish &> /dev/null; then
		dconf write /com/gexperts/Tilix/profiles/2b7c4080-0ddd-46c5-8f23-563fd3ba789d/use-custom-command true
		dconf write /com/gexperts/Tilix/profiles/2b7c4080-0ddd-46c5-8f23-563fd3ba789d/custom-command \'$(which fish)\'
	fi
fi

# Terminator configuration
if type terminator; then
	TERMCONFIG="$HOME/.config/terminator/config"
	TERMCONFIGDIR="$(dirname $TERMCONFIG)"
	if [ ! -d "$TERMCONFIGDIR" ]; then
		echo "Creating $TERMCONFIGDIR"
		mkdir -p "$TERMCONFIGDIR"
	fi
	if [ ! -f "$TERMCONFIG" ]; then
		echo "Creating $TERMCONFIG"
		bash -c "cat >>$TERMCONFIG" <<'EOL'
[profiles]
	[[default]]
		font = Liberation Mono 11
		scrollback_infinite = True
		scroll_on_output = False
		use_system_font = False
		use_theme_colors = True
EOL
	fi
fi


# MATE specific settings
if type mate-session; then
	gsettings set org.mate.pluma create-backup-copy false
	gsettings set org.mate.pluma display-line-numbers true
	gsettings set org.mate.pluma highlight-current-line true
	gsettings set org.mate.pluma bracket-matching true
	gsettings set org.mate.pluma auto-indent true
	gsettings set org.mate.pluma tabs-size 4
	gsettings set org.gtk.Settings.FileChooser show-hidden true
	gsettings set org.mate.caja.preferences executable-text-activation ask
	gsettings set org.mate.caja.preferences enable-delete true
	gsettings set org.mate.caja.preferences click-policy double
	gsettings set org.mate.caja.list-view default-zoom-level smaller
	gsettings set org.mate.caja.preferences preview-sound 'never'
	gsettings set org.mate.caja.preferences show-advanced-permissions true
	gsettings set org.mate.caja.preferences show-hidden-files true
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
	if [[ $VBOXGUEST = 1 || $QEMUGUEST = 1 || $VMWGUEST = 1 ]]; then
		gsettings set org.mate.power-manager sleep-display-ac 0
	else
		gsettings set org.mate.power-manager sleep-display-ac 300
	fi
	gsettings set org.mate.power-manager sleep-display-battery 300
	gsettings set org.mate.power-manager action-critical-battery nothing
	gsettings set org.mate.screensaver idle-activation-enabled false
	gsettings set org.mate.screensaver lock-enabled false
	gsettings set org.mate.screensaver mode blank-only
	gsettings set org.mate.font-rendering antialiasing grayscale
	gsettings set org.mate.font-rendering hinting slight
	gsettings set org.mate.peripherals-mouse middle-button-enabled true
	dconf write /org/mate/terminal/profiles/default/scrollback-unlimited true
	dconf write /org/mate/panel/objects/clock/prefs/format "'12-hour'"
	dconf write /org/mate/panel/objects/clock/position "0"
	dconf write /org/mate/panel/objects/clock/panel-right-stick "true"
	dconf write /org/mate/panel/objects/clock/locked "true"
	dconf write /org/mate/panel/objects/notification-area/position "10"
	dconf write /org/mate/panel/objects/notification-area/panel-right-stick "true"
	dconf write /org/mate/panel/objects/notification-area/locked "true"
	gsettings set org.mate.Marco.general side-by-side-tiling true
	# Set Fonts
	gsettings set org.mate.interface document-font-name 'Noto Sans 11'
	gsettings set org.mate.interface font-name 'Roboto 11'
	gsettings set org.mate.interface monospace-font-name 'Liberation Mono 11'
	gsettings set org.mate.Marco.general titlebar-font 'Roboto Bold 11'
	BINDING="custom2"
	dconf write /org/mate/desktop/keybindings/$BINDING/action "'/usr/local/bin/turnoffscreen.sh'"
	dconf write /org/mate/desktop/keybindings/$BINDING/binding "'<Mod4>q'"
	dconf write /org/mate/desktop/keybindings/$BINDING/name "'turnoffscreen'"
	# Icon theme
	gsettings set org.mate.interface icon-theme "Numix-Circle"
	# Fish config for mate-terminal
	if type fish &> /dev/null; then
		dconf write /org/mate/terminal/profiles/default/use-custom-command true
		dconf write /org/mate/terminal/profiles/default/custom-command \'$(which fish)\'
	fi

	# System Monitor applet
	SYSMON_ID="$(dconf read /org/mate/panel/objects/system-monitor/applet-iid)"
	if [[ "$SYSMON_ID" == *"MultiLoadApplet"* ]]; then
		# To find the relocatable schemas: gsettings list-relocatable-schemas
		gsettings set org.mate.panel.applet.multiload:/org/mate/panel/objects/system-monitor/prefs/ speed 1000
		gsettings set org.mate.panel.applet.multiload:/org/mate/panel/objects/system-monitor/prefs/ view-diskload true
		gsettings set org.mate.panel.applet.multiload:/org/mate/panel/objects/system-monitor/prefs/ view-memload true
		gsettings set org.mate.panel.applet.multiload:/org/mate/panel/objects/system-monitor/prefs/ view-netload true
		gsettings set org.mate.panel.applet.multiload:/org/mate/panel/objects/system-monitor/prefs/ view-swapload true
	fi
fi

# PackageKit
# https://ask.fedoraproject.org/en/question/108524/clean-up-packagekit-cache-the-right-way/
gsettings set org.gnome.software download-updates false

# Gnome specific settings
if type gnome-session; then
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
	gsettings set org.gnome.nautilus.list-view use-tree-view true
	gsettings set org.gnome.nautilus.list-view default-zoom-level small
	gsettings set org.gnome.nautilus.icon-view default-zoom-level small
	gsettings set org.gnome.nautilus.list-view use-tree-view true
	gsettings set org.gnome.nautilus.icon-view captions "['size', 'none', 'none']"
	gsettings set org.gnome.nautilus.list-view default-visible-columns "['name', 'size', 'type', 'date_modified']"
	gsettings set org.gnome.nautilus.compression default-compression-format '7z'
	gsettings set org.gnome.desktop.peripherals.touchpad scroll-method edge-scrolling
	gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
	gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
	gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 3600
	gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
	gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800
	gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
	gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'blank'
	gsettings set org.gnome.settings-daemon.plugins.power lid-close-battery-action 'blank'
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
	gsettings set org.gnome.shell enabled-extensions "['window-list@gnome-shell-extensions.gcampax.github.com', 'dash-to-dock@micxgx.gmail.com', 'GPaste@gnome-shell-extensions.gnome.org', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'shell-volume-mixer@derhofbauer.at', 'TopIcons@phocean.net', 'ubuntu-appindicators@ubuntu.com', 'donotdisturb@kylecorry31.github.io']"
	gsettings set org.gnome.desktop.wm.preferences button-layout :minimize,maximize,close
	gsettings set org.gnome.settings-daemon.peripherals.mouse locate-pointer false
	gsettings set org.gnome.desktop.datetime automatic-timezone true
	gsettings set org.gnome.desktop.interface clock-format 12h
	gsettings set org.gnome.desktop.interface clock-show-date true
	gsettings set org.gnome.desktop.interface icon-theme 'Numix-Circle'
	gsettings set org.gnome.desktop.thumbnail-cache maximum-size 100
	gsettings set org.gnome.desktop.thumbnail-cache maximum-age 90
	gsettings set org.gnome.desktop.interface show-battery-percentage true
	gsettings set org.gnome.desktop.interface clock-show-weekday true
	gsettings set org.gnome.shell.overrides workspaces-only-on-primary false
	gsettings set org.gnome.FileRoller.UI view-sidebar true
	gsettings set org.gnome.FileRoller.FileSelector show-hidden true
	gsettings set org.gnome.FileRoller.General compression-level maximum
	gsettings set org.gnome.gnome-system-monitor show-whose-processes all
	gsettings set org.freedesktop.Tracker.Miner.Files crawling-interval -2
	gsettings set org.freedesktop.Tracker.Miner.Files enable-monitors false
	dconf write /org/gnome/shell/extensions/dash-to-dock/intellihide "true"
	dconf write /org/gnome/shell/extensions/dash-to-dock/multi-monitor "true"
	gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true
	gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'
	gsettings set org.gnome.shell.extensions.dash-to-dock intellihide-mode 'FOCUS_APPLICATION_WINDOWS'
	gsettings set org.gnome.shell.extensions.dash-to-dock require-pressure-to-show true
	gsettings set org.gnome.shell.extensions.dash-to-dock icon-size-fixed false
	gsettings set org.gnome.shell.extensions.dash-to-dock isolate-monitors false
	gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
	gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false
	dconf write /org/gnome/shell/extensions/window-list/show-on-all-monitors "true"
	# Set gnome-terminal scrollback
	dconf write /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/scrollback-unlimited true
	# Set Fonts
	gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans 11'
	gsettings set org.gnome.desktop.interface font-name 'Roboto 11'
	gsettings set org.gnome.desktop.interface monospace-font-name 'Liberation Mono 11'
	gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Roboto Bold 11'

	#This section enabled the custom keybindings, and creates the required turnoffscreen script.
	gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/']"
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>e'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'gnome-control-center display'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Gnome Display Settings'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ binding '<Super>w'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ name 'Turn off screen'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ command /usr/local/bin/turnoffscreen.sh
	# Fish config for gnome-terminal
	if type fish &> /dev/null; then
		dconf write /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/use-custom-command true
		dconf write /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/custom-command \'$(which fish)\'
	fi
fi


# KDE/Plasma specific Settings
# https://askubuntu.com/questions/839647/gsettings-like-tools-for-kde#839773
# https://manned.org/kwriteconfig/d47c2de0
if type kwriteconfig5; then
	# Dolphin settings
	if type dolphin; then
		kwriteconfig5 --file dolphinrc --group General --key GlobalViewProps --type bool true
	fi
	# KDE Globals
	kwriteconfig5 --file kdeglobals --group KDE --key SingleClick --type bool false
	kwriteconfig5 --file kdeglobals --group General	--key XftSubPixel "rgb"
	# kwriteconfig5 --file kdeglobals --group General	--key fixed "Liberation Mono,10,-1,5,50,0,0,0,0,0,Regular"
	kwriteconfig5 --file kdeglobals --group Icons --key Theme "Numix-Circle"
	mkdir -p ~/.kde/share/config
	kwriteconfig5 --file ~/.kde/share/config/kdeglobals --group Icons --key Theme "Numix-Circle"
	# Keyboard shortcuts
	kwriteconfig5 --file kglobalshortcutsrc --group kwin --key MoveZoomDown ",Meta+Down,Move Zoomed Area Downwards"
	kwriteconfig5 --file kglobalshortcutsrc --group kwin --key MoveZoomLeft ",Meta+Left,Move Zoomed Area to Left"
	kwriteconfig5 --file kglobalshortcutsrc --group kwin --key MoveZoomRight ",Meta+Right,Move Zoomed Area to Right"
	kwriteconfig5 --file kglobalshortcutsrc --group kwin --key MoveZoomUp ",Meta+Up,Move Zoomed Area Upwards"
	kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Maximize" "Meta+Up\tMeta+Down,none,Maximize Window"
	# Workaround for kwriteconfig escaping \t as \\t. Without quotes, \t is escaped as only t.
	sed -i 's@\\\\t@\\t@g' $HOME/.config/kglobalshortcutsrc
	kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Left" "Meta+Left,none,Quick Tile Window to the Left"
	kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Right" "Meta+Right,none,Quick Tile Window to the Right"
	kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Show Desktop" "Meta+m,none,Show Desktop"
	# Lock Screen and Power Management
	if [[ $VBOXGUEST = 1 || $QEMUGUEST = 1 || $VMWGUEST = 1 ]]; then
		kwriteconfig5 --file powermanagementprofilesrc --group AC --group DPMSControl --key idleTime 300000
	else
		kwriteconfig5 --file powermanagementprofilesrc --group AC --group DPMSControl --key idleTime 600
	fi
	kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock --type bool false
	kwriteconfig5 --file kscreenlockerrc --group Daemon --key LockOnResume --type bool false
	kwriteconfig5 --file kscreenlockerrc --group Daemon --key Timeout 10
	kwriteconfig5 --file ksmserverrc --group General --key confirmLogout false
	kwriteconfig5 --file ksmserverrc --group General --key offerShutdown true
	kwriteconfig5 --file konsolerc --group "Desktop Entry" --key DefaultProfile "Profile 1.profile"
	mkdir -p ~/.local/share/konsole
	kwriteconfig5 --file "~/.local/share/konsole/Profile 1.profile" --group "General" --key Name "Profile 1"
	kwriteconfig5 --file "~/.local/share/konsole/Profile 1.profile" --group "General" --key Parent "FALLBACK/"
	kwriteconfig5 --file "~/.local/share/konsole/Profile 1.profile" --group "Scrolling" --key HistoryMode 2
	kwriteconfig5 --file "~/.local/share/konsole/Profile 1.profile" --group "Appearance" --key ColorScheme Solarized
	kwriteconfig5 --file "~/.local/share/konsole/Profile 1.profile" --group "Appearance" --key Font "Liberation Mono,11,-1,5,50,0,0,0,0,0,Regular"
	

	# gtk3 theme
# 	mkdir -p $HOME/.config/gtk-3.0
# 	kwriteconfig5 --file $HOME/.config/gtk-3.0/settings.ini --group Settings --key gtk-fallback-icon-theme Numix-Light
# 	kwriteconfig5 --file $HOME/.config/gtk-3.0/settings.ini --group Settings --key gtk-font-name "Noto Sans Regular 10"
# 	kwriteconfig5 --file $HOME/.config/gtk-3.0/settings.ini --group Settings --key gtk-icon-theme-name Numix-Circle-Light
# 	kwriteconfig5 --file $HOME/.config/gtk-3.0/settings.ini --group Settings --key gtk-cursor-theme-name breeze_cursors
# 	kwriteconfig5 --file $HOME/.config/gtk-3.0/settings.ini --group Settings --key gtk-menu-images 1
# 	kwriteconfig5 --file $HOME/.config/gtk-3.0/settings.ini --group Settings --key gtk-button-images 1
# 	kwriteconfig5 --file $HOME/.config/gtk-3.0/settings.ini --group Settings --key gtk-theme-name Breeze
# 	# gtk2 theme
# 	cat >"$HOME/.gtkrc-2.0" <<'EOFXYZ'
# # File created by KDE Gtk Config
# # Configs for GTK2 programs
#
# include "/usr/share/themes/Breeze/gtk-2.0/gtkrc"
# style "user-font"
# {
# 	font_name="Noto Sans Regular"
# }
# widget_class "*" style "user-font"
# gtk-font-name="Noto Sans Regular 10"
# gtk-theme-name="Breeze"
# gtk-icon-theme-name="Numix-Circle-Light"
# gtk-fallback-icon-theme="Numix-Light"
# gtk-cursor-theme-name="breeze_cursors"
# gtk-toolbar-style=GTK_TOOLBAR_ICONS
# gtk-menu-images=1
# gtk-button-images=1
# gtk-primary-button-warps-slider=0
# EOFXYZ
# 	ln -sf $HOME/.gtkrc-2.0 $HOME/.gtkrc-2.0-kde4

	# Fish config for konsole
	if type fish &> /dev/null; then
		kwriteconfig5 --file konsolerc --group "Desktop Entry" --key DefaultProfile "Profile 1.profile"
		mkdir -p ~/.local/share/konsole
		kwriteconfig5 --file "~/.local/share/konsole/Profile 1.profile" --group "General" --key Name "Profile 1"
		kwriteconfig5 --file "~/.local/share/konsole/Profile 1.profile" --group "General" --key Parent "FALLBACK/"
		kwriteconfig5 --file "~/.local/share/konsole/Profile 1.profile" --group "General" --key Command "$(which fish)"
	fi

	if type qdbus; then
		# Reload kwin.
		qdbus org.kde.KWin /KWin reconfigure
	fi
fi

# Xfce settings
if type xfconf-query; then
	xfconf-query -c xsettings -p /Net/IconThemeName -s "Numix-Circle"
	xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita"
	xfconf-query -c xfwm4 -p /general/workspace_count -s 1
	xfconf-query -c xfwm4 -p /general/theme -s "Arc-Darker"
	# Launch Gnome services (for keyring)
	xfconf-query -c xfce4-session -p /compat/LaunchGNOME -t bool -s true --create
	# Keyboard Shortcuts
	xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/Super_L -t string -s /usr/bin/xfce4-popup-whiskermenu -n
	xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/Print -t string -s "xfce4-screenshooter" -n
	# Lock Screen and Power Management
	if [[ $VBOXGUEST = 1 || $QEMUGUEST = 1 || $VMWGUEST = 1 ]]; then
		xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-ac --type int --set 0 --create
		xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-on-ac-off --type int --set 0 --create
		xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-on-ac-sleep --type int --set 0 --create
		# Disable xscreensaver.
		# TODO: Change this to xfce screensaver app later.
		echo -e 'mode:\t\toff\n' > "$HOME/.xscreensaver"
	else
		xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-ac --type int --set 10 --create
		xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-on-ac-off --type int --set 10 --create
		xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-on-ac-sleep --type int --set 10 --create
	fi

	# Thunar settings
	xfconf-query -c xfce4-panel -p /default-view --type string --set "ThunarDetailsView" --create
	xfconf-query -c xfce4-panel -p /last-view --type string --set "ThunarDetailsView" --create
	xfconf-query -c xfce4-panel -p /last-icon-view-zoom-level --type string --set "THUNAR_ZOOM_LEVEL_75_PERCENT" --create
	xfconf-query -c xfce4-panel -p /last-show-hidden --type bool --set true --create
	xfconf-query -c xfce4-panel -p /misc-show-delete-action --type bool --set true --create
	xfconf-query -c xfce4-panel -p /misc-single-click --type bool --set false --create
	xfconf-query -c xfce4-panel -p /misc-middle-click-in-tab --type bool --set true --create

	# List panels
	# xfconf-query -c xfce4-panel -p /panels -lv
	# Setup 2 panels
	xfconf-query -c xfce4-panel -p /panels -t int -s 1 -t int -s 2 -a
	# Panel settings
	xfconf-query -c xfce4-panel -p /panels/panel-1/length --type int --set 100 --create
	xfconf-query -c xfce4-panel -p /panels/panel-2/length --type int --set 100 --create
	xfconf-query -c xfce4-panel -p /panels/panel-1/size  --type int --set 20 --create
	xfconf-query -c xfce4-panel -p /panels/panel-2/size  --type int --set 20 --create
	xfconf-query -c xfce4-panel -p /panels/panel-1/position-locked --type bool --set true --create
	xfconf-query -c xfce4-panel -p /panels/panel-2/position-locked --type bool --set true --create
	xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior --type int --set 0 --create
	xfconf-query -c xfce4-panel -p /panels/panel-2/autohide-behavior --type int --set 0 --create
	# Put panel 1 on the top of the screen
	xfconf-query -c xfce4-panel -p /panels/panel-1/position --type string --set "p=6;x=0;y=0" --create
	# Put panel 2 on the bottom of the screen
	xfconf-query -c xfce4-panel -p /panels/panel-2/position --type string --set "p=10;x=0;y=0" --create
	# Create plugin ids
	xfconf-query -c xfce4-panel -p /plugins/plugin-1 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-2 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-3 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-4 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-5 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-6 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-7 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-8 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-9 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-10 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-11 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-12 --type string --set "whiskermenu" --create

	# List plugins
	# xfconf-query -c xfce4-panel -p /plugins -lv
	# Delete all existing plugin ids
	xfconf-query -c xfce4-panel -p /plugins --reset --recursive
	# Recreate plugin ids
	xfconf-query -c xfce4-panel -p /plugins/plugin-1 --type string --set "applicationsmenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-2 --type string --set "actions" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-3 --type string --set "tasklist" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-5 --type string --set "clock" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-5/digital-format --type string --set "%a %b %d | %r" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-6 --type string --set "systray" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-7 --type string --set "showdesktop" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-8 --type string --set "separator" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-9 --type string --set "whiskermenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-10 --type string --set "directorymenu" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-10/base-directory --type string --set "$HOME" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-11 --type string --set "separator" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-11/expand --type bool --set true --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-11/style --type int --set 0 --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-12 --type string --set "systemload" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-13 --type string --set "diskperf" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-14 --type string --set "xfce4-clipman-plugin" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-15 --type string --set "pulseaudio" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-20 --type string --set "launcher" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-20/items --type string --set "chromium-browser.desktop" --force-array --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-21 --type string --set "launcher" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-21/items --type string --set "Thunar.desktop" --force-array --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-22 --type string --set "launcher" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-22/items --type string --set "com.gexperts.Tilix.desktop" --force-array --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-23 --type string --set "launcher" --create
	xfconf-query -c xfce4-panel -p /plugins/plugin-23/items --type string --set "xfce4-terminal.desktop" --force-array --create

	# List existing array
	# xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids
	# Delete existing plugin arrays
	xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -rR
	xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids -rR
	# Create plugins for panels
	xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -t int -s 9 -t int -s 1 -t int -s 20 -t int -s 21 -t int -s 22 -t int -s 23 -t int -s 11 -t int -s 12 -t int -s 13 -t int -s 14 -t int -s 15 -t int -s 6 -t int -s 5 -t int -s 2 --force-array --create
	xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids -t int -s 3 --force-array --create

	# Reset the panel
	if pgrep xfce4-panel &> /dev/null; then
		xfce4-panel -r &
	fi
fi

# Firefox profile prefs.
function mod_ff () {
	sed -i 's/user_pref("'$1'",.*);/user_pref("'$1'",'$2');/' prefs.js
	grep -q $1 prefs.js || echo "user_pref(\"$1\",$2);" >> prefs.js
}

# If prefs.js for firefox was created, set the profile information.
firefox_used=false
for profilefolder in ~/.mozilla/firefox/*.default*/; do
	if [ -f "$profilefolder/prefs.js" ]; then
		cd "$profilefolder"
		echo "Editing Firefox preferences in $profilefolder."
		mod_ff "general.autoScroll" "true"
		mod_ff "extensions.pocket.enabled" "false"
		mod_ff "browser.tabs.drawInTitlebar" "true"
		mod_ff "general.warnOnAboutConfig" "false"
		mod_ff "browser.download.useDownloadDir" "false"
		mod_ff "app.shield.optoutstudies.enabled" "false"
		mod_ff "browser.newtabpage.activity-stream.showSponsored" "false"
		# DNS-over-HTTPS
		mod_ff "network.trr.mode" "2"
		mod_ff "network.trr.bootstrapAddress" "1.1.1.1"
		# Disable notifications
		mod_ff "dom.webnotifications.enabled" "false"

		# Install firefox gnome theme.
		if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
			# Clone or update it
			if [ -d "$HOME/firefox-gnome-theme" ]; then
				cd "$HOME/firefox-gnome-theme" && git checkout -f && git pull
			else
				git clone https://github.com/rafaelmardojai/firefox-gnome-theme/ ~/firefox-gnome-theme
			fi
			# Install it
			if cd ~/firefox-gnome-theme; then
				./scripts/install.sh -p "$(basename $profilefolder)"
			fi
		fi
	fi
done


