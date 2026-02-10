#!/bin/bash
function usage() {
    cat <<EOF
php8madm -- Shell helper for the PHP7 admin site.

Usage:

   php8adm [ENDPOINT] [--KEY=VALUE ..]

Example:

   php8adm metrics

EOF
    exit 2
}
case $1 in --help|-h|help)
  usage
  ;;
esac
# Determine the port we're communicating on.
ADMIN_PORT=9181

# Remove the leading slash from the cli argument.
url="http://localhost:${ADMIN_PORT}/${1#/}"
shift
params=()
for arg in "${@##--}"; do params+=('--data-urlencode' "$arg"); done
/usr/bin/curl -s -G "${params[@]}" "$url"
