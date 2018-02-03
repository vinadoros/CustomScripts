#!/usr/bin/env python3
"""Create a virtual machine image using Packer"""

# Python includes.
import argparse
from datetime import datetime
import hashlib
import json
import multiprocessing
import os
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

### Functions ###
def md5sum(md5_filename, blocksize=65536):
    """
    Calculate the MD5Sum of a file
    https://stackoverflow.com/a/21565932
    """
    hashmd5 = hashlib.md5()
    with open(md5_filename, "rb") as f:
        for block in iter(lambda: f.read(blocksize), b""):
            hashmd5.update(block)
    return hashmd5.hexdigest()
def packerversion_get():
    """Get the packer version from github"""
    releasejson_link = "https://api.github.com/repos/hashicorp/packer/tags"
    # Get the json data from GitHub.
    with urllib.request.urlopen(releasejson_link) as releasejson_handle:
        releasejson_data = json.load(releasejson_handle)
    for release in releasejson_data:
        # Stop after the first (latest) release is found.
        latestrelease = release["name"].strip().replace("v", "")
        break
    print("Detected packer version: {0}".format(latestrelease))
    return latestrelease


# Exit if root.
CFunc.is_root(False)

# Get system and user information.
USERHOME = os.path.expanduser("~")
CPUCORES = multiprocessing.cpu_count() if multiprocessing.cpu_count() <= 4 else 4

# Get arguments
parser = argparse.ArgumentParser(description='Create a VM using packer.')
parser.add_argument("-m", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-n", "--vmname", help="Name of Virtual Machine")
parser.add_argument("-t", "--vmtype", type=int, help="Virtual Machine type (1=Virtualbox, 2=libvirt, 3=VMWare)", default="1")
parser.add_argument("-a", "--ostype", type=int, help="OS type", default="1")
parser.add_argument("-f", "--fullname", help="Full Name", default="User Name")
parser.add_argument("-i", "--iso", help="Path to live cd")
parser.add_argument("-s", "--imgsize", type=int, help="Size of image", default=65536)
parser.add_argument("-p", "--vmpath", help="Path of Packer output", required=True)
parser.add_argument("-y", "--vmuser", help="VM Username", default="user")
parser.add_argument("-z", "--vmpass", help="VM Password", default="asdf")
parser.add_argument("-b", "--getpacker", help="Force refresh packer", action="store_true")
parser.add_argument("-x", "--sshkey", help="SSH authorizaiton key")
parser.add_argument("-d", "--desktopenv", help="Desktop Environment (defaults to mate)", default="mate")
parser.add_argument("--memory", help="Memory for VM", default="4096")
parser.add_argument("--vmprovision", help="""Override provision options. Enclose options in double backslashes and quotes. Example: \\\\"-n -e 3\\\\" """)

# Save arguments.
args = parser.parse_args()

# Variables most likely to change.
vmpath = os.path.abspath(args.vmpath)
print("Path to Packer output is {0}".format(vmpath))
print("OS Type is {0}".format(args.ostype))
print("VM Memory is {0}".format(args.memory))
print("VM Hard Disk size is {0}".format(args.imgsize))
print("VM User is {0}".format(args.vmuser))
print("Desktop Environment:", args.desktopenv)

# Get Packer
if not shutil.which("packer") or args.getpacker is True:
    print("Getting packer binary.")
    if not CFunc.is_windows():
        packer_os = "linux"
        packer_zipurl = "https://releases.hashicorp.com/packer/{0}/packer_{0}_{1}_amd64.zip".format(packerversion_get(), packer_os)
        packer_zipfile = CFunc.downloadfile(packer_zipurl, "/tmp")[0]
        subprocess.run("7z x -aoa -y {0} -o/usr/local/bin".format(packer_zipfile), shell=True)
        os.chmod("/usr/local/bin/packer", 0o777)
        if os.path.isfile(packer_zipfile):
            os.remove(packer_zipfile)
    subprocess.run("packer -v", shell=True)

# Ensure that certain commands exist.
cmdcheck = ["packer"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))

# Determine VM hypervisor
if args.vmtype == 1:
    hvname = "vbox"
elif args.vmtype == 2:
    hvname = "kvm"
elif args.vmtype == 3:
    hvname = "vmware"
elif args.vmtype == 4:
    hvname = "hyperv"

# Set OS options.
# KVM os options can be found by running "osinfo-query os"
if 1 <= args.ostype <= 4:
    vmprovisionscript = "MFedora.py"
    vboxosid = "Fedora_64"
    vmwareid = "fedora-64"
    kvm_os = "linux"
    kvm_variant = "fedora25"
    isourl = "https://download.fedoraproject.org/pub/fedora/linux/releases/27/Server/x86_64/iso/Fedora-Server-dvd-x86_64-27-1.6.iso"
