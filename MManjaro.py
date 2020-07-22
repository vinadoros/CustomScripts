#!/usr/bin/env python3
"""Provision Manjaro."""

# Python includes.
import argparse
import os
import shutil
import subprocess
import sys
# Custom includes
import CFunc
import CFuncExt

# Folder of this script
SCRIPTDIR = sys.path[0]

# Exit if not root.
CFunc.is_root(True)


### Functions ###
def pacman_invoke(options: str):
    """Invoke pacman"""
    subprocess.run("pacman --noconfirm {0}".format(options), shell=True, check=True)
def yay_invoke(run_as_user: str, options: str):
    """Invoke yay as normal user"""
    if shutil.which("yay"):
        CFunc.run_as_user(run_as_user, "yay --noconfirm {0}".format(options))
    else:
        print("ERROR: yay not found. Exiting.")
        sys.exit(1)
def pacman_install(packages: str):
    """Install packages with pacman"""
    pacman_invoke("-S --needed {0}".format(packages))
def pacman_update():
    """Pacman system update"""
    pacman_invoke("-Syu")
def yay_install(run_as_user: str, packages: str):
    """Install packages with yay"""
    yay_invoke(run_as_user, "-S --needed {0}".format(packages))
def sysctl_enable(options):
    """Enable systemctl services"""
    subprocess.run("systemctl enable {0}".format(options), shell=True, check=True)
def lightdm_configure():
    """Configure lightdm"""
    pacman_install("lightdm lightdm-slick-greeter lightdm-settings")
    subprocess.run("sed -i '/^#greeter-session=.*/s/^#//g' /etc/lightdm/lightdm.conf", shell=True, check=True)
    subprocess.run("sed -i 's/^greeter-session=.*/greeter-session=lightdm-slick-greeter/g' /etc/lightdm/lightdm.conf", shell=True, check=True)
    sysctl_enable("-f lightdm")
def kernels_getlist():
    """Get list of all available kernels (non-realtime)."""
    kernelsinrepo_list = subprocess.check_output('pacman -Ssq "^linux[0-9][0-9]?([0-9])$"', shell=True, universal_newlines=True).splitlines()
    return kernelsinrepo_list
    # To get realtime kernels: pacman -Ssq "^linux[0-9][0-9]?([0-9])-rt$"
def kernels_getlatest():
    """Get the latest kernel available. Note, this may be an rc kernel."""
    # The last entry in the list is expected to be the latest kernel.
    return kernels_getlist()[-1]
def kernels_getinstalled():
    """Get list of kernels installed on machine."""
    kernels_installed = []
    # Get normal kernels.
    kernels_installed = subprocess.run('pacman -Qqs "^linux[0-9][0-9]?([0-9])$"', shell=True, check=False, stdout=subprocess.PIPE, universal_newlines=True).stdout.splitlines()
    # Get realtime kernels, if they have been installed.
    kernels_rt_installed = subprocess.run('pacman -Qqs "^linux[0-9][0-9]?([0-9])-rt$"', shell=True, check=False, stdout=subprocess.PIPE, universal_newlines=True).stdout.splitlines()
    kernels_installed += kernels_rt_installed
    return kernels_installed


