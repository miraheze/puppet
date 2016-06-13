# class: base::packages
class base::packages {

    $packages = [
        'acct',
        'atop',
        'coreutils',
        'debian-goodies',
        'git',
        'htop',
	'logrotate',
        'nano',
        'screen',
        'strace',
        'tcpdump',
        'vim',
        'wipe',
    ]

    package { $packages:
        ensure => present,
    }

}
