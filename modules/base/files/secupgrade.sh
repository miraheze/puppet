#!/bin/bash
#script to upgrade packages with pending security upgrades, and automatically log these upgrades to Tech:SAL
#this is much easier than trying to use getopt or getopts
if [ "$1" = "--include-kernel" ]; then
  packages=$(apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | awk -F " " '{print $2}' | awk '{printf "%s ", $2}')
else
  packages=$(apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | grep -v "linux-image" | awk -F " " '{print $2}' | awk '{printf "%s ", $2}')
fi
if [ -z "${packages//[[:space:]]}" ]; then
  echo "No packages to upgrade"
else
  # I feel like this is cleaner, therefore:
  # shellcheck disable=SC2001
  packages_list=$(echo "$packages" | sed 's/ /, /g')
  packages_count=$(echo "$packages" | wc -w)
  if [ "$packages_count" -gt 1 ]; then
    last_package=$(echo "$packages_list" | awk '{print $NF}')
    # shellcheck disable=SC2001
    packages_list=$(echo "$packages_list" | sed 's/ '"$last_package"'$/ and '"$last_package"'/')
  fi
  read -rp "Upgrading packages $packages_list; press enter to confirm..."
  # Word splitting here is intentional (since we want each argument to be different),
  # but globbing is not. Therefore, we disable globbing:
  set -f
  # And tell shellcheck to ignore the word splitting:
  # shellcheck disable=SC2086
  sudo apt-get -o Dpkg::Options::='--force-confold' install --only-upgrade -- $packages
  # And reenable globbing, just in case (even though we have never used it in this script as of writing)
  set +f
  logsalmsg "Upgraded packages $packages_list"
fi
