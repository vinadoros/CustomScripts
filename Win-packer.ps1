
# Install packer
choco upgrade -y packer --version 1.1.1 --force
# Install python and dependancies
choco upgrade -y python
pip install passlib
# Enable Hyper-V
#Enable-WindowsOptionalFeature -Online -FeatureName:Microsoft-Hyper-V -All -NoRestart