if __name__ == '__main__':
    print("Running {0}".format(__file__))

    # Get arguments
    parser = argparse.ArgumentParser(description='Install Fedora Software.')
    parser.add_argument("-d", "--desktop", help='Desktop Environment (i.e. gnome, kde, mate, etc)')
    parser.add_argument("-x", "--nogui", help='Configure script to disable GUI.', action="store_true")
    args = parser.parse_args()

    # Get non-root user information.
    USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
    MACHINEARCH = CFunc.machinearch()
    print("Username is:", USERNAMEVAR)
    print("Group Name is:", USERGROUP)
    print("Desktop Environment:", args.desktop)

    # Get VM State
    vmstatus = CFunc.getvmstate()

    # Update mirrors.
    subprocess.run("pacman-mirrors --geoip", shell=True, check=True)
    subprocess.run("pacman-mirrors -f 5", shell=True, check=True)
    pacman_invoke("-Syy")
    # Update system.
    pacman_update()

    ### Install Software ###
    # Yay
    pacman_install("yay")
    # Install AUR dependencies
    pacman_install("base-devel")
    # Sudoers changes
    CFuncExt.SudoersEnvSettings()
    # Edit sudoers to add pacman.
    sudoersfile = os.path.join(os.sep, "etc", "sudoers.d", "pkmgt")
    CFunc.AddLineToSudoersFile(sudoersfile, "%wheel ALL=(ALL) ALL", overwrite=True)
    CFunc.AddLineToSudoersFile(sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("pacman")))

    # Cli tools
    pacman_install("bash-completion fish zsh zsh-completions nano git tmux iotop rsync p7zip zip unzip unrar xdg-utils xdg-user-dirs sshfs openssh avahi ntfs-3g")
    sysctl_enable("sshd avahi-daemon")
    pacman_install("powerline-fonts ttf-roboto ttf-roboto-mono noto-fonts")
    # Git config
    subprocess.run("git config --global pull.rebase false", shell=True, check=True)
    CFunc.run_as_user(USERNAMEVAR, "git config --global pull.rebase false")
    # Samba
    pacman_install("samba manjaro-settings-samba")
    sysctl_enable("smb nmb winbind")
    # cifs-utils
    pacman_install("cifs-utils")
    # NTP Configuration
    sysctl_enable("systemd-timesyncd")
    subprocess.run("timedatectl set-local-rtc false; timedatectl set-ntp 1", shell=True, check=True)
    # EarlyOOM
    pacman_install("earlyoom")
    sysctl_enable("earlyoom")
    # GUI Packages
    if not args.nogui:
        # X Server
        pacman_install("xorg xorg-drivers xorg-fonts manjaro-input")
        # Browsers
        pacman_install("chromium")
        pacman_install("firefox")
        # Cups
        pacman_install("cups-pdf")
        # Audio/video
        pacman_install("manjaro-pulse lib32-jack paprefs")
        # Remote access
        pacman_install("remmina")
        # Tilix
        pacman_install("tilix")
        # Exclude chromium-libs-media-freeworld from multimedia
        pacman_install("manjaro-gstreamer manjaro-vaapi")
        pacman_install("youtube-dl ffmpeg smplayer mpv")
        # Editors
        pacman_install("code")
        # Syncthing
        pacman_install("syncthing")
        # Flameshot
        pacman_install("flameshot")
        os.makedirs(os.path.join(USERHOME, ".config", "autostart"), exist_ok=True)
        # Start flameshot on user login.
        if os.path.isfile(os.path.join(os.sep, "usr", "share", "applications", "flameshot.desktop")):
            shutil.copy(os.path.join(os.sep, "usr", "share", "applications", "flameshot.desktop"), os.path.join(USERHOME, ".config", "autostart"))
        CFunc.chown_recursive(os.path.join(USERHOME, ".config", ), USERNAMEVAR, USERGROUP)
        pacman_install("dconf-editor")
        pacman_install("gnome-disk-utility")
        # Manjaro tools
        pacman_install("mhwd")

    # Install software for VMs
    if vmstatus == "kvm":
        pacman_install("spice-vdagent qemu-guest-agent")
        sysctl_enable("spice-vdagentd qemu-ga")
    if vmstatus == "vbox":
        if args.nogui:
            pacman_install("virtualbox-guest-utils-nox")
        else:
            pacman_install("virtualbox-guest-utils")
        pacman_install("virtualbox-guest-dkms")
    if vmstatus == "vmware":
        pacman_install("open-vm-tools")

    # Install Desktop Software
    if args.desktop == "gnome":
        # Gnome
        pacman_install("baobab eog evince file-roller gdm gedit gnome-backgrounds gnome-calculator gnome-characters gnome-clocks gnome-wallpapers gnome-color-manager gnome-control-center gnome-font-viewer gnome-getting-started-docs gnome-keyring gnome-logs gnome-menus gnome-remote-desktop gnome-screenshot gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-system-monitor gnome-terminal gnome-themes-extra gnome-user-docs gnome-video-effects gnome-weather gvfs gvfs-google gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb mutter nautilus orca sushi tracker tracker-miners vino xdg-user-dirs-gtk xdg-desktop-portal-gtk yelp gnome-software manjaro-gnome-assets manjaro-gnome-settings manjaro-gnome-extension-settings manjaro-gdm-theme manjaro-settings-manager")
        sysctl_enable("-f gdm")
        # Some Gnome Extensions
        pacman_install("gnome-tweaks")
        pacman_install("gpaste")
        yay_install(USERNAMEVAR, "aur/gnome-shell-extension-topicons-plus-git")
        # Install gs installer script.
        gs_installer = CFunc.downloadfile("https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer", os.path.join(os.sep, "usr", "local", "bin"), overwrite=True)
        os.chmod(gs_installer[0], 0o777)
        # Install volume extension
        CFunc.run_as_user(USERNAMEVAR, "{0} --yes 858".format(gs_installer[0]))
        # Install dashtodock extension
        CFunc.run_as_user(USERNAMEVAR, "{0} --yes 307".format(gs_installer[0]))
        # Install Do Not Disturb extension
        CFunc.run_as_user(USERNAMEVAR, "{0} --yes 1480".format(gs_installer[0]))
    elif args.desktop == "kde":
        # KDE
        pacman_install("plasma kio-extras kdebase sddm")
        pacman_install("manjaro-kde-settings sddm-breath-theme manjaro-settings-manager-knotifier manjaro-settings-manager-kcm")
        pacman_install("latte-dock")
        sysctl_enable("-f sddm")
    elif args.desktop == "mate":
        # MATE
        pacman_install("mate network-manager-applet mate-extra manjaro-mate-settings arc-maia-icon-theme papirus-maia-icon-theme manjaro-settings-manager manjaro-settings-manager-notifier")
        lightdm_configure()
        # Brisk-menu
        pacman_install("brisk-menu")
        # Run MATE Configuration
        subprocess.run("{0}/DExtMate.py -c".format(SCRIPTDIR), shell=True, check=True)
    elif args.desktop == "xfce":
        pacman_install("xfce4-gtk3 xfce4-goodies xfce4-terminal network-manager-applet xfce4-notifyd-gtk3 xfce4-whiskermenu-plugin-gtk3 tumbler engrampa manjaro-xfce-gtk3-settings manjaro-settings-manager")
        lightdm_configure()

    if not args.nogui:
        # Numix
        yay_install(USERNAMEVAR, "aur/numix-icon-theme-git aur/numix-circle-icon-theme-git")

    # Add normal user to all reasonable groups
    CFunc.AddUserToGroup("disk")
    CFunc.AddUserToGroup("lp")
    CFunc.AddUserToGroup("wheel")
    CFunc.AddUserToGroup("cdrom")
    CFunc.AddUserToGroup("man")
    CFunc.AddUserToGroup("dialout")
    CFunc.AddUserToGroup("floppy")
    CFunc.AddUserToGroup("games")
    CFunc.AddUserToGroup("tape")
    CFunc.AddUserToGroup("video")
    CFunc.AddUserToGroup("audio")
    CFunc.AddUserToGroup("input")
    CFunc.AddUserToGroup("network")
    CFunc.AddUserToGroup("sys")
    CFunc.AddUserToGroup("power")
    CFunc.AddUserToGroup("kvm")
    CFunc.AddUserToGroup("systemd-journal")
    CFunc.AddUserToGroup("systemd-network")
    CFunc.AddUserToGroup("systemd-resolve")
    CFunc.AddUserToGroup("systemd-timesync")
    CFunc.AddUserToGroup("pipewire")
    CFunc.AddUserToGroup("colord")
    CFunc.AddUserToGroup("nm-openconnect")
    CFunc.AddUserToGroup("vboxsf")

    # Hdparm
    pacman_install("smartmontools hdparm")

    if not args.nogui:
        # Install snapd
        pacman_install("snapd")
        if not os.path.islink("/snap"):
            os.symlink("/var/lib/snapd/snap", "/snap", target_is_directory=True)
        CFunc.AddLineToSudoersFile(sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("snap")))
        sysctl_enable("snapd.socket")

        # Flatpak setup
        pacman_install("flatpak xdg-desktop-portal")
        CFunc.flatpak_addremote("flathub", "https://flathub.org/repo/flathub.flatpakrepo")
        CFunc.AddLineToSudoersFile(sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("flatpak")))

        # Flatpak apps
        CFunc.flatpak_install("flathub", "org.keepassxc.KeePassXC")
        CFunc.flatpak_install("flathub", "org.videolan.VLC")
        CFunc.flatpak_install("flathub", "io.github.quodlibet.QuodLibet")
        CFunc.flatpak_install("flathub", "org.atheme.audacious")
        CFunc.flatpak_install("flathub", "com.calibre_ebook.calibre")

    # Disable mitigations
    CFuncExt.GrubEnvAdd(os.path.join(os.sep, "etc", "default", "grub"), "GRUB_CMDLINE_LINUX", "mitigations=off")
    CFuncExt.GrubUpdate()

    # Extra scripts
    subprocess.run("{0}/Csshconfig.sh".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/CShellConfig.py -f -z -d".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/CCSClone.py".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/CDisplayManagerConfig.py".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/CVMGeneral.py".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/Cxdgdirs.py".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/Czram.py".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/CSysConfig.sh".format(SCRIPTDIR), shell=True, check=True)

    print("\nScript End")
