# class: irc
class irc {
    $packages = [
        'python',
        'python-twisted',
    ]

    package { $packages:
        ensure => present,
    }
}
