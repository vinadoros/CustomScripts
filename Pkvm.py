#!/usr/bin/env python3
"""Create a virtual machine image using Packer"""

# Python includes.
import argparse
import crypt
from datetime import datetime
import grp
import json
import hashlib
import multiprocessing
import os
import pwd
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
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

# Exit if root.
if os.geteuid() is 0:
    sys.exit("\nError: Please run this script as a normal (non root) user.\n")

# Get non-root user information.
if os.getenv("SUDO_USER") not in ["root", None]:
    USERNAMEVAR = os.getenv("SUDO_USER")
elif os.getenv("USER") not in ["root", None]:
    USERNAMEVAR = os.getenv("USER")
else:
    # https://docs.python.org/3/library/pwd.html
    USERNAMEVAR = pwd.getpwuid(1000)[0]
# https://docs.python.org/3/library/grp.html
USERGROUP = grp.getgrgid(pwd.getpwnam(USERNAMEVAR)[3])[0]
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
    packer_zipurl = "https://releases.hashicorp.com/packer/1.1.2/packer_1.1.2_linux_amd64.zip"
    packer_zipfile = CFunc.downloadfile(packer_zipurl, "/tmp")[0]
    subprocess.run("unzip -o {0} -d /usr/local/bin".format(packer_zipfile), shell=True)
    os.chmod("/usr/local/bin/packer", 0o777)
    if os.path.isfile(packer_zipfile):
        os.remove(packer_zipfile)
    subprocess.run("packer -v", shell=True)

# Ensure that certain commands exist.
cmdcheck = ["packer", "ssh"]
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

# Set OS options.
# KVM os options can be found by running "osinfo-query os"
if args.ostype == 1:
    vmname = "Packer-Fedora-{0}".format(hvname)
    vmprovisionscript = "MFedora.py"
    vmprovision_defopts = "-d {0} -a".format(args.desktopenv)
    vboxosid = "Fedora_64"
    vmwareid = "fedora-64"
    kvm_os = "linux"
    kvm_variant = "fedora25"
    isourl = "https://download.fedoraproject.org/pub/fedora/linux/releases/27/Server/x86_64/iso/Fedora-Server-dvd-x86_64-27-1.6.iso"
if 2 <= args.ostype <= 3:
    vboxosid = "Fedora_64"
    vmwareid = "fedora-64"
    kvm_os = "linux"
    kvm_variant = "fedora22"
    isourl = "https://mirrors.kernel.org/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1708.iso"
    vmprovisionscript = "MCentOS.py"
if args.ostype == 2:
    vmname = "Packer-CentOS-{0}".format(hvname)
    vmprovision_defopts = "-d -r"
if args.ostype == 3:
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
    isourl = "http://download.opensuse.org/tumbleweed/iso/openSUSE-Tumbleweed-DVD-x86_64-Current.iso"
if args.ostype == 40:
    vmname = "Packer-FreeBSD-{0}".format(hvname)
    vboxosid = "FreeBSD_64"
    vmwareid = "freebsd-64"
    vmprovisionscript = "MFreeBSD.sh"
    vmprovision_defopts = " "
    kvm_os = "freebsd"
    kvm_variant = "freebsd11.0"
    isourl = "https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/11.0/FreeBSD-11.0-RELEASE-amd64-disc1.iso"
if args.ostype == 50:
    vmname = "Packer-Windows10-{0}".format(hvname)
    vboxosid = "Windows10_64"
    vmwareid = "windows9-64"
    kvm_os = "windows"
    kvm_variant = "win10"
    vmprovision_defopts = " "
    isourl = None
if args.ostype == 51:
    vmname = "Packer-Windows7-{0}".format(hvname)
    vboxosid = "Windows7_64"
    vmwareid = "windows7-64"
    kvm_os = "windows"
    kvm_variant = "win7"
    vmprovision_defopts = " "
    isourl = None
