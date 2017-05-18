#!/bin/sh

# Assume yes for pkg.
export ASSUME_ALWAYS_YES=yes

# Update freebsd.
freebsd-update fetch install
# Update packages.
pkg update -f

# Install command line utilities.
pkg install -y nano fish git
