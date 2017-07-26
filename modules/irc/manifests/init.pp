# class: irc
class irc {
    $packages = [
        'python',
        'python-twisted',
        'python-irc',
    ]

    package { $packages:
        ensure => present,
    }
}
