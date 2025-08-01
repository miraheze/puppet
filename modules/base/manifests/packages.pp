# === Class base::packages
class base::packages {
    stdlib::ensure_packages([
        'acct',
        'apt-transport-https',
        'coreutils',
        'debian-goodies',
        'dirmngr',
        'fatrace',
        'git',
        'gzip',
        'htop',
        'iftop',
        'iotop',
        'jq',
        'logrotate',
        'lsof',
        'lvm2',
        'molly-guard',
        'mtr',
        'nano',
        'net-tools',
        'netcat-openbsd',
        'parted',
        'pigz',
        'python-is-python3',
        'python3-distro',
        'qemu-guest-agent',
        'ruby',
        'screen',
        'strace',
        'tcpdump',
        'tcptrack',
        'telnet',
        'vim',
        'vnstat',
        'wipe',
    ])

    # Get rid of these
    stdlib::ensure_packages(
        'needrestart',
        { ensure => purged }
    )

    stdlib::ensure_packages(
        [ 'apt-listchanges', 'systemd-timesyncd' ],
        { ensure => absent }
    )
}
