#! /bin/bash

# Make sure that the mount is connected and if not remounts.

if ! mountpoint -q /mnt/mediawiki-static
then
   umount /mnt/mediawiki-static && mount /mnt/mediawiki-static
fi
