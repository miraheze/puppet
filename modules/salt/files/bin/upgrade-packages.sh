#!/bin/bash

# Default flags
skip_confirm=false
dry_run=false
server_pattern='.*'  # Default: Match all servers
include_kernel=false # Default: Exclude kernel updates

# Trap SIGINT (CTRL+C) to exit the entire script
trap "echo -e '\nScript terminated by user'; exit 1" SIGINT

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)
      skip_confirm=true
      ;;
    --dry-run|-d)
      dry_run=true
      ;;
    --servers|-s)
      shift
      server_pattern="$1"
      ;;
    --include-kernel|-k)
      include_kernel=true
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Get a list of target servers based on the provided pattern
servers=$(sudo salt-ssh -E "$server_pattern" test.ping --out=json | jq -r 'keys[]')

# Loop through the servers and check/execute the upgrade command
for server in $servers; do
  hostname=$(echo $server | awk -F '.' '{print $1}')
  echo "Checking packages for upgrade on $hostname..."

  # Get the list of security upgrades (excluding kernal upgrades unless the flag is specified)
  if $include_kernel; then
    packages=$(sudo salt-ssh "$server" cmd.run 'apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | awk -F " " {"print $2"}' | awk '{printf "%s ", $2}')
  else
    packages=$(sudo salt-ssh "$server" cmd.run 'apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | grep -v "linux-image" | awk -F " " {"print $2"}' | awk '{printf "%s ", $2}')
  fi

  if [ -z "${packages//[[:space:]]}" ]; then
    echo "No packages to upgrade on $hostname"
  else
    # Create formatted package list
    packages_list=$(echo $packages | sed 's/ /, /g')
    packages_count=$(echo $packages | wc -w)

    if [ $packages_count -gt 1 ]; then
      last_package=$(echo $packages_list | awk '{print $NF}')
      packages_list=$(echo $packages_list | sed "s/ $last_package$/ and $last_package/")
    fi

    # If dry-run mode is enabled, only display the list
    if $dry_run; then
      echo "[DRY RUN] Packages that would be upgraded on $hostname: $packages_list"
      continue
    fi

    # Prompt for confirmation unless --yes or -y is provided
    if ! $skip_confirm; then
      read -p "Upgrading packages $packages_list on $hostname; press enter to confirm or type 'skip' to skip this server... " user_input
      if [[ "$user_input" == "skip" ]]; then
        echo "Skipping upgrade on $hostname..."
        continue
      fi
    fi

    # Execute the upgrade command
    sudo salt-ssh "$server" cmd.run "apt-get -o Dpkg::Options::='--force-confold' install --only-upgrade $packages"

    # Log the packages that were upgraded
    logsalmsg "Upgraded packages $packages_list on $hostname"
  fi
done
