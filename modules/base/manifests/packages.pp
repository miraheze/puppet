# class: base::packages
class base::packages {

    $packages = [
        'acct',
        'atop',
        'coreutils',
        'debian-goodies',
        'git',
        'htop',
        'nano',
        'screen',
        'strace',
        'tcpdump',
        'vim',
        'wipe',
    ]

    package { $packages:
        ensure => latest,
    }

}