if args.ostype == 1:
    vmname = "Packer-Fedora-{0}".format(hvname)
    vmprovision_defopts = "-d {0} -a".format(args.desktopenv)
if args.ostype == 2:
    vmname = "Packer-FedoraBare-{0}".format(hvname)
    vmprovision_defopts = "-d {0} -b".format(args.desktopenv)
if args.ostype == 3:
    vmname = "Packer-FedoraCLI-{0}".format(hvname)
    vmprovision_defopts = "-x -a"
if args.ostype == 4:
    vmname = "Packer-FedoraCLIBare-{0}".format(hvname)
    vmprovision_defopts = "-x -b"
if 5 <= args.ostype <= 9:
    vboxosid = "Fedora_64"
    vmwareid = "fedora-64"
    kvm_os = "linux"
    kvm_variant = "centos7.0"
    isourl = "https://mirrors.kernel.org/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1708.iso"
    vmprovisionscript = "MCentOS.py"
if args.ostype == 5:
    vmname = "Packer-CentOS-{0}".format(hvname)
    vmprovision_defopts = "-d -r"
if args.ostype == 6:
    vmname = "Packer-CentOSOrig-{0}".format(hvname)
    vmprovision_defopts = " "
if 10 <= args.ostype <= 19:
    vboxosid = "Ubuntu_64"
    vmwareid = "ubuntu-64"
    vmprovisionscript = "MUbuntu.py"
    kvm_os = "linux"
# Ubuntu latest
if 10 <= args.ostype <= 14:
    kvm_variant = "ubuntu17.04"
    isourl = "http://releases.ubuntu.com/17.10/ubuntu-17.10-server-amd64.iso"
# Ubuntu LTS
if 15 <= args.ostype <= 19:
    kvm_variant = "ubuntu16.04"
    isourl = "http://releases.ubuntu.com/16.04/ubuntu-16.04.3-server-amd64.iso"
if args.ostype == 10:
    vmname = "Packer-Ubuntu-{0}".format(hvname)
    vmprovision_defopts = "-d {0} -a".format(args.desktopenv)
if args.ostype == 11:
    vmname = "Packer-UbuntuCLI-{0}".format(hvname)
    vmprovision_defopts = "-a -x"
if args.ostype == 15:
    vmname = "Packer-UbuntuLTS-{0}".format(hvname)
    vmprovision_defopts = "-l -d {0} -a".format(args.desktopenv)
if args.ostype == 16:
    vmname = "Packer-UbuntuLTSCLI-{0}".format(hvname)
    vmprovision_defopts = "-l -a -x"
if args.ostype == 17:
    vmname = "Packer-UbuntuLTSBare-{0}".format(hvname)
    vmprovision_defopts = "-l -b -x"
if args.ostype == 20:
    vmname = "Packer-OpenSuseTW-{0}".format(hvname)
    vboxosid = "OpenSUSE_64"
    vmwareid = "ubuntu-64"
    vmprovisionscript = "MOpensuse.py"
    vmprovision_defopts = "-d {0} -a".format(args.desktopenv)
    kvm_os = "linux"
    kvm_variant = "opensusetumbleweed"
    isourl = "http://download.opensuse.org/tumbleweed/iso/openSUSE-Tumbleweed-NET-x86_64-Current.iso"
if 30 <= args.ostype <= 39:
    vboxosid = "Debian_64"
    vmwareid = "debian-64"
    vmprovisionscript = "MDebian.py"
    kvm_os = "linux"
    kvm_variant = "debiantesting"
# Debian Testing and Unstable
if 30 <= args.ostype <= 39:
    isourl = "https://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/debian-testing-amd64-netinst.iso"
if args.ostype == 30:
    vmname = "Packer-DebianTesting-{0}".format(hvname)
    vmprovision_defopts = "-d {0} -a".format(args.desktopenv)
if args.ostype == 31:
    vmname = "Packer-DebianTestingCLI-{0}".format(hvname)
    vmprovision_defopts = "-a -x"
if args.ostype == 32:
    vmname = "Packer-DebianTestingBare-{0}".format(hvname)
    vmprovision_defopts = "-b -x"
if args.ostype == 33:
    vmname = "Packer-DebianUnstable-{0}".format(hvname)
    vmprovision_defopts = "-u -d {0} -a".format(args.desktopenv)
if args.ostype == 34:
    vmname = "Packer-DebianUnstableCLI-{0}".format(hvname)
    vmprovision_defopts = "-u -a -x"
