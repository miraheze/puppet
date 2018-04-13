# class: irc
class irc {
    $packages = [
        'python',
        'python-twisted',
        'python-irc',
        'python-requests',
        'python-requests-oauthlib',
    ]

    package { $packages:
        ensure => present,
    }
}
