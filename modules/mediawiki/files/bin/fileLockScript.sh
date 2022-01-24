#! /bin/bash

# To run this script do the following fileLockScript.sh <lock_name> "<script>"

LOCK_FILE=$1

if ( set -o noclobber; echo "$$" > "$LOCK_FILE") 2> /dev/null; then

        trap 'rm -f "$LOCK_FILE"; exit $?' INT TERM EXIT

        # do stuff here
        $2

        # clean up after yourself, and release your trap
        rm -f "$LOCK_FILE"
        trap - INT TERM EXIT
else
        echo "Lock Exists: $lockfile owned by $(cat $LOCK_FILE)"
fi
