class icinga2::custom::conf {
    include ::icinga2

    include ::icinga2::feature::api

    include ::icinga2::feature::checker

    include ::icinga2::feature::command

    include ::icinga2::feature::notification

    include ::icinga2::feature::perfdata

    $db_host = hiera('icinga_ido_db_host', 'db4.miraheze.org')
    $db_name = hiera('icinga_ido_db_name', 'icinga')
    $db_user = hiera('icinga_ido_user_name', 'icinga2')
    $db_password = hiera('passwords::icinga_ido')

    class{ '::icinga2::feature::idomysql':
        host          => $db_host,
        user          => $db_user,
        password      => $db_password,
        database      => $db_name,
        import_schema => true,
    }

    file { '/etc/icinga2/conf.d/commands.conf':
        source  => 'puppet:///modules/icinga2/commands.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/groups.conf':
        source  => 'puppet:///modules/icinga2/groups.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/hosts.conf':
        source  => 'puppet:///modules/icinga2/hosts.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/notifications.conf':
        source  => 'puppet:///modules/icinga2/notifications.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/templates.conf':
        source  => 'puppet:///modules/icinga2/templates.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/timeperiods.conf':
        source  => 'puppet:///modules/icinga2/timeperiods.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/users.conf':
        source  => 'puppet:///modules/icinga2/users.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/features-enabled/checker.conf':
        source  => 'puppet:///modules/icinga2/checker.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/scripts/irc-host-notification.sh':
        source  => 'puppet:///modules/icinga2/scripts/irc-host-notification.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/scripts/irc-service-notification.sh':
        source  => 'puppet:///modules/icinga2/scripts/irc-service-notification.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/scripts/create_ssl_phabricator_ticket.sh':
        source  => 'puppet:///modules/icinga2/scripts/create_ssl_phabricator_ticket.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    $ssl = loadyaml('/etc/puppet/ssl/certs.yaml')
    $redirects = loadyaml('/etc/puppet/ssl/redirects.yaml')
    $sslcerts = merge( $ssl, $redirects )

    file { '/etc/icinga2/conf.d/ssl.conf':
        ensure  => 'present',
        content => template('icinga2/ssl.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    $icingabot_password = hiera('passwords::phabricator::icinga')

    file { '/etc/icinga2/ssl-phabricator.py':
        ensure  => 'present',
        content => template('icinga2/ssl-phabricator.py'),
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
    }

    package { 'nagios-nrpe-plugin':
        ensure => present,
    }

    include ::icingaweb2

    $mirahezebots_password = hiera('passwords::irc::mirahezebots')

    file { '/etc/icinga2/irc.py':
        ensure  => present,
        owner   => 'irc',
        content => template('icinga2/bot/irc.py'),
        mode    => '0551',
        notify  => Service['icingabot'],
    }

    exec { 'Icingabot reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/icingabot.service':
        ensure => present,
        source => 'puppet:///modules/icinga2/bot/icingabot.systemd',
        notify => Exec['Icingabot reload systemd'],
    }

    service { 'icingabot':
        ensure => running,
    }

    # Purge unmanaged icinga2::object::host and icinga2::object::service resources
    # This will only happen for non exported resources, that is resources that
    # are declared by the icinga host itself
    # resources { 'icinga2::object::host': purge => true, }
    # resources { 'icinga2::object::service': purge => true, }

    Icinga2::Object::Host <<||>> ~> Service['icinga2']
    Icinga2::Object::Service <<||>> ~> Service['icinga2']
}
