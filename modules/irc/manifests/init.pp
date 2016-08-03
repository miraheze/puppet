# class: irc
class irc {
    $mirahezebots_password = hiera('passwords::irc::mirahezebots')

    $packages = [
        'python',
        'python-twisted',
        'python-irc',
    ]

    package { $packages:
        ensure => present,
    }
    
    motd::role { '::irc':
        description => 'IRC bots server',
    }
}
