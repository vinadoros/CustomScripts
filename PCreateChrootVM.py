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
        # Note: domifaddr does not always work. Use domiflist to get mac address and then look up ip using arp.
        mac_list = []
        mac_sp = subprocess.run("virsh --connect qemu:///system -q domiflist '{0}'".format(vmname), shell=True, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        mac_status = mac_sp.returncode
        if mac_status == 0:
            mac_list = mac_sp.stdout.split()
            # Make sure the output is a list and has 5 elements, as opposed to being empty.
            if isinstance(mac_list, list) and len(mac_list) == 5:
                ip_list = subprocess.run("arp -en -i virbr0 | grep '{0}'".format(mac_list[4]), shell=True, check=False, stdout=subprocess.PIPE, universal_newlines=True).stdout.split()
                # Make sure the output is a list and has 5 elements, as opposed to being empty.
                if isinstance(ip_list, list) and len(ip_list) == 5:
                    ip = ip_list[0]
                    # Check to see if it is a valid IP address.
                    try:
                        ipaddress.ip_address(ip)
                        logging.debug('%s is a correct IP address.', ip)
                    except:
                        logging.debug('Address/Netmask is invalid: %s', ip)
                        ip = None
                        time.sleep(5)
        else:
            if mac_sp.stderr:
                logging.debug("Mac stderr: %s", mac_sp.stderr)
            time.sleep(5)
    return ip
def vm_createimage(vmname: str, path: str, size_gb: int):
    """Create a VM image file."""
    imgfile_fullpath = os.path.join(os.path.abspath(path), "{0}.qcow2".format(vmname))
    subprocess.run("qemu-img create -f qcow2 -o compat=1.1,lazy_refcounts=on '{0}' {1}G".format(imgfile_fullpath, size_gb), shell=True, check=True)
    return imgfile_fullpath
def ssh_vm(ip: str, command: str, ssh_opts: str, port: int = 22, user: str = "root", password: str = "asdf"):
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
        status = ssh_vm(ip, port, user, password, "echo Connected", "-q")
        attempt += 1
    if status != 0:
        logging.info("ERROR: ssh_wait could not connect.")
    return status
def vm_check_onoff(vmname: str):
    """Check if a VM is started or not. Return True if VM is on."""
    status = subprocess.run('virsh --connect qemu:///system -q list | grep -i "{0}"'.format(vmname), shell=True, check=False).returncode
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
        subprocess.run("virsh --connect qemu:///system shutdown {0}".format(vmname), shell=True, check=True)
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
            subprocess.run("virsh --connect qemu:///system destroy {0}".format(vmname), shell=True, check=True)
def vm_cleanup(vmname: str):
    """Cleanup existing VM."""
    # Destroy and undefine the VM.
    vm_shutdown(vmname)
    subprocess.run("virsh --connect qemu:///system undefine {0}".format(vmname), shell=True, check=False)
    # Delete the image file.
def vm_runscript(ip: str, port: int, user: str, password: str, script: str):
    """Run a script (passed as a variable) on a VM."""
    # Write the script to a file.
    # Make the file executable.
    # SCP the file to the host.
    # Run the file in the VM.
    # Remove the file from host and guest.


if __name__ == '__main__':
    print("Running {0}".format(__file__))

    # Exit if root.
    CFunc.is_root(False)

    # Get non-root user information.
    USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
    CPUCORES = multiprocessing.cpu_count() if multiprocessing.cpu_count() <= 4 else 4

    # Ensure that certain commands exist.
    cmdcheck = ["ssh", "sshpass", "qemu-img", "virsh"]
    for cmd in cmdcheck:
        if not shutil.which(cmd):
            sys.exit("\nError, ensure command {0} is installed.".format(cmd))

    # Get arguments
    parser = argparse.ArgumentParser(description='Create and run a Virtual Machine.')
    parser.add_argument("-a", "--ostype", type=int, help="OS type (20=Manjaro, 10=Ubuntu)", default="1")
    parser.add_argument("-f", "--fullname", help="Full Name", default="User Name")
    parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
    parser.add_argument("-i", "--iso", help="Path to live cd", required=True)
    parser.add_argument("-p", "--vmpath", help="Path of Virtual Machine folders", required=True)
    parser.add_argument("-v", "--rootsshkey", help="Root SSH Key")
    parser.add_argument("-w", "--livesshuser", help="Live SSH Username", default="root")
    parser.add_argument("-x", "--livesshpass", help="Live SSH Password", default="asdf")
    parser.add_argument("-y", "--vmuser", help="VM Username", default="user")
    parser.add_argument("-z", "--vmpass", help="VM Password", default="asdf")
    parser.add_argument("--memory", help="Memory for VM", default="4096")
    parser.add_argument("--vmbootstrap", help="Override bootstrap options.")
    parser.add_argument("--vmprovision", help="Override provision options.")
    parser.add_argument("--driveopts", help="Add drive creation options.")
    args = parser.parse_args()

    # Variables most likely to change.
    vmpath = os.path.abspath(args.vmpath)
    print("Path to VM Files is {0}".format(vmpath))
    isopath = os.path.abspath(args.iso)
    print("Path to LiveCD/ISO is {0}".format(isopath))
    print("OS Type is {0}".format(args.ostype))
    print("VM Memory is {0}".format(args.memory))
    print("Live SSH user is {0}".format(args.livesshuser))
    print("VM User is {0}".format(args.vmuser))
    # Detect root ssh key.
    if args.rootsshkey is not None:
        rootsshkey = args.rootsshkey
    elif os.path.isfile(USERHOME+"/.ssh/id_ed25519.pub") == True:
        with open(USERHOME+"/.ssh/id_ed25519.pub", 'r') as sshfile:
            rootsshkey=sshfile.read().replace('\n', '')
    elif os.path.isfile(USERHOME+"/.ssh/id_rsa.pub") == True:
        with open(USERHOME+"/.ssh/id_rsa.pub", 'r') as sshfile:
            rootsshkey=sshfile.read().replace('\n', '')
    else:
        sys.exit("\nError, ssh key not detect. Please specify one.")
    print("SSH Key is \"{0}\"".format(rootsshkey))


    # Determine VM hypervisor
    hvname = "kvm"

    # Determine VM Name
    if args.ostype == 1:
        vmname = "ArchTest-{0}".format(hvname)
        vboxosid = "ArchLinux_64"
        vmbootstrapscript = "BArch.py"
        vmbootstrap_defopts = ' '
        vmprovisionscript = "MArch.sh"
        vmprovision_defopts = "-e 3 -m 3"
        kvm_variant = "fedora22"
    elif args.ostype == 2:
        vmname = "DebianTest-{0}".format(hvname)
        vboxosid = "Debian_64"
        vmbootstrapscript = "BDebian.py"
        vmbootstrap_defopts = '-t debian -r unstable'
        vmprovisionscript = "MUbuntu.sh"
        vmprovision_defopts = "-e 2"
        kvm_variant = "debian8"
    elif args.ostype == 3:
        vmname = "DebianTest-{0}".format(hvname)
        vboxosid = "Debian_64"
        vmbootstrapscript = "BDebian.py"
        vmbootstrap_defopts = '-t debian -r jessie'
        vmprovisionscript = "MUbuntu.sh"
        vmprovision_defopts = "-e 3"
        kvm_variant = "debian8"
    elif args.ostype == 4:
        vmname = "UbuntuTest-{0}".format(hvname)
        vboxosid = "Ubuntu_64"
        vmbootstrapscript = "BDebian.py"
        vmbootstrap_defopts = '-t ubuntu -r xenial'
        vmprovisionscript = "MUbuntu.sh"
        vmprovision_defopts = "-e 3"
        kvm_variant = "ubuntu16.04"
    elif args.ostype == 5:
        vmname = "FedoraTest-{0}".format(hvname)
        vboxosid = "Fedora_64"
        vmbootstrapscript = "BFedora.py"
        vmbootstrap_defopts = ' '
        vmprovisionscript = "MFedora.sh"
        vmprovision_defopts = " "
        kvm_variant = "fedora22"
    elif args.ostype == 50:
        vmname = "Windows10-{0}".format(hvname)
        vboxosid = "Windows10_64"
        vmbootstrap_defopts = ' '
        vmprovision_defopts = ' '
        kvm_variant = ' '
    # Override bootstrap opts if provided.
    if args.vmbootstrap is None:
        vmbootstrap_opts = vmbootstrap_defopts
    else:
        vmbootstrap_opts = args.vmbootstrap
    print("VM Bootstrap Options:", vmbootstrap_opts)
    # Override provision opts if provided.
    if args.vmprovision is None:
        vmprovision_opts = vmprovision_defopts
    else:
        vmprovision_opts = args.vmprovision
    print("VM Provision Options:", vmprovision_opts)
    # Add drive Options
    if args.driveopts is not None:
        zslimopts += args.driveopts
    print("Drive Options:", zslimopts)

    # Variables less likely to change.
    fullpathtoimg=vmpath+"/"+vmname+".qcow2"
    sship = None
    localsshport=22

    print("Path to Image: {0}".format(fullpathtoimg))
    nameofvnet = "default"
    imgsize="65536"

    if not os.path.isdir(vmpath) or not os.path.isfile(isopath):
        sys.exit("\nError, ensure {0} is a folder, and {1} is a file.".format(vmpath, isopath))

    if args.noprompt == False:
        input("Press Enter to continue.")

    ### Functions (to be deleted) ###
    def vm_bootstrap():
        # Compose BOOTSTRAPCMD
        BOOTSTRAPCMD="""#!/bin/bash
sshpass -p "{sshpassword}" ssh {sship} -p {sshport} -l {sshuser} "cd /CustomScripts/; git pull"
sshpass -p "{sshpassword}" ssh {sship} -p {sshport} -l {sshuser} "/CustomScripts/ZSlimDrive.py -n {zslimopts}"
sshpass -p "{sshpassword}" ssh {sship} -p {sshport} -l {sshuser} "/CustomScripts/{vmbootstrapscript} -n -c {vmname} -u {username} -f \\"{fullname}\\" -g {grubnumber} -q \\"{password}\\" {vmbootstrap_opts} /mnt"
sshpass -p "{sshpassword}" ssh {sship} -p {sshport} -l {sshuser} "mkdir -p /mnt/root/.ssh/; echo '{sshkey}' >> /mnt/root/.ssh/authorized_keys"
sshpass -p "{sshpassword}" ssh {sship} -p {sshport} -l {sshuser} "poweroff"
        """.format(sship=sship, sshpassword=args.livesshpass, sshuser=args.livesshuser, sshport=localsshport, vmname=vmname, username=args.vmuser, password=args.vmpass, fullname=args.fullname, grubnumber=grubnumber, vmbootstrapscript=vmbootstrapscript, vmbootstrap_opts=vmbootstrap_opts, zslimopts=zslimopts, sshkey=rootsshkey)
        subprocess.run(BOOTSTRAPCMD, shell=True)
        return
    def vm_provision():
        # Compose PROVISIONCMD
        PROVISIONCMD="""
        #!/bin/bash
        ssh {sship} -p {sshport} -l root "cd /opt/CustomScripts/; git pull"
        ssh {sship} -p {sshport} -l root "/opt/CustomScripts/{vmprovisionscript} -n {vmprovision_opts} -s {password}"
        ssh {sship} -p {sshport} -l root "reboot"
        """.format(sship=sship, sshport=localsshport, password=args.vmpass, vmprovisionscript=vmprovisionscript, vmprovision_opts=vmprovision_opts)
        subprocess.run(PROVISIONCMD, shell=True)
        return

    ### Scripts ###

    # Compose DELETESCRIPT
    DELETESCRIPT_KVM="""#!/bin/bash
    virsh --connect qemu:///system destroy {0}
    virsh --connect qemu:///system undefine {0}
    """.format(vmname)

    # Notes for virt-install
    # virt-install manual: https://linux.die.net/man/1/virt-install
    # Enable qemu guest agent: https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Virtualization_Deployment_and_Administration_Guide/chap-QEMU_Guest_Agent.html
    CREATESCRIPT_KVM="""#!/bin/bash
    qemu-img create -f qcow2 -o compat=1.1,lazy_refcounts=on {fullpathtoimg} {imgsize}M
    virt-install --connect qemu:///system --name={vmname} --disk path={fullpathtoimg},bus=virtio --graphics spice --vcpu={cpus} --ram={memory} --cdrom={isopath}  --network bridge=virbr0,model=virtio --network network={nameofvnet},model=virtio --filesystem source=/,target=root,mode=mapped --os-type=linux --os-variant={kvm_variant} --noautoconsole --video=virtio --channel unix,target_type=virtio,name=org.qemu.guest_agent.0
    """.format(vmname=vmname, memory=args.memory, cpus=CPUCORES, fullpathtoimg=fullpathtoimg, imgsize=imgsize, isopath=isopath, sshport=localsshport, kvm_variant=kvm_variant, nameofvnet=nameofvnet)

    ### Begin Code ###

    # Create KVM network config.
    kvm_createvnet()

    # Run this if we are destroying (not keeping) the VM.
    if args.keep != True:
        # Delete old vm.
        if os.path.isfile(fullpathtoimg):
            print("\nDeleting old VM.")
            subprocess.run(DELETESCRIPT_KVM, shell=True)
            os.remove(fullpathtoimg)

        # Create new VM.
        print("\nCreating VM.")
        subprocess.run(CREATESCRIPT_KVM, shell=True)

        # Get VM IP
        sship = vm_getip(vmname)
        sshwait(sship, args.livesshuser, args.livesshpass, localsshport)

        # Bootstrap VM
        vm_bootstrap()

        # Shutdown VM
        subprocess.run("virsh --connect qemu:///system shutdown {vmname}".format(vmname=vmname), shell=True)
        shutdownwait()

    # Start VM
    startvm(vmname)

    # Get VM IP
    sship = vm_getip(vmname)
    sshwait(sship, args.livesshuser, args.livesshpass, localsshport)

    # Provision VM
    vm_provision()
