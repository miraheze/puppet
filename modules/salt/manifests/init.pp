class salt {
    package { ['salt-ssh', 'salt-common']:
        ensure  => present,
    }

    $host = query_nodes("domain='${domain}'", 'fqdn')
    file { '/etc/salt/roster':
        content => template('salt/roster.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['salt-ssh'],
    }

    file { '/home/salt-user/.ssh':
        ensure  => directory,
        mode    => '0700',
        owner   => 'salt-user',
        group   => 'salt-user',
        require => User['salt-user'],
    }

    file { '/home/salt-user/.ssh/id_ed25519':
        source    => 'puppet:///private/base/user/salt-user-ssh-key',
        owner     => 'salt-user',
        group     => 'salt-user',
        mode      => '0400',
        show_diff => false,
        require   => File['/home/salt-user/.ssh'],
    }

    file { '/home/salt-user/.ssh/known_hosts':
        content => template('salt/salt-user-known-hosts.erb'),
        owner   => 'salt-user',
        group   => 'salt-user',
        mode    => '0644',
        require => File['/home/salt-user/.ssh'],
    }

    file { '/root/.ssh':
        ensure => directory,
        mode   => '0700',
        owner  => 'root',
        group  => 'root',
    }

    file { '/root/.ssh/known_hosts':
        content => template('salt/salt-user-known-hosts.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => File['/root/.ssh'],
    }
}
