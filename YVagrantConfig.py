#!/usr/bin/env python3
"""Create a Vagrant global configuration"""

# Python Includes
import os
import multiprocessing
import shutil
import subprocess
import sys

print("Running {0}".format(__file__))

# Exit if root.
if os.geteuid() is 0:
    sys.exit("\nError: Please run this script as a normal user (not root).\n")

# Exit if vagrant not installed.
if shutil.which("vagrant") is None:
    sys.exit("\nError: Vagrant not detected. Please install vagrant.\n")

# Get homefolder.
USERHOME = os.path.expanduser("~")
print("Home Folder is:", USERHOME)

# Install vagrant plugins
# List of vagrant plugins available: https://github.com/mitchellh/vagrant/wiki/Available-Vagrant-Plugins
subprocess.call("vagrant plugin install vagrant-vbguest vagrant-timezone", shell=True)

# Get CPUs of host
CPUCOUNT = multiprocessing.cpu_count() if multiprocessing.cpu_count() <= 4 else 4
# Get memory of host, parse free command, return only physical free memory (the first column and first row).
MEMORY = int(os.popen('free -t -m').readlines()[-3].split()[1:][0])
# Install vagrant user configuration
VAGRANTCONFIG = """
Vagrant.configure("2") do |config|
  if Vagrant.has_plugin?("vagrant-timezone")
    config.timezone.value = :host
  end
  config.vm.provider "virtualbox" do |v|
    v.memory = {1}
    v.cpus = {0}
  end
end
""".format(CPUCOUNT, MEMORY/8)
VAGRANTFOLDER = USERHOME+"/.vagrant.d/"
if os.path.isdir(VAGRANTFOLDER) is True:
    print("Writing {0}".format(VAGRANTFOLDER+"Vagrantfile"))
    with open(VAGRANTFOLDER+"Vagrantfile", "w") as f:
        f.write(VAGRANTCONFIG)
