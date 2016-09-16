#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys

print("Running {0}".format(__file__))

# Exit if root.
if os.geteuid() == 0:
    sys.exit("\nError: Please run this script as a normal user (not root).\n")

# Exit if vagrant not installed.
if shutil.which("vagrant") == None:
    sys.exit("\nError: Vagrant not detected. Please install vagrant.\n")

# Get homefolder.
USERHOME=os.path.expanduser("~")
print("Home Folder is:",USERHOME)

# Install vagrant plugins
# List of vagrant plugins available: https://github.com/mitchellh/vagrant/wiki/Available-Vagrant-Plugins
subprocess.call("vagrant plugin install vagrant-vbguest vagrant-timezone", shell=True)

# Get CPUs and memory of host
CPUCOUNT=os.cpu_count()
if CPUCOUNT >= 4:
    CPUCOUNT = 4
# Install vagrant user configuration
VAGRANTCONFIG="""
Vagrant.configure("2") do |config|
  if Vagrant.has_plugin?("vagrant-timezone")
    config.timezone.value = :host
  end
  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
    v.cpus = {0}
  end
end
""".format(CPUCOUNT)
VAGRANTFOLDER=USERHOME+"/.vagrant.d/"
if os.path.isdir(VAGRANTFOLDER) == True:
    print("Writing {0}".format(VAGRANTFOLDER+"Vagrantfile"))
    f = open(VAGRANTFOLDER+"Vagrantfile","w")
    f.write(VAGRANTCONFIG)
    f.close()
