# class: irc
class irc {
    ensure_packages([
        'python',
        'python3',
        'python3-twisted',
        'python3-irc',
        'python3-requests',
        'python3-requests-oauthlib',
    ])
}
