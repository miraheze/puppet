# class: irc
class irc {
    $packages = [
        'python',
        'python3',
        'python3-twisted',
        'python3-irc',
        'python3-requests',
        'python3-requests-oauthlib',
    ]

    package { $packages:
        ensure => present,
    }
}
