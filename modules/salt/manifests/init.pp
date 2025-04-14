class salt {
    if $facts['os']['distro']['codename'] == 'bookworm' {
        $http_proxy = lookup('http_proxy', {'default_value' => undef})
        if $http_proxy {
            file { '/etc/apt/apt.conf.d/01salt':
                ensure  => present,
                content => template('salt/apt/01salt.erb'),
                before  => Apt::Source['salt_apt'],
            }
        }

        apt::source { 'salt_apt':
            location => 'https://packages.broadcom.com/artifactory/saltproject-deb',
            release  => 'stable',
            repos    => 'main',
            key      => {
              name   => 'salt.pgp',
              source => 'puppet:///modules/salt/key/salt.pgp'
            },
            notify   => Exec['apt_update_salt'],
        }

        apt::pin { 'salt_pin':
            priority => 1001,
            packages => 'salt-*',
            # TODO: Migrate to LTS once a version greater than 3007 becomes lts.
            version  => '3007.*',
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
    } else {
        package { ['salt-ssh', 'salt-common']:
            ensure => present,
        }
    }

    $host = query_nodes('', 'networking.fqdn')
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

    file { '/usr/local/bin/upgrade-packages':
        ensure => present,
        source => 'puppet:///modules/salt/bin/upgrade-packages.sh',
        mode   => '0555',
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
