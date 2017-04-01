#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

if [ "$(id -u)" == "0" ]; then
	echo "Running with root. Please run the script as a normal user."
	exit 1;
fi

# Install packages
if type yaourt; then
  yaourt -ASa --needed --noconfirm python-jedi shellcheck pylama pylama_pylint
elif type zypper; then
	sudo zypper ar -f http://download.opensuse.org/repositories/devel:/languages:/python3/openSUSE_Tumbleweed/ languages-python3
	sudo zypper ar -f http://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Tumbleweed/ languages-python
	sudo zypper --non-interactive --gpg-auto-import-keys refresh
  sudo zypper in -yl python3-jedi ShellCheck python3-pylama python-pylama_pylint
fi

# Update existing plugins
apm update
# Install atom plugins
# Python plugins
apm install autocomplete-python
# Git plugins
apm install git-plus git-time-machine
# Sublime column editing
apm install sublime-style-column-selection

### Plugins which require external packages ###
# Linting
apm install linter
# Python
apm install autocomplete-python linter-python
# Shell
apm install linter-shellcheck
# Php
apm install linter-php
# C
apm install linter-gcc

echo "Be sure to install php, gcc, python3-jedi, pylama, pylama-pylint, shellcheck"
