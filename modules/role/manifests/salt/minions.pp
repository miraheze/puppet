class role::salt::minions(
    $salt_master_key = false,
) {
    # stretch's salt-minion uses SHA256 instead of MD5 by default.
    # while it's possible to set 'hash_type: md5', this is preferrable
    $master_finger = 'f6:36:06:73:ca:54:55:c4:68:17:66:13:47:4b:cf:3e:32:71:7a:70:2d:69:b4:e8:3b:f0:d0:ae:d0:4b:4c:f5'

    class { '::salt::minion':
        id            => $::fqdn,
        master        => 'misc3.miraheze.org',
        master_finger => $master_finger,
        master_key    => $salt_master_key,
    }
}