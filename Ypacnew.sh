#!/bin/bash
# pacnew-diff - merge *.pacnew files with original configurations with meld

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Add general functions if they don't exist.
type -t grepadd >> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

# Find all pacnew files in etc.
pacnew=$(find /etc -type f -name "*.pacnew")

# Merge config files using meld.
for config in $pacnew
do
  echo "Merging $config."
  sudo meld ${config%\.*} $config &
  wait
done

# Delete files after loop above has been done for merging.
read -p "Press any key to delete merged pacnew files."
for config in $pacnew
do
  echo "Deleting $config."
  sudo rm "$config"
done
