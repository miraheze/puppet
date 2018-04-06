# class: base::packages
class base::packages {
    $packages = [
        'acct',
        'coreutils',
        'debian-goodies',
        'dirmngr',
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

    # Get rid of this
    package { [ 'apt-listchanges' ]:
        ensure => absent,
    }
}
