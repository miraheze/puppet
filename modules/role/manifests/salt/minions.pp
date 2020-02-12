class role::salt::minions(
    $salt_master = 'misc4.miraheze.org',
    $salt_master_key = false
) {
    # stretch's/buster's salt-minion uses SHA256 instead of MD5 by default.
    # while it's possible to set 'hash_type: md5', this is preferrable
    if hiera('new_servers', false) {
        $master_finger = 'a8:b0:35:99:7c:2e:d5:5e:16:cc:ee:cc:2e:2c:b5:dd:72:f0:de:49:82:e5:bb:07:53:15:34:0b:50:62:5a:aa'
    } else {
        $master_finger = '28:62:d0:61:2c:76:3c:15:51:6a:43:1b:bb:e1:99:a4:e8:82:b5:47:fc:3c:44:b5:16:84:86:f4:5d:22:69:9d'
    }

    class { '::salt::minion':
        id            => $::fqdn,
        master        => $salt_master,
        master_finger => $master_finger,
        master_key    => $salt_master_key,
    }

    motd::role { 'role::salt::minions':
        description => 'a minion that connects to the salt master.',
    }
}