if args.ostype == 35:
    vmname = "Packer-DebianUnstableBare-{0}".format(hvname)
    vmprovision_defopts = "-u -b -x"
if args.ostype == 40:
    vmname = "Packer-FreeBSD-{0}".format(hvname)
    vboxosid = "FreeBSD_64"
    vmwareid = "freebsd-64"
    vmprovisionscript = "MFreeBSD.sh"
    vmprovision_defopts = " "
    kvm_os = "freebsd"
    kvm_variant = "freebsd11.0"
    isourl = "https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/11.1/FreeBSD-11.1-RELEASE-amd64-disc1.iso"
if 50 <= args.ostype <= 59:
    vboxosid = "Windows10_64"
    vmwareid = "windows9-64"
    kvm_os = "windows"
    kvm_variant = "win10"
    vmprovision_defopts = " "
    isourl = None
if args.ostype == 50:
    vmname = "Packer-Windows10-{0}".format(hvname)
if args.ostype == 51:
    vmname = "Packer-Windows10LTS-{0}".format(hvname)
if args.ostype == 54:
    vmname = "Packer-Windows7-{0}".format(hvname)
    vboxosid = "Windows7_64"
    vmwareid = "windows7-64"
    kvm_variant = "win7"
if 55 <= args.ostype <= 59:
    vboxosid = "Windows2016_64"
    vmwareid = "windows9srv-64"
    kvm_os = "windows"
    kvm_variant = "win10"
    vmprovision_defopts = " "
if args.ostype == 55:
    vmname = "Packer-Windows2016-{0}".format(hvname)
if args.ostype == 56:
    vmname = "Packer-Windows2016Core-{0}".format(hvname)
if args.ostype == 57:
    vmname = "Packer-WindowsServerCore-{0}".format(hvname)
if args.ostype == 60:
    vmname = "Packer-Gentoo-{0}".format(hvname)
    vmprovisionscript = "MFedora.sh"
    vmprovision_defopts = " "
    vboxosid = "Gentoo_64"
    vmwareid = "ubuntu-64"
    kvm_os = "linux"
    kvm_variant = "opensusetumbleweed"
    install_txt_url = "http://distfiles.gentoo.org/releases/amd64/autobuilds/latest-install-amd64-minimal.txt"
    # Save url
    install_txt_data = urllib.request.urlopen(install_txt_url)
    # Search through every line.
    for line in install_txt_data:
        # Find the line with the install iso.
        if "install" in str(line):
            # Split that line, decode the byte array and save it.
            relative_install_iso = line.split()[0].decode()
            isourl = "http://distfiles.gentoo.org/releases/amd64/autobuilds/"+relative_install_iso
            print("Gentoo ISO Url: "+isourl)

# Override provision opts if provided.
if args.vmprovision is None:
    vmprovision_opts = vmprovision_defopts
else:
    vmprovision_opts = args.vmprovision
print("VM Provision Options:", vmprovision_opts)

# Override VM Name if provided
if args.vmname is not None:
    vmname = args.vmname
print("VM Name is {0}".format(vmname))

if args.noprompt is False:
    input("Press Enter to continue.")

# Set up VM hypervisor settings
if args.vmtype == 1:
    # Set vbox machine folder path.
    subprocess.run('vboxmanage setproperty machinefolder "{0}"'.format(vmpath), shell=True, check=True)
    # Create host only adapter if it does not exist.
    if CFunc.is_windows():
        vbox_hostonlyif_name = "VirtualBox Host-Only Ethernet Adapter"
    else:
        vbox_hostonlyif_name = "vboxnet0"
    vbox_hostonlyifs = CFunc.subpout("vboxmanage list hostonlyifs")
    if vbox_hostonlyif_name not in vbox_hostonlyifs:
        print("Creating {0} hostonlyif.".format(vbox_hostonlyif_name))
        subprocess.run("vboxmanage hostonlyif create", shell=True, check=True)
        # Set DHCP active on created adapter
        subprocess.run('vboxmanage hostonlyif ipconfig "{0}" --ip 192.168.253.1'.format(vbox_hostonlyif_name), shell=True, check=True)
        subprocess.run('vboxmanage dhcpserver modify --ifname "{0}" --ip 192.168.253.1 --netmask 255.255.255.0 --lowerip 192.168.253.2 --upperip 192.168.253.253 --enable'.format(vbox_hostonlyif_name), shell=True, check=True)