if args.ostype == 52:
    vmname = "Packer-Windows2016-{0}".format(hvname)
    vboxosid = "Windows2016_64"
    vmwareid = "windows9srv-64"
    kvm_os = "windows"
    kvm_variant = "win10"
    vmprovision_defopts = " "
    isourl = None
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
    subprocess.run('vboxmanage setproperty machinefolder "{0}"'.format(vmpath), shell=True, check=True)
    status = subprocess.run('vboxmanage list hostonlyifs | grep -i vboxnet0', shell=True)
    if status.returncode is not 0:
        print("Creating vboxnet0 hostonlyif.")
        subprocess.run("vboxmanage hostonlyif create", shell=True, check=True)
        # Set DHCP active on created adapter
        subprocess.run("vboxmanage hostonlyif ipconfig vboxnet0 --ip 192.168.253.1", shell=True, check=True)
        subprocess.run("vboxmanage dhcpserver modify --ifname vboxnet0 --ip 192.168.253.1 --netmask 255.255.255.0 --lowerip 192.168.253.2 --upperip 192.168.253.253 --enable", shell=True, check=True)

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
packer_temp_folder = vmpath+"/packertemp"+vmname
if os.path.isdir(packer_temp_folder):
    print("\nDeleting old VM.")
    shutil.rmtree(packer_temp_folder)
os.mkdir(packer_temp_folder)
os.chdir(packer_temp_folder)

# Detect root ssh key.
if args.sshkey is not None:
    sshkey = args.rootsshkey
elif os.path.isfile(USERHOME+"/.ssh/id_ed25519.pub") is True:
    with open(USERHOME+"/.ssh/id_ed25519.pub", 'r') as sshfile:
        sshkey = sshfile.read().replace('\n', '')
elif os.path.isfile(USERHOME+"/.ssh/id_rsa.pub") is True:
    with open(USERHOME+"/.ssh/id_rsa.pub", 'r') as sshfile:
        sshkey = sshfile.read().replace('\n', '')
else:
    sshkey = " "
print("SSH Key is \"{0}\"".format(sshkey))

# Generate hashed password
# https://serverfault.com/questions/330069/how-to-create-an-sha-512-hashed-password-for-shadow#330072
sha512_password = crypt.crypt(args.vmpass, crypt.mksalt(crypt.METHOD_SHA512))


# Copy unattend script folder
if os.path.isdir(SCRIPTDIR+"/unattend"):
    tempunattendfolder = packer_temp_folder+"/unattend"
    shutil.copytree(SCRIPTDIR+"/unattend", tempunattendfolder)
    # Set usernames and passwords
    subprocess.run("find {0} -type f -print0 | xargs -0 sed -i'' -e 's/INSERTUSERHERE/{1}/g'".format(tempunattendfolder, args.vmuser), shell=True)
    subprocess.run("find {0} -type f -print0 | xargs -0 sed -i'' -e 's/INSERTPASSWORDHERE/{1}/g'".format(tempunattendfolder, args.vmpass), shell=True)
    subprocess.run("find {0} -type f -print0 | xargs -0 sed -i'' -e 's/INSERTFULLNAMEHERE/{1}/g'".format(tempunattendfolder, args.fullname), shell=True)
    subprocess.run("find {0} -type f -print0 | xargs -0 sed -i'' -e 's/INSERTHOSTNAMENAMEHERE/{1}/g'".format(tempunattendfolder, vmname), shell=True)
    subprocess.run("find {0} -type f -print0 | xargs -0 sed -i'' -e 's@INSERTHASHEDPASSWORDHERE@{1}@g'".format(tempunattendfolder, sha512_password), shell=True)
    subprocess.run("find {0} -type f -print0 | xargs -0 sed -i'' -e 's/INSERTSSHKEYHERE/{1}/g'".format(tempunattendfolder, sshkey), shell=True)


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
    data['builders'][0]["vboxmanage"].append(["modifyvm", "{{.Name}}", "--hostonlyadapter2", "vboxnet0"])
    data['builders'][0]["vboxmanage_post"] = ['']
    data['builders'][0]["vboxmanage_post"][0] = ["sharedfolder", "add", "{{.Name}}", "--name", "root", "--hostpath", "/", "--automount"]
    data['builders'][0]["vboxmanage_post"].append(["modifyvm", "{{.Name}}", "--clipboard", "bidirectional"])
    data['builders'][0]["vboxmanage_post"].append(["modifyvm", "{{.Name}}", "--accelerate3d", "on"])

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
        data['builders'][0]["disk_interface"] = "ide"
        data['builders'][0]["net_device"] = "e1000"
    else:
        data['builders'][0]["disk_interface"] = "virtio"
        data['builders'][0]["net_device"] = "virtio-net"
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
data['builders'][0]["shutdown_command"] = "shutdown -P now"
data['builders'][0]["iso_url"] = "file://"+isopath
data['builders'][0]["iso_checksum"] = md5
data['builders'][0]["iso_checksum_type"] = "md5"
data['builders'][0]["output_directory"] = "{0}".format(vmname)
data['builders'][0]["http_directory"] = "unattend"
data['builders'][0]["disk_size"] = "{0}".format(args.imgsize)
data['builders'][0]["boot_wait"] = "5s"
data['builders'][0]["ssh_username"] = "root"
data['builders'][0]["ssh_password"] = "{0}".format(args.vmpass)
data['builders'][0]["ssh_wait_timeout"] = "90m"
# Packer Provisioning Configuration
data['provisioners'] = ['']
data['provisioners'][0] = {}
if args.ostype is 1:
    data['builders'][0]["boot_command"] = ["<tab> inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/fedora.cfg<enter><wait>"]
    data['provisioners'][0]["type"] = "shell"
    data['provisioners'][0]["inline"] = "dnf install -y git; git clone https://github.com/vinadoros/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{0} {1}".format(vmprovisionscript, vmprovision_opts)
