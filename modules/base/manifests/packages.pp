# class: base::packages
class base::packages {
    $packages = [
        'acct',
        'apt-transport-https',
        'coreutils',
        'debian-goodies',
        'git',
        'gzip',
        'htop',
        'iftop',
        'logrotate',
        'molly-guard',
        'mtr',
        'nano',
        'net-tools',
        'pigz',
        'ruby',
        'ruby-safe-yaml',
        'screen',
        'strace',
        'tcpdump',
        'telnet',
        'vim',
        'vnstat',
        'wipe',
    ]

    package { $packages:
        ensure => present,
    }

    if os_version('debian >= stretch') {
        require_package('dirmngr')
    }

    # Get rid of this
    package { [ 'apt-listchanges' ]:
        ensure => absent,
    }
}
