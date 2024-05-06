#!/bin/bash
#script to upgrade packages with pending security upgrades, and automatically log these upgrades to Tech:SAL
packages=$(apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | grep -v "linux-image" | awk -F " " {"print $2"} | awk '{printf "%s ", $2}')
if [ -z "${packages//[[:space:]]}" ]; then
  echo "No packages to upgrade"
else
  packages_list=$(echo $packages | sed 's/ /, /g')
  packages_count=$(echo $packages | wc -w)
  if [ $packages_count -gt 1 ]; then
    last_package=$(echo $packages_list | awk '{print $NF}')
    packages_list=$(echo $packages_list | sed 's/ '$last_package'$/ and '$last_package'/')
  fi
  read -p "Upgrading packages $packages_list; press enter to confirm..."
  sudo apt-get -o Dpkg::Options::='--force-confold' install --only-upgrade $packages
  logsalmsg "Upgraded packages $packages_list"
fi
