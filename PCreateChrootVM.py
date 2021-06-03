#!/usr/bin/env python3
"""Create a VM from a chroot environment."""

# Python includes.
import argparse
import datetime
import ipaddress
import logging
import multiprocessing
import os
import shutil
import subprocess
import sys
import time
# Custom includes
import CFunc

# Folder of this script
SCRIPTDIR = sys.path[0]

### Functions ###
def vm_getip(vmname: str):
    """Get IP address of Virtual Machine."""
    ip = None
    while ip is None:
        # Note: domifaddr does not always work. Use domiflist to get mac address and then look up ip using "ip neighbor" command.
        mac_list = []
        mac_sp = subprocess.run("virsh --connect qemu:///system -q domiflist '{0}'".format(vmname), shell=True, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        mac_status = mac_sp.returncode
        if mac_status == 0:
            mac_list = mac_sp.stdout.split()
            # Make sure the output is a list and has 5 elements, as opposed to being empty.
            if isinstance(mac_list, list) and len(mac_list) == 5:
                ip_list = subprocess.run("ip neigh show dev virbr0 | grep '{0}'".format(mac_list[4]), shell=True, check=False, stdout=subprocess.PIPE).stdout.splitlines()
                # Process every IP line given, and split it into a list.
                for ip_line in ip_list:
                    ip_line_decoded = ip_line.decode().split()
                    # Make sure the output is a list and has at least 1 element, as opposed to being empty.
                    if isinstance(ip_line_decoded, list) and len(ip_line_decoded) == 4:
                        ip = ip_line_decoded[0]
                        # Check for a valid IP address.
                        try:
                            # Test if it is an IPv4 or IPv6 address.
                            ipaddress.ip_address(ip)
                            # For now, enforce ipv4, since can't connect to ssh in ipv6 address.
                            # TODO: Later convert to ssh connection test, reject IP if ssh doesn't connect.
                            if not isinstance(ipaddress.ip_address(ip), ipaddress.IPv4Address):
                                raise Exception()
                            logging.debug('%s is a correct IP address.', ip)
                            return ip
                        except:
                            logging.debug('Address/Netmask is invalid: %s', ip)
                            ip = None
        else:
            if mac_sp.stderr:
                logging.debug("Mac stderr: %s", mac_sp.stderr)
        time.sleep(1)
    return ip
def vm_getimgpath(vmname: str, folder_path: str):
    """Get the hypothetical full path of a VM image."""
    imgfile_fullpath = os.path.abspath(os.path.join(folder_path, "{0}.qcow2".format(vmname)))
    return imgfile_fullpath
def vm_createimage(img_path: str, size_gb: int):
    """Create a VM image file."""
    subprocess.run("qemu-img create -f qcow2 -o compat=1.1,lazy_refcounts=on '{0}' {1}G".format(img_path, size_gb), shell=True, check=True)
def vm_create(vmname: str, img_path: str, isopath: str, kvm_os: str):
    """Create the VM in libvirt."""
    # virt-install manual: https://www.mankier.com/1/virt-install
    # List of os: osinfo-query os
    CREATESCRIPT_KVM = """virt-install --connect qemu:///system --name={vmname} --install bootdev=cdrom --boot=hd,cdrom --disk device=cdrom,path="{isopath}",bus=sata,target=sda,readonly=on --disk path={fullpathtoimg},bus=virtio --graphics spice --vcpu={cpus} --ram={memory} --network bridge=virbr0,model=virtio --filesystem source=/,target=root,mode=mapped --os-type={kvm_os} --os-variant={kvm_variant} --import --noautoconsole --noreboot --video=virtio --channel unix,target_type=virtio,name=org.qemu.guest_agent.0 --channel spicevmc,target_type=virtio,name=com.redhat.spice.0 --boot uefi""".format(vmname=vmname, memory=args.memory, cpus=CPUCORES, fullpathtoimg=img_path, kvm_os=kvm_os, kvm_variant=kvm_variant, isopath=isopath)
    logging.info("KVM launch command: {0}".format(CREATESCRIPT_KVM))
    subprocess.run(CREATESCRIPT_KVM, shell=True, check=True)
def vm_ejectiso(vmname: str):
    """Eject an iso from a VM."""
    subprocess.run("virsh --connect qemu:///system change-media {0} sda --eject --config".format(vmname), shell=True, check=False)
def vm_create_existingimage(vmname: str, vmpath: str, backing_img_path: str, kvm_os: str):
    """Create the VM in libvirt, using an existing image as a backing store."""
    # virt-install manual: https://www.mankier.com/1/virt-install
    # List of os: osinfo-query os
    CREATESCRIPT_KVM = """virt-install --connect qemu:///system --name={vmname} --install --boot=hd --disk size=100,backing_store={backing_img_path},bus=virtio,path={imgpath} --disk path={backing_img_path},bus=virtio --graphics spice --vcpu={cpus} --ram={memory} --network bridge=virbr0,model=virtio --filesystem source=/,target=root,mode=mapped --os-type={kvm_os} --os-variant={kvm_variant} --import --noautoconsole --noreboot --video=virtio --channel unix,target_type=virtio,name=org.qemu.guest_agent.0 --channel spicevmc,target_type=virtio,name=com.redhat.spice.0 --boot uefi""".format(vmname=vmname, memory=args.memory, cpus=CPUCORES, imgpath=os.path.join(vmpath, vmname + ".qcow2"), backing_img_path=backing_img_path, kvm_os=kvm_os, kvm_variant=kvm_variant)
    logging.info("KVM launch command: {0}".format(CREATESCRIPT_KVM))
    subprocess.run(CREATESCRIPT_KVM, shell=True, check=True)
def ssh_vm(ip: str, command: str, ssh_opts: str = "", port: int = 22, user: str = "root", password: str = "asdf"):
    """SSH into the Virtual Machine and run a command."""
    status = subprocess.run("""sshpass -p "{password}" ssh {ssh_opts} {ip} -p {port} -l {user} '{command}'""".format(password=password, ip=ip, port=port, user=user, command=command, ssh_opts=ssh_opts), shell=True, check=False).returncode
    return status
def scp_vm(ip: str, filepath: str, destination: str, port: int = 22, user: str = "root", password: str = "asdf"):
    """Copy files into the Virtual Machine."""
    status = subprocess.run("""sshpass -p "{password}" scp -P {port} "{filepath}" {user}@{ip}:{destination}""".format(password=password, ip=ip, port=port, user=user, filepath=filepath, destination=destination), shell=True, check=False).returncode
    return status
def ssh_wait(ip: str, port: int = 22, user: str = "root", password: str = "asdf", retries: int = 10000):
    """Wait for ssh to connect successfully to the VM."""
    logging.info("Waiting for VM to boot.")
    status = 1
    attempt = 0
    # Run ssh in quiet mode.
    while status != 0 and attempt < retries:
        logging.debug("SSH status was %s, attempt %s, waiting.", status, attempt)
        time.sleep(5)
        status = ssh_vm(ip=ip, port=port, user=user, password=password, command="echo Connected", ssh_opts="-q")
        attempt += 1
    if status != 0:
        logging.info("ERROR: ssh_wait could not connect.")
    return status
def vm_check_onoff(vmname: str):
    """Check if a VM is started or not. Return True if VM is on."""
    status = subprocess.run('virsh --connect qemu:///system -q list | grep -i "{0}"'.format(vmname), shell=True, check=False, stdout=subprocess.DEVNULL).returncode
    return bool(status == 0)
def vm_start(vmname: str):
    """Start the VM."""
    if not vm_check_onoff(vmname=vmname):
        # Start the VM
        logging.info("Starting VM %s", vmname)
        subprocess.run("virsh --connect qemu:///system start {0}".format(vmname), shell=True, check=True)
        time.sleep(5)
def vm_shutdown(vmname: str, timeout_minutes: int = 5):
    """Shutdown the VM. Timeout in minutes."""
    logging.info("Shutting down VM %s", vmname)
    vm_is_on = vm_check_onoff(vmname=vmname)
    # Issue a shutdown if the VM is on.
    if vm_is_on:
        subprocess.run("virsh --connect qemu:///system shutdown {0}".format(vmname), shell=True, check=True, stdout=subprocess.DEVNULL)
        # Save time variables.
        current_time_saved = datetime.datetime.now()
        current_time_diff = 0
        # Check if VM is shutdown every 5 seconds.
        while vm_is_on and current_time_diff < timeout_minutes:
            time.sleep(5)
            vm_is_on = vm_check_onoff(vmname=vmname)
            current_time_diff = (datetime.datetime.now() - current_time_saved).total_seconds() / 60
        # If after timeout is exceeded, force off the VM.
        if vm_is_on and current_time_diff >= timeout_minutes:
            logging.debug("Force Shutting down VM %s", vmname)
            subprocess.run("virsh --connect qemu:///system destroy {0}".format(vmname), shell=True, check=True, stdout=subprocess.DEVNULL)
def vm_cleanup(vmname: str, img_path: str):
    """Cleanup existing VM."""
    # Destroy and undefine the VM.
    vm_shutdown(vmname)
    subprocess.run("virsh --connect qemu:///system undefine --snapshots-metadata --nvram {0}".format(vmname), shell=True, check=False)
    # Delete the image file.
    if os.path.isfile(img_path):
        os.remove(img_path)
def vm_runscript(ip: str, port: int, user: str, password: str, script: str):
    """Run a script (passed as a variable) on a VM."""
    # Write the script to a file.
    # Make the file executable.
    # SCP the file to the host.
    # Run the file in the VM.
    # Remove the file from host and guest.
def git_branch_retrieve():
    """Retrieve the current branch of this script's git repo."""
    git_branch = None
    if shutil.which("git"):
        original_working_folder = os.getcwd()
        os.chdir(SCRIPTDIR)
        git_branch = CFunc.subpout("git rev-parse --abbrev-ref HEAD")
        os.chdir(original_working_folder)
    else:
        git_branch = "master"
    return git_branch
def git_cmdline(destination=os.path.join(os.sep, "opt", "CustomScripts")):
    """Compose the git command line to check out the repo."""
    git_branch = git_branch_retrieve()
    git_cmd = "git clone https://github.com/ramesh45345/CustomScripts {0} -b {1}".format(destination, git_branch)
    return git_cmd


if __name__ == '__main__':
    print("Running {0}".format(__file__))

    # Exit if root.
    CFunc.is_root(False)

    # Get non-root user information.
    USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
    CPUCORES = multiprocessing.cpu_count() if multiprocessing.cpu_count() <= 4 else 4

    # Ensure that certain commands exist.
    cmdcheck = ["ssh", "sshpass", "qemu-img", "virsh", "ip"]
    for cmd in cmdcheck:
        if not shutil.which(cmd):
            sys.exit("\nError, ensure command {0} is installed.".format(cmd))

    # Get arguments
    parser = argparse.ArgumentParser(description='Create and run a Virtual Machine.')
    parser.add_argument("-a", "--ostype", type=int, help="OS type (1=Arch, 3=Debian)", default=1)
    parser.add_argument("-d", "--debug", help='Use Debug Logging', action="store_true")
    parser.add_argument("-e", "--desktopenv", help="Desktop Environment (defaults to mate)", default="mate")
    parser.add_argument("-f", "--fullname", help="Full Name", default="User Name")
    parser.add_argument("-i", "--iso", help="Path to live cd", required=True)
    parser.add_argument("-n", "--vmname", help="Name of Virtual Machine")
    parser.add_argument("-p", "--vmpath", help="Path of Virtual Machine folders", required=True)
    parser.add_argument("-v", "--rootsshkey", help="Root SSH Key")
    parser.add_argument("-w", "--livesshuser", help="Live SSH Username", default="root")
    parser.add_argument("-x", "--livesshpass", help="Live SSH Password", default="asdf")
    parser.add_argument("-y", "--vmuser", help="VM Username", default="user")
    parser.add_argument("-z", "--vmpass", help="VM Password", default="asdf")
    parser.add_argument("--memory", help="Memory for VM", default=4096)
    parser.add_argument("--noprompt", help='Do not prompt to continue.', action="store_true")
    args = parser.parse_args()

    # Enable logging
    if args.debug:
        logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(message)s')
    else:
        logging.basicConfig(level=logging.INFO, format='%(message)s')

    # Set paths
    vmpath = os.path.abspath(args.vmpath)
    iso_path = os.path.abspath(args.iso)

    # Detect root ssh key.
    if args.rootsshkey is not None:
        sshkey = args.rootsshkey
    elif os.path.isfile(os.path.join(USERHOME, ".ssh", "id_ed25519.pub")) is True:
        with open(os.path.join(USERHOME, ".ssh", "id_ed25519.pub"), 'r') as sshfile:
            sshkey = sshfile.read().replace('\n', '')
    elif os.path.isfile(os.path.join(USERHOME, ".ssh", "id_rsa.pub")) is True:
        with open(os.path.join(USERHOME, ".ssh", "id_rsa.pub"), 'r') as sshfile:
            sshkey = sshfile.read().replace('\n', '')
    else:
        sshkey = " "

    # Determine VM Name
    # https://download.fedoraproject.org/pub/fedora/linux/releases/34/Cloud/x86_64/images/
    # https://cloud-images.ubuntu.com/releases/focal/release/
    vm_backing_img = ""
    if args.ostype == 1:
        vm_name = "CC-Arch-kvm"
        # Modify alis
        temp_folder = os.path.join(os.sep, "tmp")
        temp_alis = os.path.join(temp_folder, "alis.conf")
        shutil.copy(os.path.join(SCRIPTDIR, "unattend", "alis.conf"), temp_alis)
        # Set usernames and passwords
        CFunc.find_replace(temp_folder, "INSERTUSERHERE", args.vmuser, "alis.conf")
        CFunc.find_replace(temp_folder, "INSERTPASSWORDHERE", args.vmpass, "alis.conf")
        CFunc.find_replace(temp_folder, "INSERTHOSTNAMENAMEHERE", vm_name, "alis.conf")
        # VM commands
        vmbootstrap_cmd = 'cd /opt/CustomScripts && git checkout -f && git pull && git checkout {gitbranch} && cd ~ && curl -sL https://raw.githubusercontent.com/picodotdev/alis/master/download.sh | bash && cp /root/alis_new.conf /root/alis.conf && cp /root/alis-packages_new.conf /root/alis-packages.conf && export LANG=en_US.UTF-8 && yes | ./alis.sh && echo "PermitRootLogin yes" >> /mnt/etc/ssh/sshd_config && poweroff'.format(gitbranch=git_branch_retrieve())
        vmprovision_cmd = "mkdir -m 700 -p /root/.ssh; echo '{sshkey}' > /root/.ssh/authorized_keys; mkdir -m 700 -p ~{vmuser}/.ssh; echo '{sshkey}' > ~{vmuser}/.ssh/authorized_keys; chown {vmuser}:users -R ~{vmuser}; pacman -Sy --noconfirm git; {gitcmd}; /opt/CustomScripts/MArch.py -d {desktop}".format(vmuser=args.vmuser, sshkey=sshkey, gitcmd=git_cmdline(), desktop=args.desktopenv)
        kvm_variant = "archlinux"
    if args.ostype == 3:
        vm_name = "CC-Debian-kvm"
        # Image url
        # https://cloud.debian.org/images/cloud/sid/daily/
        # Username and password for initial bootstrap
        vm_backing_img = ""
        # VM commands
        vmbootstrap_cmd = 'cd /opt/CustomScripts && git checkout -f && git pull && git checkout {gitbranch} && cd ~ && curl -sL https://raw.githubusercontent.com/picodotdev/alis/master/download.sh | bash && cp /root/alis_new.conf /root/alis.conf && cp /root/alis-packages_new.conf /root/alis-packages.conf && export LANG=en_US.UTF-8 && yes | ./alis.sh && echo "PermitRootLogin yes" >> /mnt/etc/ssh/sshd_config && poweroff'.format(gitbranch=git_branch_retrieve())
        vmprovision_cmd = "mkdir -m 700 -p /root/.ssh; echo '{sshkey}' > /root/.ssh/authorized_keys; mkdir -m 700 -p ~{vmuser}/.ssh; echo '{sshkey}' > ~{vmuser}/.ssh/authorized_keys; chown {vmuser}:users -R ~{vmuser}; pacman -Sy --noconfirm git; {gitcmd}; /opt/CustomScripts/MArch.py -d {desktop}".format(vmuser=args.vmuser, sshkey=sshkey, gitcmd=git_cmdline(), desktop=args.desktopenv)
        kvm_variant = "debiantesting"

    # Override VM Name if provided
    if args.vmname is not None:
        vm_name = args.vmname
    print("VM Name is {0}".format(vm_name))
    print("Path to LiveCD/ISO is {0}".format(iso_path))
    print("OS Type is {0}".format(args.ostype))
    print("VM Memory is {0}".format(args.memory))
    print("Live SSH user is {0}".format(args.livesshuser))
    print("VM User is {0}".format(args.vmuser))
    print("SSH Key is \"{0}\"".format(sshkey))

    # Variables less likely to change.
    sship = None
    localsshport = 22

    imgsize = "64"

    if not os.path.isdir(vmpath) or not os.path.isfile(iso_path):
        sys.exit("\nError, ensure {0} is a folder, and {1} is a file.".format(vmpath, iso_path))

    if args.noprompt is False:
        input("Press Enter to continue.")

    ### Begin Code ###

    # Run this if we are destroying (not keeping) the VM.
    imgpath = vm_getimgpath(vm_name, vmpath)
    vm_cleanup(vm_name, imgpath)

    # Create new VM.
    print("\nCreating VM.")
    if args.ostype == 1:
        vm_createimage(imgpath, imgsize)
        vm_create(vm_name, imgpath, iso_path, kvm_variant)
    else:
        vm_create_existingimage(vm_name, vmpath, vm_backing_img, kvm_variant)
    # Bootstrap the VM.
    vm_start(vm_name)
    sship = vm_getip(vm_name)
    ssh_wait(ip=sship, port=localsshport, user=args.livesshuser, password=args.livesshpass)
    # Pre-bootstrap commands
    if args.ostype == 1:
        scp_vm(ip=sship, port=localsshport, user=args.livesshuser, password=args.livesshpass, filepath=temp_alis, destination="/root/alis_new.conf")
        scp_vm(ip=sship, port=localsshport, user=args.livesshuser, password=args.livesshpass, filepath=os.path.join(SCRIPTDIR, "unattend", "alis-packages.conf"), destination="/root/alis-packages_new.conf")
    ssh_vm(ip=sship, port=localsshport, user=args.livesshuser, password=args.livesshpass, command=vmbootstrap_cmd)
    vm_shutdown(vm_name)
    # Eject cdrom
    vm_ejectiso(vm_name)
    time.sleep(5)
    # Provision the VM.
    vm_start(vm_name)
    sship = vm_getip(vm_name)
    ssh_wait(ip=sship, port=localsshport, user="root", password=args.vmpass)
    ssh_vm(ip=sship, port=localsshport, user="root", password=args.vmpass, command=vmprovision_cmd)
    vm_shutdown(vm_name)
