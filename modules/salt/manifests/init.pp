class salt {
    file { '/etc/apt/trusted.gpg.d/salt.gpg':
        ensure => present,
        source => 'puppet:///modules/salt/key/salt.gpg',
    }

    apt::source { 'salt_apt':
        location => 'https://repo.saltproject.io/salt/py3/debian/12/amd64/latest',
        release  => $facts['os']['distro']['codename'],
        repos    => 'main',
        require  => File['/etc/apt/trusted.gpg.d/salt.gpg'],
        notify   => Exec['apt_update_salt'],
    }

    apt::pin { 'proxmox_pin':
        priority => 600,
        origin   => 'repo.saltproject.io'
    }

    # First installs can trip without this
    exec {'apt_update_salt':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
        require     => Apt::Pin['salt_pin'],
    }

    package { ['salt-ssh', 'salt-common']:
        ensure  => present,
        require => Apt::Source['salt_apt']
    }

    $host = query_nodes("networking.domain='${facts['networking']['domain']}'", 'networking.fqdn')
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
