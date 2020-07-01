class salt {
    package { ['salt-ssh', 'salt-common']:
        ensure  => present,
    }

    $host = query_nodes("domain='$domain'", 'fqdn')
    file { '/etc/salt/roster':
        content => template('salt/roster.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['salt-ssh'],
    }
}
