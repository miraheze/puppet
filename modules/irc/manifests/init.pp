# class: irc
class irc {
    stdlib::ensure_packages([
        'python3',
        'python3-irc',
        'python3-requests',
        'python3-requests-oauthlib',
        'python3-twisted',
    ])
}