elif args.vmtype == 4:
    # Create an external switch if it does not already exist. External switch is required for guests to get DHCP.
    # https://github.com/MattHodge/PackerTemplates#building-hyper-v-images
    hyperv_switch_name = "External VM Switch"
    hyperv_mainnetadapter_name = "Ethernet"
    hyperv_winadapters = CFunc.subpout('powershell -c "Get-NetAdapter -Name "*" | Format-List -Property "Name""')
    if hyperv_switch_name not in hyperv_winadapters:
        subprocess.run('''powershell -c "New-VMSwitch -name '{0}' -NetAdapterName '{1}' -AllowManagementOS $true"'''.format(hyperv_switch_name, hyperv_mainnetadapter_name), shell=True)

# Delete leftover VMs
if args.vmtype == 1:
    vboxvmlist = CFunc.subpout("VBoxManage list vms")
    if vmname in vboxvmlist:
        subprocess.run('VBoxManage unregistervm "{0}" --delete'.format(vmname), shell=True)
elif args.vmtype == 2:
    print("Delete KVM image.")
elif args.vmtype == 3:
    print("Delete vmware image.")

# Check iso
if args.iso is not None:
    isopath = os.path.abspath(args.iso)
else:
    isopath = CFunc.downloadfile(isourl, vmpath)[0]
if os.path.isfile(isopath) is True:
    print("Path to ISO is {0}".format(isopath))
else:
    sys.exit("\nError, ensure iso {0} exists.".format(isopath))

# Create temporary folder for packer
packer_temp_folder = os.path.join(vmpath, "packertemp"+vmname)
if os.path.isdir(packer_temp_folder):
    print("\nDeleting old VM.")
    shutil.rmtree(packer_temp_folder)
os.mkdir(packer_temp_folder)
os.chdir(packer_temp_folder)

# Detect root ssh key.
if args.sshkey is not None:
    sshkey = args.rootsshkey
elif os.path.isfile(os.path.join(USERHOME, ".ssh", "id_ed25519.pub")) is True:
    with open(os.path.join(USERHOME, ".ssh", "id_ed25519.pub"), 'r') as sshfile:
        sshkey = sshfile.read().replace('\n', '')
elif os.path.isfile(os.path.join(USERHOME, ".ssh", "id_rsa.pub")) is True:
    with open(os.path.join(USERHOME, ".ssh", "id_rsa.pub"), 'r') as sshfile:
        sshkey = sshfile.read().replace('\n', '')
else:
    sshkey = " "
print("SSH Key is \"{0}\"".format(sshkey))

# Generate hashed password
# https://serverfault.com/questions/330069/how-to-create-an-sha-512-hashed-password-for-shadow#330072

if CFunc.is_windows() is True:
    from passlib import hash
    sha512_password = hash.sha512_crypt.encrypt(args.vmpass, rounds=5000)
else:
    import crypt
    sha512_password = crypt.crypt(args.vmpass, crypt.mksalt(crypt.METHOD_SHA512))


# Copy unattend script folder
if os.path.isdir(os.path.join(SCRIPTDIR, "unattend")):
    tempscriptbasename = os.path.basename(SCRIPTDIR)
    tempscriptfolderpath = os.path.join(packer_temp_folder, tempscriptbasename)
    tempunattendfolder = os.path.join(tempscriptfolderpath, "unattend")
    shutil.copytree(SCRIPTDIR, tempscriptfolderpath, ignore=shutil.ignore_patterns('.git'))
    # Set usernames and passwords
    CFunc.find_replace(tempunattendfolder, "INSERTUSERHERE", args.vmuser, "*")
    CFunc.find_replace(tempunattendfolder, "INSERTPASSWORDHERE", args.vmpass, "*")
    CFunc.find_replace(tempunattendfolder, "INSERTFULLNAMEHERE", args.fullname, "*")
    CFunc.find_replace(tempunattendfolder, "INSERTHOSTNAMENAMEHERE", vmname, "*")
    CFunc.find_replace(tempunattendfolder, "INSERTHASHEDPASSWORDHERE", sha512_password, "*")
    CFunc.find_replace(tempunattendfolder, "INSERTSSHKEYHERE", sshkey, "*")


# Get hash for iso.
print("Generating Checksum of {0}".format(isopath))
md5 = md5sum(isopath)

