#!/usr/bin/env python3
"""Install Mate extensions and config"""

# Python includes.
import argparse
import os
import shutil
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]
# Temp folder
tempfolder = "/var/tmp/tempfolder_mate"

# Get arguments
parser = argparse.ArgumentParser(description='Install Mate extensions and config')
parser.add_argument("-b", "--brisk", help='Build Brisk menu.', action="store_true")
parser.add_argument("-c", "--config", help='Generate and Install panel configuration.', action="store_true")
args = parser.parse_args()

# Exit if not root.
CFunc.is_root(True)

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)


### Functions ###
def cleantempfolder():
    """Remove the temporary folder if it exists."""
    if os.path.isdir(tempfolder):
        shutil.rmtree(tempfolder)


### Begin Code ###

# Brisk
if args.brisk:
    cleantempfolder()
    # Install packages
    if shutil.which("dnf"):
        CFunc.dnfinstall("meson ninja-build gcc gtk3-devel mate-panel-devel mate-menus-devel libnotify-devel")
    try:
        CFunc.gitclone("https://github.com/solus-project/brisk-menu", tempfolder)
        subprocess.run("chmod -R a+rw {0}".format(tempfolder), shell=True)
        subprocess.run("""cd {0}
meson --buildtype plain build --prefix=/usr
ninja -C build -j$(($(getconf _NPROCESSORS_ONLN)+1))
ninja -C build install
""".format(tempfolder), shell=True)
    finally:
        cleantempfolder()
        # Clean up devel libraries.
        subprocess.run("dnf remove gtk3-devel mate-panel-devel mate-menus-devel libnotify-devel", shell=True)

# Configuration
if args.config:
    app_folder = os.path.join(os.path.sep, "usr", "share", "applications")
    # Find application desktop icons, for adding to panel
    dpath_chromium = None
    if os.path.isfile(os.path.join(app_folder, "chromium-vaapi.desktop")):
        # Chromium vaapi
        dpath_chromium = os.path.join(app_folder, "chromium-vaapi.desktop")
    elif os.path.isfile(os.path.join(app_folder, "chromium-browser.desktop")):
        # Stock chromium
        dpath_chromium = os.path.join(app_folder, "chromium-browser.desktop")
    elif os.path.isfile(os.path.join(app_folder, "google-chrome.desktop")):
        # Google Chrome
        dpath_chromium = os.path.join(app_folder, "google-chrome.desktop")

    dpath_tilix = None
    if os.path.isfile(os.path.join(app_folder, "com.gexperts.Tilix.desktop")):
        dpath_tilix = os.path.join(app_folder, "com.gexperts.Tilix.desktop")

    # https://github.com/mate-desktop/mate-panel/blob/master/data/fedora.layout
    # https://github.com/ubuntu-mate/ubuntu-mate-settings/blob/master/usr/share/mate-panel/layouts/familiar.layout
    mate_config = """[Toplevel top]
expand=true
orientation=top
size=24

[Toplevel bottom]
expand=true
orientation=bottom
size=24

[Object briskmenu]
object-type=applet
applet-iid=BriskMenuFactory::BriskMenu
toplevel-id=top
position=0
locked=true

[Object menu-bar]
object-type=menu-bar
toplevel-id=top
position=1
locked=true

[Object notification-area]
object-type=applet
applet-iid=NotificationAreaAppletFactory::NotificationArea
toplevel-id=top
position=10
panel-right-stick=true
locked=true

[Object indicatorappletcomplete]
object-type=applet
applet-iid=IndicatorAppletCompleteFactory::IndicatorAppletComplete
toplevel-id=top
position=11
panel-right-stick=true
locked=true

[Object clock]
object-type=applet
applet-iid=ClockAppletFactory::ClockApplet
toplevel-id=top
position=0
panel-right-stick=true
locked=true

[Object show-desktop]
object-type=applet
applet-iid=WnckletFactory::ShowDesktopApplet
toplevel-id=bottom
position=0
locked=true

[Object window-list]
object-type=applet
applet-iid=WnckletFactory::WindowListApplet
toplevel-id=bottom
position=20
locked=true
"""

    if dpath_chromium:
        mate_config += """
[Object chromium-browser]
object-type=launcher
launcher-location={0}
toplevel-id=top
position=10
locked=true
""".format(dpath_chromium)

    mate_config += """
[Object file-browser]
object-type=launcher
launcher-location=/usr/share/applications/caja-browser.desktop
toplevel-id=top
position=20
locked=true

[Object mate-terminal]
object-type=launcher
launcher-location=/usr/share/applications/mate-terminal.desktop
toplevel-id=top
position=30
locked=true
"""

    if dpath_tilix:
        mate_config += """
[Object tilix-terminal]
object-type=launcher
launcher-location={0}
toplevel-id=top
position=40
locked=true
""".format(dpath_tilix)

    # Write the configuration.
    matepanel_layout_folder = os.path.join(os.path.sep, "usr", "share", "mate-panel", "layouts")
    matepanel_layout_filepath = os.path.join(matepanel_layout_folder, "mate-rcustom.layout")
    if os.path.isdir(matepanel_layout_folder):
        print("Writing layout to {0} .".format(matepanel_layout_filepath))
        with open(matepanel_layout_filepath, 'w') as file:
            file.write(mate_config)
    else:
        print("ERROR: {0} does not exist, not writing configuration.".format(matepanel_layout_folder))

    # Set as default panel layout
    schemas_folder = os.path.join(os.path.sep, "usr", "share", "glib-2.0", "schemas")
    schemas_customfile = os.path.join(schemas_folder, "99_mate-rcustom.gschema.override")
    if os.path.isdir(schemas_folder):
        print("Writing override to {0} .".format(schemas_customfile))
        with open(schemas_customfile, 'w') as file:
            file.write("""[org.mate.panel]
default-layout='mate-rcustom'
""")

    # Refresh MATE panel
    # https://ubuntu-mate.community/t/ubuntu-mate-14-04-lts-useful-information/25
    # mate-panel --reset --layout mate-rcustom
    # mate-panel --replace &
    print('Run "mate-panel --layout mate-rcustom; mate-panel --reset; mate-panel replace &" as a normal user to reset the panel.')
