class role::salt::minions(
    $salt_master_key = false,
) {
    # stretch's salt-minion uses SHA256 instead of MD5 by default.
    # while it's possible to set 'hash_type: md5', this is preferrable
    $master_finger = '28:62:d0:61:2c:76:3c:15:51:6a:43:1b:bb:e1:99:a4:e8:82:b5:47:fc:3c:44:b5:16:84:86:f4:5d:22:69:9d'

    class { '::salt::minion':
        id            => $::fqdn,
        master        => 'misc4.miraheze.org',
        master_finger => $master_finger,
        master_key    => $salt_master_key,
    }

    motd::role { 'role::salt::minions':
        description => 'a minion that connects to the salt master.',
    }
}
