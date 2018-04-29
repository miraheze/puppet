# class: base::packages
class base::packages {
    $packages = [
        'acct',
        'apt-transport-https',
        'coreutils',
        'debian-goodies',
        'git',
        'htop',
        'logrotate',
        'mtr',
        'nano',
        'pigz',
        'screen',
        'strace',
        'tcpdump',
        'vim',
        'wipe',
    ]

    package { $packages:
        ensure => present,
    }

    if os_version('debian >= stretch') {
        package { 'dirmngr':
            ensure => present,
        }
    }

    # Get rid of this
    package { [ 'apt-listchanges' ]:
        ensure => absent,
    }
}
