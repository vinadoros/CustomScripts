#!/usr/bin/env python3
"""Install/uninstall libvirt and Virt-Manager."""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Get arguments
parser = argparse.ArgumentParser(description='Install/uninstall libvirt and virt-manager.')
parser.add_argument("-i", "--image", help='Image path, i.e. /mnt/Storage/VMs')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-u", "--uninstall", help='Uninstall libvirt and virt-manager.', action="store_true")

# Save arguments.
args = parser.parse_args()

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)

# Process arguments
if args.uninstall:
    print("Uninstalling libvirt.")
else:
    print("Installing libvirt.")
if args.image and os.path.isdir(args.image):
    ImagePath = os.path.abspath(args.image)
    print("Path to store Images: {0}".format(ImagePath))
else:
    sys.exit("ERROR: Image path {0} is not valid. Please specify a valid folder.".format(args.image))

# Exit if not root.
CFunc.is_root(True)

if args.noprompt is False:
    input("Press Enter to continue.")


### Begin Code ###
# Set universal variables
PolkitPath = os.path.join(os.sep, "etc", "polkit-1")
PolkitRulesPath = os.path.join(PolkitPath, "rules.d")
PolkitUserRulePath = os.path.join(PolkitRulesPath, "80-libvirt.rules")
SysctlAcceptRaPath = os.path.join(os.sep, "etc", "sysctl.d", "99-acceptra.conf")
# Installation Code
if args.uninstall is False:
    print("Installing libvirt")
    if shutil.which("dnf"):
        CFunc.dnfinstall("@virtualization")
        CFunc.dnfinstall("python3-libguestfs")
        subprocess.run("systemctl enable libvirtd", shell=True)
        subprocess.run("systemctl start libvirtd", shell=True)
        subprocess.run("usermod -aG libvirt {0}".format(USERNAMEVAR), shell=True)
    elif shutil.which("apt-get"):
        CFunc.aptinstall("virt-manager qemu-kvm ssh-askpass")
        subprocess.run("usermod -aG libvirt {0}".format(USERNAMEVAR), shell=True)
        subprocess.run("usermod -aG libvirt-qemu {0}".format(USERNAMEVAR), shell=True)

    # Remove existing default pool
    subprocess.run("virsh pool-destroy default", shell=True)
    subprocess.run("virsh pool-undefine default", shell=True)
    print("List all pools after deletion")
    subprocess.run("virsh pool-list --all", shell=True)
    # Create new default pool
    subprocess.run('virsh pool-define-as default dir - - - - "{0}"'.format(ImagePath), shell=True)
    subprocess.run("virsh pool-autostart default", shell=True)
    subprocess.run("virsh pool-start default", shell=True)
    print("List all pools after re-creation")
    subprocess.run("virsh pool-list --all", shell=True)
    subprocess.run("virsh pool-info default", shell=True)

    # Set config info
    subprocess.run('''sed -i 's/#user = "root"/user = "{0}"/g' /etc/libvirt/qemu.conf'''.format(USERNAMEVAR), shell=True)
    subprocess.run('''sed -i 's/#save_image_format = "raw"/save_image_format = "xz"/g' /etc/libvirt/qemu.conf''', shell=True)
    subprocess.run('''sed -i 's/#dump_image_format = "raw"/dump_image_format = "xz"/g' /etc/libvirt/qemu.conf''', shell=True)
    subprocess.run('''sed -i 's/#snapshot_image_format = "raw"/snapshot_image_format = "xz"/g' /etc/libvirt/qemu.conf''', shell=True)

    if os.path.isdir(PolkitPath) and not os.path.isdir(PolkitRulesPath):
        os.makedirs(PolkitRulesPath)
    # https://ask.fedoraproject.org/en/question/45805/how-to-use-virt-manager-as-a-non-root-user/
    with open(PolkitUserRulePath, mode='w') as f:
        f.write("""polkit.addRule(function(action, subject) {
  if (action.id == "org.libvirt.unix.manage" && subject.active && subject.isInGroup("wheel")) {
      return polkit.Result.YES;
  }
});
""")

    # https://wiki.gentoo.org/wiki/QEMU/KVM_IPv6_Support
    NetXMLPath = os.path.join(tempfile.gettempdir(), "default.xml")
    NetXMLText = """<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' zone='trusted' stp='off'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
  <ip family='ipv6' address='fdab:8ce1:b5cd:fbd5::1' prefix='96'>
    <dhcp>
      <range start='fdab:8ce1:b5cd:fbd5::1000' end='fdab:8ce1:b5cd:fbd5::2000' />
    </dhcp>
  </ip>
</network>
"""
    with open(NetXMLPath, mode='w') as f:
        f.write(NetXMLText)
    subprocess.run("virsh net-destroy default", shell=True)
    subprocess.run("virsh net-undefine default", shell=True)
    # Add accept_ra
    # https://superuser.com/questions/1208952/qemu-kvm-libvirt-forwarding
    with open(SysctlAcceptRaPath, mode='w') as f:
        f.write("net.ipv6.conf.all.accept_ra = 2")
    subprocess.run('echo "2" | tee /proc/sys/net/ipv6/conf/all/accept_ra', shell=True)
    os.chdir(tempfile.gettempdir())
    subprocess.run("virsh net-define default.xml", shell=True)
    os.remove(NetXMLPath)
    # Set network info
    subprocess.run("virsh net-autostart default", shell=True)
    subprocess.run("virsh net-start default", shell=True)

    # Set dconf info
    if shutil.which("gsettings"):
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager.stats enable-cpu-poll true")
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager.stats enable-disk-poll true")
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager.stats enable-memory-poll true")
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager.stats enable-net-poll true")
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager.vmlist-fields cpu-usage true")
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager.vmlist-fields disk-usage false")
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager.vmlist-fields memory-usage true")
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager.vmlist-fields network-traffic true")
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager.console resize-guest 1")
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager enable-libguestfs-vm-inspection true")
        CFunc.run_as_user(USERNAMEVAR, "gsettings set org.virt-manager.virt-manager xmleditor-enabled true")
    else:
        print("WARNING: gsettings command not found. Install to set virt-manager defaults.")

# Uninstallation Code
if args.uninstall is True:
    print("Uninstalling libvirt")
    subprocess.run("virsh net-autostart default --disable", shell=True)
    subprocess.run("virsh net-destroy default", shell=True)
    if shutil.which("dnf"):
        subprocess.run("systemctl stop libvirtd", shell=True)
        subprocess.run("systemctl disable libvirtd", shell=True)
        subprocess.run("dnf remove @virtualization", shell=True)
    elif shutil.which("apt-get"):
        subprocess.run("apt-get --purge remove virt-manager qemu-kvm ssh-askpass", shell=True)
    if os.path.isfile(PolkitUserRulePath):
        os.remove(PolkitUserRulePath)
    if os.path.isfile(SysctlAcceptRaPath):
        os.remove(SysctlAcceptRaPath)

print("Script completed successfully!")