# Create Packer json configuration
# Packer Builder Configuration
data = {}
data['builders'] = ['']
data['builders'][0] = {}
if args.vmtype == 1:
    data['builders'][0]["type"] = "virtualbox-iso"
    data['builders'][0]["guest_os_type"] = "{0}".format(vboxosid)
    data['builders'][0]["vm_name"] = "{0}".format(vmname)
    data['builders'][0]["hard_drive_interface"] = "sata"
    data['builders'][0]["sata_port_count"] = 2
    data['builders'][0]["iso_interface"] = "sata"
    data['builders'][0]["vboxmanage"] = ['']
    data['builders'][0]["vboxmanage"][0] = ["modifyvm", "{{.Name}}", "--memory", "{0}".format(args.memory)]
    data['builders'][0]["vboxmanage"].append(["modifyvm", "{{.Name}}", "--vram", "40"])
    data['builders'][0]["vboxmanage"].append(["modifyvm", "{{.Name}}", "--cpus", "{0}".format(CPUCORES)])
    data['builders'][0]["vboxmanage"].append(["modifyvm", "{{.Name}}", "--nic2", "hostonly"])
    data['builders'][0]["vboxmanage"].append(["modifyvm", "{{.Name}}", "--hostonlyadapter2", vbox_hostonlyif_name])
    data['builders'][0]["vboxmanage_post"] = ['']
    data['builders'][0]["vboxmanage_post"][0] = ["modifyvm", "{{.Name}}", "--clipboard", "bidirectional"]
    data['builders'][0]["vboxmanage_post"].append(["modifyvm", "{{.Name}}", "--accelerate3d", "on"])
    if CFunc.is_windows() is False:
        data['builders'][0]["vboxmanage_post"].append(["sharedfolder", "add", "{{.Name}}", "--name", "root", "--hostpath", "/", "--automount"])

    data['builders'][0]["post_shutdown_delay"] = "30s"
    if 1 <= args.ostype <= 39:
        data['builders'][0]["vboxmanage"].append(["modifyvm", "{{.Name}}", "--nictype1", "virtio"])
        data['builders'][0]["vboxmanage"].append(["modifyvm", "{{.Name}}", "--nictype2", "virtio"])
    if 50 <= args.ostype <= 59:
        # https://hodgkins.io/best-practices-with-packer-and-windows#use-headless-mode
        data['builders'][0]["headless"] = "true"
        data['builders'][0]["guest_additions_mode"] = "upload"
        data['builders'][0]["guest_additions_path"] = "c:/Windows/Temp/windows.iso"
elif args.vmtype == 2:
    data['builders'][0]["type"] = "qemu"
    data['builders'][0]["accelerator"] = "kvm"
    if 50 <= args.ostype <= 59:
        # Use more generic hardware for windows
        kvm_diskinterface = "ide"
        kvm_netdevice = "e1000"
    else:
        kvm_diskinterface = "virtio"
        kvm_netdevice = "virtio-net"
    data['builders'][0]["disk_interface"] = kvm_diskinterface
    data['builders'][0]["net_device"] = kvm_netdevice
    data['builders'][0]["vm_name"] = "{0}.qcow2".format(vmname)
    data['builders'][0]["qemuargs"] = ['']
    data['builders'][0]["qemuargs"][0] = ["-m", "{0}M".format(args.memory)]
    data['builders'][0]["qemuargs"].append(["--cpu", "host"])
    data['builders'][0]["qemuargs"].append(["--smp", "cores={0}".format(CPUCORES)])
elif args.vmtype == 3:
    data['builders'][0]["type"] = "vmware-iso"
    data['builders'][0]["version"] = "12"
    data['builders'][0]["vm_name"] = "{0}".format(vmname)
    data['builders'][0]["vmdk_name"] = "{0}".format(vmname)
    data['builders'][0]["vmx_data"] = {"virtualhw.version": "12", "memsize": "{0}".format(args.memory), "numvcpus": "{0}".format(CPUCORES), "cpuid.coresPerSocket": "{0}".format(CPUCORES), "guestos": "{0}".format(vmwareid), "usb.present": "TRUE", "scsi0.virtualDev": "lsisas1068"}
    data['builders'][0]["vmx_data_post"] = {"sharedFolder0.present": "TRUE", "sharedFolder0.enabled": "TRUE", "sharedFolder0.readAccess": "TRUE", "sharedFolder0.writeAccess": "TRUE", "sharedFolder0.hostPath": "/", "sharedFolder0.guestName": "root", "sharedFolder0.expiration": "never", "sharedFolder.maxNum": "1", "isolation.tools.hgfs.disable": "FALSE"}
    if 50 <= args.ostype <= 59:
        data['builders'][0]["tools_upload_flavor"] = "windows"
        data['builders'][0]["tools_upload_path"] = "c:/Windows/Temp/windows.iso"
elif args.vmtype == 4:
    data['builders'][0]["type"] = "hyperv-iso"
    data['builders'][0]["vm_name"] = "{0}".format(vmname)
    data['builders'][0]["ram_size"] = "{0}".format(args.memory)
    data['builders'][0]["enable_dynamic_memory"] = True
