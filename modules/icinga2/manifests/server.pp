class icinga2::server {
    include ::icinga2::setup

    include ::icinga2::feature::api

    include ::icinga2::feature::command

    include ::icinga2::feature::notification

    include ::icinga2::feature::perfdata

    $db_host = hiera('icinga_ido_db_host', 'db4.miraheze.org')
    $db_name = hiera('icinga_ido_db_name', 'icinga')
    $db_user = hiera('icinga_ido_user_name', 'icinga2')
    $db_password = hiera('passwords::icinga_ido')

    group { 'nagios':
        ensure    => present,
        name      => 'nagios',
        system    => true,
        allowdupe => false,
    }

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

    file { '/etc/icinga2/features-available/checker.conf':
        source  => 'puppet:///modules/icinga2/checker.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { 'features-enabled-checker.conf':
        path => '/etc/icinga2/features-enabled/checker.conf',
        ensure  => 'link',
        target  => '/etc/icinga2/features-available/checker.conf',
        require => File['/etc/icinga2/features-available/checker.conf'],
    }


    file { '/etc/icinga2/scripts/mail-host-notification.sh':
        source  => 'puppet:///modules/icinga2/scripts/mail-host-notification.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/scripts/mail-service-notification.sh':
        source  => 'puppet:///modules/icinga2/scripts/mail-service-notification.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
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

    $ssl = loadyaml('/etc/puppet/ssl/certs.yaml')
    $redirects = loadyaml('/etc/puppet/ssl/redirects.yaml')
    $sslcerts = merge( $ssl, $redirects )

    file { '/etc/icinga2/conf.d/ssl.conf':
        ensure  => 'present',
        content => template('icinga2/ssl.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/scripts/ssl-renew.sh':
        ensure  => 'present',
        source  => 'puppet:///modules/icinga2/scripts/ssl-renew.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
    }

    file { '/var/lib/nagios/id_rsa2':
        ensure => present,
        source => 'puppet:///private/icinga2/id_rsa2',
        owner  => 'nagios',
        group  => 'nagios',
        mode   => '0400',
    }

    package { 'nagios-nrpe-plugin':
        ensure => present,
    }

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

    file { '/usr/lib/nagios/plugins/check_icinga_config':
        source  => 'puppet:///modules/icinga2/check_icinga_config',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['nagios-nrpe-plugin'],
    }

    icinga2::custom::services { 'Check correctness of the icinga configuration':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_icinga_config',
        },
    }

    tidy { '/var/spool/icinga2/perfdata':
        age     => '3d',
        recurse => 1,
        matches => [ 'service*', 'host*' ],
    }

    # Purge unmanaged icinga2::object::host and icinga2::object::service resources
    # This will only happen for non exported resources, that is resources that
    # are declared by the icinga host itself
    # resources { 'icinga2::object::host': purge => true, }
    # resources { 'icinga2::object::service': purge => true, }

    Icinga2::Object::Host <<||>> ~> Service['icinga2']
    Icinga2::Object::Service <<||>> ~> Service['icinga2']
}
