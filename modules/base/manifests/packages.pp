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
        'jq',
        'iftop',
        'iotop',
        'logrotate',
        'lsof',
        'lvm2',
        'molly-guard',
        'mtr',
        'nano',
        'netcat-openbsd',
        'net-tools',
        'parted',
        'pigz',
        'python-is-python3',
        'python3-distro',
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

    package { 'needrestart':
        ensure => 'purged',
    }

    # Get rid of this
    package { 'apt-listchanges':
        ensure => absent,
    }
}