data['builders'][0]["shutdown_command"] = "shutdown -P now"
data['builders'][0]["iso_url"] = "{0}".format(isopath)
data['builders'][0]["iso_checksum"] = md5
data['builders'][0]["iso_checksum_type"] = "md5"
data['builders'][0]["output_directory"] = "{0}".format(vmname)
data['builders'][0]["http_directory"] = tempunattendfolder
data['builders'][0]["disk_size"] = "{0}".format(args.imgsize)
data['builders'][0]["boot_wait"] = "5s"
data['builders'][0]["ssh_username"] = "root"
data['builders'][0]["ssh_password"] = "{0}".format(args.vmpass)
data['builders'][0]["ssh_timeout"] = "90m"
# Packer Provisioning Configuration
data['provisioners'] = ['']
data['provisioners'][0] = {}
if 1 <= args.ostype <= 4:
    data['builders'][0]["boot_command"] = ["<tab> inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/fedora.cfg<enter><wait>"]
    data['provisioners'][0]["type"] = "shell"
    data['provisioners'][0]["inline"] = "dnf install -y git; git clone https://github.com/ramesh45345/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{0} {1}".format(vmprovisionscript, vmprovision_opts)
if 5 <= args.ostype <= 9:
    data['builders'][0]["boot_command"] = ["<tab> text ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos7-ks.cfg<enter><wait>"]
    data['provisioners'][0]["type"] = "shell"
    data['provisioners'][0]["inline"] = "yum install -y git; git clone https://github.com/ramesh45345/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{0} {1}".format(vmprovisionscript, vmprovision_opts)
if 10 <= args.ostype <= 19:
    data['provisioners'][0]["type"] = "shell"
    data['provisioners'][0]["inline"] = "mkdir -m 700 -p /root/.ssh; echo '{sshkey}' > /root/.ssh/authorized_keys; mkdir -m 700 -p ~{vmuser}/.ssh; echo '{sshkey}' > ~{vmuser}/.ssh/authorized_keys; chown {vmuser}:{vmuser} -R ~{vmuser}; apt install -y git; git clone https://github.com/ramesh45345/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{vmprovisionscript} {vmprovision_opts}".format(vmprovisionscript=vmprovisionscript, vmprovision_opts=vmprovision_opts, sshkey=sshkey, vmuser=args.vmuser)
if 10 <= args.ostype <= 14:
    data['builders'][0]["boot_command"] = ["<enter><wait><f6><wait><esc><home>url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu.cfg hostname=ubuntu locale=en_US keyboard-configuration/modelcode=SKIP netcfg/choose_interface=auto <enter>"]
if 15 <= args.ostype <= 19:
    data['builders'][0]["boot_command"] = ["<enter><wait><down><wait><f6><wait><esc><home>url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu.cfg hostname=ubuntu locale=en_US keyboard-configuration/modelcode=SKIP netcfg/choose_interface=auto <enter>"]
if 20 <= args.ostype <= 21:
    data['builders'][0]["boot_command"] = ["<wait><down><wait><f4><wait><esc><wait>autoyast2=http://{{ .HTTPIP }}:{{ .HTTPPort }}/opensuse.cfg textmode=1<enter>"]
    data['provisioners'][0]["type"] = "shell"
    data['provisioners'][0]["inline"] = "mkdir -m 700 -p /root/.ssh; echo '{sshkey}' > /root/.ssh/authorized_keys; mkdir -m 700 -p ~{vmuser}/.ssh; echo '{sshkey}' > ~{vmuser}/.ssh/authorized_keys; chown {vmuser}:{vmuser} -R ~{vmuser}; while ! zypper install -yl --no-recommends git; do sleep 5; done; git clone https://github.com/ramesh45345/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{vmprovisionscript} {vmprovision_opts}".format(vmprovisionscript=vmprovisionscript, vmprovision_opts=vmprovision_opts, sshkey=sshkey, vmuser=args.vmuser)
if 30 <= args.ostype <= 39:
    data['provisioners'][0]["type"] = "shell"
    data['provisioners'][0]["inline"] = "mkdir -m 700 -p /root/.ssh; echo '{sshkey}' > /root/.ssh/authorized_keys; mkdir -m 700 -p ~{vmuser}/.ssh; echo '{sshkey}' > ~{vmuser}/.ssh/authorized_keys; chown {vmuser}:{vmuser} -R ~{vmuser}; apt install -y git; git clone https://github.com/ramesh45345/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{vmprovisionscript} {vmprovision_opts}".format(vmprovisionscript=vmprovisionscript, vmprovision_opts=vmprovision_opts, sshkey=sshkey, vmuser=args.vmuser)
    data['builders'][0]["boot_command"] = ["<esc>auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian.cfg hostname=debian locale=en_US keyboard-configuration/modelcode=SKIP netcfg/choose_interface=auto <enter>"]
