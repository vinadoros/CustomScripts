#!/usr/bin/env python3
"""ssh config"""

# Python includes.
import os
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Exit if not root.
CFunc.is_root(True)

# Check if includes exist in ssh config. If not, add them and create foldders.
ssh_config_global_file = os.path.join(os.sep, "etc", "ssh", "ssh_config")
if CFunc.find_pattern_infile(ssh_config_global_file, "^Include /etc/ssh/ssh_config.d/") is False:
    with open(ssh_config_global_file, 'a') as f:
        f.write(r"""
Include /etc/ssh/ssh_config.d/*.conf
""")
# Check if includes exist in sshd config. If not, add them and create foldders.
sshd_config_global_file = os.path.join(os.sep, "etc", "ssh", "sshd_config")
if CFunc.find_pattern_infile(sshd_config_global_file, "^Include /etc/ssh/sshd_config.d/") is False:
    with open(sshd_config_global_file, 'a') as f:
        f.write(r"""
Include /etc/ssh/sshd_config.d/*.conf
""")

### ssh client config ###
ssh_config_folder = os.path.join(os.sep, "etc", "ssh", "ssh_config.d")
if not os.path.isdir(ssh_config_folder):
    os.makedirs(ssh_config_folder, exist_ok=True, mode=0o755)
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
if not os.path.isdir(sshd_config_folder):
    os.makedirs(sshd_config_folder, exist_ok=True, mode=0o700)
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
