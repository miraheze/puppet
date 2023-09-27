#!/bin/bash

# To run this script do the following fileLockScript.sh <lock_name> "<script>"

exec 100>$1 || exit 1
flock -n 100 || exit 1

trap "rm -f $1" EXIT

$2