if 2 <= args.ostype <= 3:
    data['builders'][0]["boot_command"] = ["<tab> text ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos7-ks.cfg<enter><wait>"]
    data['provisioners'][0]["type"] = "shell"
    data['provisioners'][0]["inline"] = "yum install -y git; git clone https://github.com/vinadoros/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{0} {1}".format(vmprovisionscript, vmprovision_opts)
if 10 <= args.ostype <= 11:
    data['builders'][0]["boot_command"] = ["<enter><wait><f6><wait><esc><home>url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu.cfg hostname=ubuntu locale=en_US keyboard-configuration/modelcode=SKIP netcfg/choose_interface=auto <enter>"]
    data['provisioners'][0]["type"] = "shell"
    data['provisioners'][0]["inline"] = "mkdir -m 700 -p /root/.ssh; echo '{sshkey}' > /root/.ssh/authorized_keys; mkdir -m 700 -p ~{vmuser}/.ssh; echo '{sshkey}' > ~{vmuser}/.ssh/authorized_keys; chown {vmuser}:{vmuser} -R ~{vmuser}; apt install -y git; git clone https://github.com/vinadoros/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{vmprovisionscript} {vmprovision_opts}".format(vmprovisionscript=vmprovisionscript, vmprovision_opts=vmprovision_opts, sshkey=sshkey, vmuser=args.vmuser)
if 20 <= args.ostype <= 21:
    data['builders'][0]["boot_command"] = ["<wait><down><wait><f4><wait><esc><wait>autoyast2=http://{{ .HTTPIP }}:{{ .HTTPPort }}/opensuse.cfg textmode=1<enter>"]
    data['provisioners'][0]["type"] = "shell"
    data['provisioners'][0]["inline"] = 'while ! zypper install -yl --no-recommends git; do sleep 5; done; git clone https://github.com/vinadoros/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{0} {1}'.format(vmprovisionscript, vmprovision_opts)
if 40 <= args.ostype <= 41:
    data['builders'][0]["boot_command"] = ["<wait><enter><wait10><wait10><right><enter><wait>dhclient -b vtnet0<enter><wait>dhclient -b em0<enter><wait10>fetch -o /tmp/installerconfig http://{{ .HTTPIP }}:{{ .HTTPPort }}/freebsd<wait><enter><wait>bsdinstall script /tmp/installerconfig<wait><enter>"]
    data['provisioners'][0]["type"] = "shell"
    # Needed for freebsd: https://www.packer.io/docs/provisioners/shell.html#execute_command
    data['provisioners'][0]["execute_command"] = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
    data['provisioners'][0]["inline"] = 'export ASSUME_ALWAYS_YES=yes; pkg update -f; pkg install -y git; git clone https://github.com/vinadoros/CustomScripts /opt/CustomScripts; /opt/CustomScripts/{0} {1}'.format(vmprovisionscript, vmprovision_opts)
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
    data['builders'][0]["floppy_files"] = ["unattend/autounattend.xml",
                                           "unattend/win_initial.bat",
                                           "unattend/win_openssh.bat"]
    # Provision with generic windows script
    data['provisioners'][0]["script"] = packer_temp_folder+"/unattend/win_custom.ps1"
