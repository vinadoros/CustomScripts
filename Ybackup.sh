#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
FLWSOURCE=$(readlink -f "$SOURCE")
DIR="$(dirname "$FLWSOURCE")"

echo Script Folder location: $DIR

d="$(date +%Y-%m-%d_%R)"
srcdir="$DIR"
bakdir="./Backup"
dstfile="$bakdir/$d.tar.gz"

cd $DIR

tar --exclude="$bakdir" -cvpzf "$dstfile" -C "$srcdir" .

echo "Backup to $dstfile complete."