if 40 <= args.ostype <= 41:
    data['builders'][0]["boot_command"] = ["<wait><enter><wait10><wait10><right><enter><wait>dhclient -b vtnet0<enter><wait>dhclient -b em0<enter><wait10>fetch -o /tmp/installerconfig http://{{ .HTTPIP }}:{{ .HTTPPort }}/freebsd<wait><enter><wait>bsdinstall script /tmp/installerconfig<wait><enter>"]
    data['provisioners'][0]["type"] = "shell"
    # Needed for freebsd: https://www.packer.io/docs/provisioners/shell.html#execute_command
    data['provisioners'][0]["execute_command"] = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
    data['provisioners'][0]["inline"] = "export ASSUME_ALWAYS_YES=yes; pw useradd -n {vmuser} -m; mkdir -m 700 -p /root/.ssh; echo '{sshkey}' > /root/.ssh/authorized_keys; mkdir -m 700 -p ~{vmuser}/.ssh; echo '{sshkey}' > ~{vmuser}/.ssh/authorized_keys; pkg update -f; pkg install -y git; git clone https://github.com/ramesh45345/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{vmprovisionscript} {vmprovision_opts}".format(vmprovisionscript=vmprovisionscript, vmprovision_opts=vmprovision_opts, sshkey=sshkey, vmuser=args.vmuser)
    data['builders'][0]["shutdown_command"] = "shutdown -p now"
if 50 <= args.ostype <= 59:
    data['provisioners'][0]["type"] = "powershell"
    data['builders'][0]["boot_command"] = ["<wait5>"]
    # Shutdown in 4 minutes (for Windows 7, which runs the commands earlier in setup than Windows 10)
    data['builders'][0]["shutdown_command"] = "shutdown /s /t 60"
    data['builders'][0]["shutdown_timeout"] = "15m"
    # Use ssh for communication instead of winrm (which doesn't work for vmware for some reason)
    data['builders'][0]["communicator"] = "ssh"
    data['builders'][0]["ssh_username"] = "{0}".format(args.vmuser)
    data['builders'][0]["floppy_files"] = [os.path.join(tempscriptbasename, "unattend", "autounattend.xml"),
                                           os.path.join(tempscriptbasename, "unattend", "win_initial.bat"),
                                           os.path.join(tempscriptbasename, "unattend", "win_cygssh.bat")]
    # Provision with generic windows script for all but Server Core
    data['provisioners'][0]["scripts"] = [os.path.join(tempscriptfolderpath, "Win-provision.ps1")]
    # Register the namespace to avoid nsX in namespace.
    ET.register_namespace('', "urn:schemas-microsoft-com:unattend")
    ET.register_namespace('wcm', "http://schemas.microsoft.com/WMIConfig/2002/State")
    ET.register_namespace('xsi', "http://www.w3.org/2001/XMLSchema-instance")
if args.ostype == 50:
    shutil.move(os.path.join(tempunattendfolder, "windows10.xml"), os.path.join(tempunattendfolder, "autounattend.xml"))
if args.ostype == 51:
    # Load the xml file
    tree = ET.parse(os.path.join(tempunattendfolder, "windows10.xml"))
    root = tree.getroot()
    # Find specific ProductKey entries, and delete them.
    for a in root:
        if "settings" in a.tag:
            for b in a:
                if "component" in b.tag:
                    for c in b:
                        if "ProductKey" in c.tag:
                            # Remove the productkey element from the parent.
                            b.remove(c)
                        if "UserData" in c.tag:
                            for d in c:
                                if "ProductKey" in d.tag:
                                    c.remove(d)
    # Write the XML file
    tree.write(os.path.join(tempunattendfolder, "autounattend.xml"))
if args.ostype == 54:
    shutil.move(os.path.join(tempunattendfolder, "windows7.xml"), os.path.join(tempunattendfolder, "autounattend.xml"))
if 55 <= args.ostype <= 59:
    # Username is fixed to Administrator in Server
    data['builders'][0]["ssh_username"] = "Administrator"
if 55 <= args.ostype <= 56:
    shutil.move(os.path.join(tempunattendfolder, "windows2016.xml"), os.path.join(tempunattendfolder, "autounattend.xml"))
