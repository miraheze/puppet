#!/bin/bash

# Usage: opensearch-plugin-sync <check|remove> <plugin dir> <version> <plugin>...
mode="$1"
plugin_dir="$2"
version="$3"
shift 3

export JAVA_HOME=/usr/share/opensearch/jdk
export OPENSEARCH_PATH_CONF=/etc/opensearch

stale=()
for descriptor in "${plugin_dir}"/*/plugin-descriptor.properties; do
    [ -f "${descriptor}" ] || continue

    name=$(sed -n 's/^name=//p' "${descriptor}" | tr -d '\r')
    installed=$(sed -n 's/^opensearch\.version=//p' "${descriptor}" | tr -d '\r')

    for managed in "$@"; do
        if [ "${name}" = "${managed}" ] && [ "${installed}" != "${version}" ]; then
            stale+=("${name}")
        fi
    done
done

case "${mode}" in
    check)
        [ "${#stale[@]}" -gt 0 ]
        ;;
    remove)
        for name in "${stale[@]}"; do
            /usr/share/opensearch/bin/opensearch-plugin remove "${name}" || exit 1
        done
        ;;
    *)
        echo "Unknown mode: ${mode}" >&2
        exit 2
        ;;
esac
