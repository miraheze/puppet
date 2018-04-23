class role::salt::minions(
    $salt_master_key = false,
) {
    # stretch's salt-minion uses SHA256 instead of MD5 by default.
    # while it's possible to set 'hash_type: md5', this is preferrable
    $master_finger = 'f8:9e:01:c4:65:5a:10:92:79:ae:80:ce:37:83:d9:b4:0a:2e:9b:f3:c7:d2:65:83:69:f2:a7:b0:47:80:73:ec'

    class { '::salt::minion':
        id            => $::fqdn,
        master        => 'misc3.miraheze.org',
        master_finger => $master_finger,
        master_key    => $salt_master_key,
    }

    motd::role { 'role::salt::minions':
        description => 'is a host for a minion',
    }
}
