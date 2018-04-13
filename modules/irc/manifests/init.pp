# class: irc
class irc {
    $packages = [
        'python',
        'python-twisted',
        'python-irc',
        'python-requests',
    ]

    package { $packages:
        ensure => present,
    }
}