if args.ostype == 55:
    CFunc.find_replace(tempunattendfolder, "INSERTWINOSIMAGE", "2", "autounattend.xml")
if args.ostype == 56:
    CFunc.find_replace(tempunattendfolder, "INSERTWINOSIMAGE", "1", "autounattend.xml")
if args.ostype == 57:
    # Load the xml file
    tree = ET.parse(os.path.join(tempunattendfolder, "windows2016.xml"))
    root = tree.getroot()
    # Find specific ProductKey entries, and delete them.
    for a in root:
        if "settings" in a.tag:
            for b in a:
                if "component" in b.tag:
                    for c in b:
                        if "ProductKey" in c.tag:
                            # Remove the productkey element from the parent.
                            b.remove(c)
                        if "UserData" in c.tag:
                            for d in c:
                                if "ProductKey" in d.tag:
                                    c.remove(d)
    # Write the XML file
    tree.write(os.path.join(tempunattendfolder, "autounattend.xml"))
    CFunc.find_replace(tempunattendfolder, "INSERTWINOSIMAGE", "1", "autounattend.xml")


# Write packer json file.
with open(os.path.join(packer_temp_folder, 'file.json'), 'w') as file_json_wr:
    json.dump(data, file_json_wr, indent=2)

# Save start time.
beforetime = datetime.now()
# Call packer.
subprocess.run("packer build file.json", shell=True)
# Save packer finish time.
packerfinishtime = datetime.now()

# Remove temp folder
os.chdir(vmpath)
output_folder = os.path.join(packer_temp_folder, vmname)
# Copy output to VM folder.
if os.path.isdir(output_folder):
    # Remove previous folder, if it exists.
    if os.path.isdir(os.path.join(vmpath, vmname)):
        shutil.rmtree(os.path.join(vmpath, vmname))
    # Remove existing VMs in KVM
    if args.vmtype == 2:
        kvmlist = CFunc.subpout("virsh --connect qemu:///system -q list --all")
        if vmname.lower() in kvmlist.lower():
            subprocess.run('virsh --connect qemu:///system destroy "{0}"'.format(vmname), shell=True)
            subprocess.run('virsh --connect qemu:///system undefine "{0}"'.format(vmname), shell=True)
    # Remove previous file for kvm.
    if args.vmtype == 2 and os.path.isfile(os.path.join(vmpath, vmname+".qcow2")):
        os.remove(os.path.join(vmpath, vmname+".qcow2"))
    print("\nCopying {0} to {1}.".format(output_folder, vmpath))
    if args.vmtype != 2:
        shutil.copytree(output_folder, os.path.join(vmpath, vmname))
    # Copy the qcow2 file, and remove the folder entirely for kvm.
    if args.vmtype == 2 and os.path.isfile(os.path.join(output_folder, vmname+".qcow2")):
        shutil.copy2(os.path.join(output_folder, vmname+".qcow2"), os.path.join(vmpath, vmname+".qcow2"))
print("Removing {0}".format(packer_temp_folder))
shutil.rmtree(packer_temp_folder)
print("VM successfully output to {0}".format(os.path.join(vmpath, vmname)))
# Save full finish time.
fullfinishtime = datetime.now()

# Attach VM to libvirt
if args.vmtype == 2:
    if 50 <= args.ostype <= 59:
        kvm_video = "qxl"
        kvm_diskinterface = "ide"
        kvm_netdevice = "virtio"
    else:
        kvm_video = "virtio"
        kvm_diskinterface = "virtio"
        kvm_netdevice = "virtio"
    CREATESCRIPT_KVM = """virt-install --connect qemu:///system --name={vmname} --disk path={fullpathtoimg}.qcow2,bus={kvm_diskinterface} --graphics spice --vcpu={cpus} --ram={memory} --network bridge=virbr0,model={kvm_netdevice} --filesystem source=/,target=root,mode=mapped --os-type={kvm_os} --os-variant={kvm_variant} --import --noautoconsole --video={kvm_video} --channel unix,target_type=virtio,name=org.qemu.guest_agent.0""".format(vmname=vmname, memory=args.memory, cpus=CPUCORES, fullpathtoimg=os.path.join(vmpath, vmname), kvm_os=kvm_os, kvm_variant=kvm_variant, kvm_video=kvm_video, kvm_diskinterface=kvm_diskinterface, kvm_netdevice=kvm_netdevice)
    print(CREATESCRIPT_KVM)
    subprocess.run(CREATESCRIPT_KVM, shell=True)

# Print finish times
print("Packer completed in :", packerfinishtime - beforetime)
print("Whole thing completed in :", fullfinishtime - beforetime)
