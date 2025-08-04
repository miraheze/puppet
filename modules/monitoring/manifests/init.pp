class monitoring (
    String $db_host,
    String $db_name                         = 'icinga',
    String $db_user                         = 'icinga2',
    String $db_password                     = undef,
    String $mirahezebots_password           = undef,
    String $ticket_salt                     = '',
    Optional[String] $icinga2_api_bind_host = undef,
) {
    stdlib::ensure_packages([
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
    if $http_proxy and !defined(File['/etc/apt/apt.conf.d/02mariadb']) {
        file { '/etc/apt/apt.conf.d/02mariadb':
            ensure  => present,
            content => template('mariadb/aptproxy.erb'),
        }
    }

    $version = lookup('mariadb::version', {'default_value' => '11.8'})
    apt::source { 'mariadb_apt':
        comment  => 'MariaDB stable',
        location => "https://mirror.mariadb.org/repo/${version}/debian",
        release  => $facts['os']['distro']['codename'],
        repos    => 'main',
        key      => {
            'name'   => 'mariadb_release_signing_key.pgp',
            'source' => 'puppet:///modules/mariadb/mariadb_release_signing_key.pgp',
        },
    }

    apt::pin { 'mariadb_pin':
        priority => 600,
        origin   => 'mirror.mariadb.org',
        require  => Apt::Source['mariadb_apt'],
        notify   => Exec['apt_update_mariadb'],
    }

    # First installs can trip without this
    exec { 'apt_update_mariadb':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
    }

    stdlib::ensure_packages(
        'mariadb-client',
        {
            ensure  => present,
            require => Apt::Source['mariadb_apt'],
        },
    )

    class { 'icinga2':
        manage_repos => true,
        constants    => {
            'TicketSalt' => Sensitive($ticket_salt),
        }
    }

    class { 'icinga2::feature::api':
        bind_host   => $icinga2_api_bind_host,
        ca_host     => $facts['networking']['fqdn'],
        ticket_salt => Sensitive($ticket_salt),
    }

    include icinga2::feature::command

    include icinga2::feature::notification

    include icinga2::feature::perfdata

    class { 'icinga2::feature::idomysql':
        host          => $db_host,
        user          => $db_user,
        password      => $db_password,
        database      => $db_name,
        import_schema => false,
    }

    class { 'icinga2::feature::gelf':
        host => 'logging.wikitide.net',
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
    $domains = readlines('/etc/puppetlabs/puppet/ssl-cert/cloudflare_domains')
    $redirects = loadyaml('/etc/puppetlabs/puppet/ssl-cert/redirects.yaml')
    $sslcerts = $ssl + $redirects

    $servers = query_nodes('Class[Role::Mediawiki]')
        .flatten()
        .unique()
        .sort()

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

    # includes a irc bot to relay messages from icinga to irc
    class { 'monitoring::ircecho':
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
        ensure => absent,
    }

    file { '/usr/lib/nagios/plugins/check_mysql_connections.php':
        source  => 'puppet:///modules/monitoring/check_mysql_connections.php',
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
        command => '/usr/lib/nagios/plugins/check_icinga_config'
    }

    systemd::timer::job { 'remove_icinga2_perfdata':
        ensure      => present,
        description => 'Removes Icinga2 perfdata files older than 2 days',
        command     => '/usr/bin/find /var/spool/icinga2/perfdata -type f -mtime +2 -exec rm {} +',
        interval    => {
            start    => 'OnCalendar',
            interval => '*-*-* 05:00:00',
        },
        user        => 'root',
    }

    Icinga2::Object::Host <<||>> ~> Service['icinga2']
    Icinga2::Object::Service <<||>> ~> Service['icinga2']
}
