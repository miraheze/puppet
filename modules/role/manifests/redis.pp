class role::redis {
    include private::redis

    class { '::redis':
        password => $password,
    }

    motd::role { 'role::redis':
        description => 'Redis caching server',
    }
}
