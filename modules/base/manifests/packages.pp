# class: base::packages
class base::packages {
    $packages = [
        'acct',
        'apt-transport-https',
        'coreutils',
        'debian-goodies',
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
        'net-tools',
        'parted',
        'pigz',
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
    ]

    package { $packages:
        ensure => present,
    }

    package { 'needrestart':
        ensure  => 'purged',
    }

    if os_version('debian >= stretch') {
        require_package('dirmngr')
    }

    # Get rid of this
    package { [ 'apt-listchanges' ]:
        ensure => absent,
    }
}
