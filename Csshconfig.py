#!/usr/bin/env python3
"""ssh config"""

# Python includes.
import os
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Exit if not root.
CFunc.is_root(True)

### ssh client config ###
ssh_config_folder = os.path.join(os.sep, "etc", "ssh", "ssh_config.d")
ssh_config_file = os.path.join(ssh_config_folder, "01-custom.conf")
ssh_config_text = r"""
ForwardX11 yes
Host *
StrictHostKeyChecking no
UpdateHostKeys no
UserKnownHostsFile /dev/null
Compression yes
"""
if os.path.isdir(ssh_config_folder):
    with open(ssh_config_file, 'w') as f:
        f.write(ssh_config_text)
else:
    print("ERROR: folder {0} doesn't exist, ssh config not saved.".format(ssh_config_folder))

### sshd server config ###
sshd_config_folder = os.path.join(os.sep, "etc", "ssh", "sshd_config.d")
sshd_config_file = os.path.join(sshd_config_folder, "01-custom.conf")
sshd_config_text = r"""
X11Forwarding yes
AllowAgentForwarding yes
AllowTcpForwarding yes
"""
if os.path.isdir(sshd_config_folder):
    with open(sshd_config_file, 'w') as f:
        f.write(sshd_config_text)
else:
    print("ERROR: folder {0} doesn't exist, sshd config not saved.".format(sshd_config_folder))
