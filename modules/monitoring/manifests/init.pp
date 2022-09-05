class monitoring (
    String $db_host,
    String $db_name               = 'icinga',
    String $db_user               = 'icinga2',
    String $db_password           = undef,
    String $mirahezebots_password = undef,
    String $ticket_salt           = '',
    Optional[String] $icinga2_api_bind_host = undef,
) {
    ensure_packages([
        'nagios-nrpe-plugin',
        'python3-dnspython',
        'python3-filelock',
        'python3-flask',
        'python3-tldextract',
    ])

    group { 'nagios':
        ensure    => present,
        name      => 'nagios',
        system    => true,
        allowdupe => false,
    }

    $http_proxy = lookup('http_proxy', {'default_value' => undef})
    $version = lookup('mariadb::version', {'default_value' => '10.4'})
    apt::source { 'mariadb_apt':
        comment  => 'MariaDB stable',
        location => "http://ams2.mirrors.digitalocean.com/mariadb/repo/${version}/debian",
        release  => $::lsbdistcodename,
        repos    => 'main',
        key      => {
                'id'      => '177F4010FE56CA3336300305F1656F24C74CD1D8',
                'options' => "http-proxy='${http_proxy}'",
                'server'  => 'hkp://keyserver.ubuntu.com:80',
        },
    }

    apt::pin { 'mariadb_pin':
        priority => 600,
        origin   => 'ams2.mirrors.digitalocean.com',
        require  => Apt::Source['mariadb_apt'],
        notify   => Exec['apt_update_mariadb'],
    }

    # First installs can trip without this
    exec { 'apt_update_mariadb':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
    }

    ensure_packages(
        "mariadb-client-${version}",
        {
            ensure  => present,
            require => Apt::Source['mariadb_apt'],
        },
    )

    class { '::icinga2':
        manage_repo => true,
        constants   => {
            'TicketSalt' => $ticket_salt
        }
    }

    class { '::icinga2::feature::api':
        bind_host   => $icinga2_api_bind_host,
        ca_host     => $::fqdn,
        ticket_salt => $ticket_salt,
    }

    include ::icinga2::feature::command

    include ::icinga2::feature::notification

    include ::icinga2::feature::perfdata

    class{ '::icinga2::feature::idomysql':
        host            => $db_host,
        user            => $db_user,
        password        => $db_password,
        database        => $db_name,
        import_schema   => false,
        enable_ssl      => true,
        ssl_cacert_path => '/etc/ssl/certs/Sectigo.crt',
    }

    class { '::icinga2::feature::gelf':
        host => 'graylog.miraheze.org',
    }

    file { '/etc/icinga2/conf.d/commands.conf':
        source  => 'puppet:///modules/monitoring/commands.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/groups.conf':
        source  => 'puppet:///modules/monitoring/groups.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/hosts.conf':
        source  => 'puppet:///modules/monitoring/hosts.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/notifications.conf':
        source  => 'puppet:///modules/monitoring/notifications.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/services.conf':
        source  => 'puppet:///modules/monitoring/services.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/templates.conf':
        source  => 'puppet:///modules/monitoring/templates.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/timeperiods.conf':
        source  => 'puppet:///modules/monitoring/timeperiods.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/conf.d/users.conf':
        source  => 'puppet:///modules/monitoring/users.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/scripts/mail-host-notification.sh':
        source  => 'puppet:///modules/monitoring/scripts/mail-host-notification.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/scripts/mail-service-notification.sh':
        source  => 'puppet:///modules/monitoring/scripts/mail-service-notification.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/scripts/irc-host-notification.sh':
        source  => 'puppet:///modules/monitoring/scripts/irc-host-notification.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/scripts/irc-service-notification.sh':
        source  => 'puppet:///modules/monitoring/scripts/irc-service-notification.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    $ssl = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')
    $redirects = loadyaml('/etc/puppetlabs/puppet/ssl-cert/redirects.yaml')
    $sslcerts = merge( $ssl, $redirects )

    file { '/etc/icinga2/conf.d/ssl.conf':
        ensure  => 'present',
        content => template('monitoring/ssl.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0664',
        require => Package['icinga2'],
        notify  => Service['icinga2'],
    }

    file { '/etc/icinga2/scripts/ssl-renew.sh':
        ensure => 'present',
        source => 'puppet:///modules/monitoring/scripts/ssl-renew.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/var/lib/nagios/id_rsa2':
        ensure => present,
        source => 'puppet:///private/icinga2/id_rsa2',
        owner  => 'nagios',
        group  => 'nagios',
        mode   => '0400',
    }

    # includes a irc bot to relay messages from icinga to irc
    class { '::monitoring::ircecho':
        mirahezebots_password => $mirahezebots_password,
    }

    file { '/usr/lib/nagios/plugins/check_icinga_config':
        source  => 'puppet:///modules/monitoring/check_icinga_config',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['nagios-nrpe-plugin'],
    }

    file { '/usr/lib/nagios/plugins/check_reverse_dns.py':
        source  => 'puppet:///modules/monitoring/check_reverse_dns.py',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['nagios-nrpe-plugin'],
    }

    # Setup webhook for grafana to call
    file { '/usr/local/bin/grafana-webhook.py':
        ensure => present,
        source => 'puppet:///modules/monitoring/grafana-webhook.py',
        mode   => '0755',
        notify => Service['grafana-webhook'],
    }

    systemd::service { 'grafana-webhook':
        ensure  => present,
        content => systemd_template('grafana-webhook'),
        restart => true,
    }

    # Icinga monitoring
    monitoring::nrpe { 'Check correctness of the icinga configuration':
        command => '/usr/lib/nagios/plugins/check_icinga_config /etc/icinga/icinga.cfg'
    }

    cron { 'remove_icinga2_perfdata_2_days':
        ensure  => present,
        command => '/usr/bin/find /var/spool/icinga2/perfdata -type f -mtime +2 -exec rm {} +',
        user    => 'root',
        hour    => 5,
        minute  => 0,
    }

    Icinga2::Object::Host <<||>> ~> Service['icinga2']
    Icinga2::Object::Service <<||>> ~> Service['icinga2']
}
