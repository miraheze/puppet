#!/bin/bash

# Default flags
skip_confirm=false
dry_run=false
server_pattern='.*'  # Default: Match all servers
include_kernel=false # Default: Exclude kernel upgrades
include_all=false    # Default: Only security upgrades

# Trap SIGINT (CTRL+C) to exit the entire script
trap "echo -e '\nScript terminated by user'; exit 1" SIGINT

# Display help message
function show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --yes, -y            Skip confirmation prompts"
  echo "  --dry-run, -d        Show what would be done without making changes"
  echo "  --servers, -s        Specify target servers using a pattern"
  echo "  --include-kernel, -k Include kernel upgrades (requires system reboot to take effect)"
  echo "  --include-all, -a    Include all package upgrades rather than only security upgrades (requires maintenance window)"
  echo "  --help, -h           Show this help message"
  exit 0
}

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
    --include-all|-a)
      include_all=true
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Confirm before proceeding if including kernel or all upgrades
if $include_all; then
  echo "WARNING: You have chosen to include all package upgrades. This type of upgrade can never be done without a maintenance window. Proceeding may cause unexpected system behavior or outage."
  read -r -p "Are you sure you want to proceed? (yes/no): " user_confirm
  if [[ "$user_confirm" != "yes" ]]; then
    echo "Operation cancelled."
    exit 1
  fi
elif $include_kernel; then
  echo "WARNING: You have chosen to include kernel upgrades. This will require a system reboot to take effect."
  read -r -p "Are you sure you want to proceed? (yes/no): " user_confirm
  if [[ "$user_confirm" != "yes" ]]; then
    echo "Operation cancelled."
    exit 1
  fi
fi

# Get a list of target servers based on the provided pattern
servers=$(sudo salt-ssh -E "$server_pattern" test.ping --out=json | jq -r 'keys[]')

# Loop through the servers and check/execute the upgrade command
for server in $servers; do
  hostname=$(echo "$server" | awk -F '.' '{print $1}')
  echo "Checking packages for upgrade on $hostname..."

  # Get the list of upgrades
  if $include_all; then
    packages=$(sudo salt-ssh "$server" cmd.run 'apt-get -s dist-upgrade | grep "^Inst" | awk -F " " {"print $2"}' | awk '{printf "%s ", $2}')
  elif $include_kernel; then
    packages=$(sudo salt-ssh "$server" cmd.run 'apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | awk -F " " {"print $2"}' | awk '{printf "%s ", $2}')
  else
    packages=$(sudo salt-ssh "$server" cmd.run 'apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | grep -v "linux-image" | awk -F " " {"print $2"}' | awk '{printf "%s ", $2}')
  fi

  if [ -z "${packages//[[:space:]]}" ]; then
    echo "No packages to upgrade on $hostname"
  else
    # Convert package list into an array
    IFS=' ' read -r -a package_array <<< "$packages"
    packages_count=${#package_array[@]}

    # Format the package list
    case "$packages_count" in
      1) packages_list="${package_array[0]}" ;;
      2) packages_list="${package_array[0]} and ${package_array[1]}" ;;
      *)
        # Join all except last with ", " and append "and last_item"
        packages_list="$(printf "%s, " "${package_array[@]:0:$((packages_count - 1))}")and ${package_array[-1]}"
        ;;
    esac

    # If dry-run mode is enabled, only display the list
    if $dry_run; then
      echo "[DRY RUN] Packages that would be upgraded on $hostname: $packages_list"
      continue
    fi

    # Check if a reboot will be required before upgrading (if there are kernel upgrades)
    reboot_required=$(echo "$packages" | grep -q "linux-image" && echo "yes" || echo "no")

    echo "Packages that will be upgraded on $hostname: $packages_list"

    # Warn about required reboot if necessary
    if [[ "$reboot_required" == "yes" ]]; then
      echo "WARNING: Upgrading kernel package on $hostname will require a system reboot. However, this script will not automatically perform a reboot. Please plan accordingly."
    fi

    # Prompt for confirmation unless --yes or -y is provided
    if ! $skip_confirm; then
      read -r -p "Are you sure you want to proceed with these upgrades? (yes/no): " upgrade_confirm
      if [[ "$upgrade_confirm" != "yes" ]]; then
        echo "Skipping upgrade on $hostname..."
        continue
      fi
    fi

    # Execute the upgrade command
    sudo salt-ssh "$server" cmd.run "apt-get -o Dpkg::Options::='--force-confold' install --only-upgrade $packages"

    # Log the packages that were upgraded
    logsalmsg "Upgraded packages on $hostname: $packages_list"
  fi
done
