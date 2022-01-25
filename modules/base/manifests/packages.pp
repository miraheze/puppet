# class: base::packages
class base::packages {
    ensure_packages([
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
        'python3-distro',
        'python-is-python3',
        'ruby',
        'ruby-safe-yaml',
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
        ensure  => 'purged',
    }

    # Get rid of this
    package { 'apt-listchanges':
        ensure => absent,
    }
}
