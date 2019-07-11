#!/bin/bash

# To run this script do the following fileLockScript.sh <lock_name> "<script>"

LOCK_FILE=$1
if [ -f "$LOCK_FILE" ]; then
    # Lock file already exists, exit the script
    echo "An instance of this script is already running"
    exit 1
fi
# Create the lock file
echo "Locked" > "$LOCK_FILE"

# Do the normal stuff
$2

# clean-up before exit
rm "$LOCK_FILE"