if args.ostype == 50:
    shutil.move(packer_temp_folder+"/unattend/windows10.xml", packer_temp_folder+"/unattend/autounattend.xml")
if args.ostype == 51:
    shutil.move(packer_temp_folder+"/unattend/windows7.xml", packer_temp_folder+"/unattend/autounattend.xml")
if args.ostype == 52:
    # Username is fixed to Administrator in Server 2016
    data['builders'][0]["ssh_username"] = "Administrator"
    shutil.move(packer_temp_folder+"/unattend/windows2016.xml", packer_temp_folder+"/unattend/autounattend.xml")


# Write packer json file.
with open(packer_temp_folder+'/file.json', 'w') as file_json_wr:
    json.dump(data, file_json_wr, indent=2)

# Save start time.
beforetime = datetime.now()
# Call packer.
subprocess.run("packer build file.json", shell=True)
# Save packer finish time.
packerfinishtime = datetime.now()

# Remove temp folder
os.chdir(vmpath)
output_folder = packer_temp_folder+"/"+vmname
# Copy output to VM folder.
if os.path.isdir(output_folder):
    # Remove previous folder, if it exists.
    if os.path.isdir(vmpath+"/"+vmname):
        shutil.rmtree(vmpath+"/"+vmname)
    # Remove existing VMs in KVM
    if args.vmtype == 2:
        kvmlist = CFunc.subpout("virsh --connect qemu:///system -q list --all")
        if vmname.lower() in kvmlist.lower():
            subprocess.run('virsh --connect qemu:///system destroy "{0}"'.format(vmname), shell=True)
            subprocess.run('virsh --connect qemu:///system undefine "{0}"'.format(vmname), shell=True)
    # Remove previous file for kvm.
    if args.vmtype == 2 and os.path.isfile(vmpath+"/"+vmname+".qcow2"):
        os.remove(vmpath+"/"+vmname+".qcow2")
    print("\nCopying {0} to {1}.".format(output_folder, vmpath))
    if args.vmtype != 2:
        shutil.copytree(output_folder, vmpath+"/"+vmname)
    # Copy the qcow2 file, and remove the folder entirely for kvm.
    if args.vmtype == 2 and os.path.isfile(output_folder+"/"+vmname+".qcow2"):
        shutil.copy2(output_folder+"/"+vmname+".qcow2", vmpath+"/"+vmname+".qcow2")
print("Removing {0}".format(packer_temp_folder))
shutil.rmtree(packer_temp_folder)
print("VM successfully output to {0}".format(vmpath+"/"+vmname))
# Save full finish time.
fullfinishtime = datetime.now()

# Attach VM to libvirt
if args.vmtype == 2:
    CREATESCRIPT_KVM = """virt-install --connect qemu:///system --name={vmname} --disk path={fullpathtoimg}.qcow2,bus=virtio --graphics spice --vcpu={cpus} --ram={memory} --network bridge=virbr0,model=virtio --filesystem source=/,target=root,mode=mapped --os-type={kvm_os} --os-variant={kvm_variant} --import --noautoconsole --video=virtio --channel unix,target_type=virtio,name=org.qemu.guest_agent.0""".format(vmname=vmname, memory=args.memory, cpus=CPUCORES, fullpathtoimg=vmpath+"/"+vmname, kvm_os=kvm_os, kvm_variant=kvm_variant)
    print(CREATESCRIPT_KVM)
    subprocess.run(CREATESCRIPT_KVM, shell=True)

# Print finish times
print("Packer completed in :", packerfinishtime - beforetime)
print("Whole thing completed in :", fullfinishtime - beforetime)
