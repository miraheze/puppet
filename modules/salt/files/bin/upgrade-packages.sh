#!/bin/bash
# Get a list of target servers
servers=$(sudo salt-ssh -E '.*' test.ping --out=json | jq -r 'keys[]')
# Loop through the servers and execute the upgrade command
for server in $servers; do
  hostname=$(echo $server | awk -F '.' '{print $1}')
  echo "Upgrading packages on $hostname"
  packages=$(sudo salt-ssh "$server" cmd.run 'apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | grep -v "linux-image" | awk -F " " {"print $2"}' | awk '{printf "%s ", $2}')
  if [ -z "${packages//[[:space:]]}" ]; then
    echo "No packages to upgrade on $hostname"
  else
    # Create formatted list
    packages_list=$(echo $packages | sed 's/ /, /g')
    packages_count=$(echo $packages | wc -w)
    if [ $packages_count -gt 1 ]; then
      last_package=$(echo $packages_list | awk '{print $NF}')
      packages_list=$(echo $packages_list | sed 's/ '$last_package'$/ and '$last_package'/')
    fi
    read -p "Upgrading packages $packages_list on $hostname; press enter to confirm..."
    sudo salt-ssh "$server" cmd.run "apt-get -o Dpkg::Options::='--force-confold' install --only-upgrade $packages"
    # Log the upgrade message
    logsalmsg "Upgraded packages $packages_list on $hostname"
  fi
done
