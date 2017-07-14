# icinga
class icinga {
    include ::apache::mod::alias
    include ::apache::mod::php5
    include ::apache::mod::rewrite
    include ::apache::mod::ssl

    group { 'nagios':
        ensure    => present,
        name      => 'nagios',
        system    => true,
        allowdupe => false,
    }

    group { 'icinga':
        ensure => present,
        name   => 'icinga',
    }

    user { 'icinga':
        name       => 'icinga',
        home       => '/home/icinga',
        gid        => 'icinga',
        system     => true,
        managehome => false,
        shell      => '/bin/false',
        require    => [ Group['icinga'], Group['nagios'] ],
        groups     => 'nagios',
    }

    package { 'icinga':
        ensure => present,
    }

    file { '/etc/icinga/cgi.cfg':
        source  => 'puppet:///modules/icinga/cgi.cfg',
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0644',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    file { '/etc/icinga/icinga.cfg':
        source  => 'puppet:///modules/icinga/icinga.cfg',
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0644',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    file { '/etc/icinga/config/generics.cfg':
        source  => 'puppet:///modules/icinga/generics.cfg',
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0664',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    file { '/etc/icinga/config/extinfo.cfg':
        source  => 'puppet:///modules/icinga/extinfo.cfg',
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0664',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    file { '/etc/icinga/config/contactgroups.cfg':
        source  => 'puppet:///modules/icinga/contactgroups.cfg',
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0644',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    file { '/etc/icinga/config/contacts.cfg':
        source  => 'puppet:///modules/icinga/contacts.cfg',
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0644',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }


    file { '/etc/icinga/config/timeperiods.cfg':
        source  => 'puppet:///modules/icinga/timeperiods.cfg',
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0664',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    file { '/etc/icinga/commands.cfg':
        source  => 'puppet:///modules/icinga/commands.cfg',
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0664',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    file { '/etc/icinga/config/hosts.cfg':
        source  => 'puppet:///modules/icinga/hosts.cfg',
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0664',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    file { '/etc/icinga/config/hostgroups.cfg':
        source  => 'puppet:///modules/icinga/hostgroups.cfg',
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0664',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    $ssl = loadyaml('/etc/puppet/ssl/certs.yaml')
    $redirects = loadyaml('/etc/puppet/ssl/redirects.yaml')
    $sslcerts = merge( $ssl, $redirects )

    file { '/etc/icinga/config/ssl.cfg':
        ensure  => 'present',
        content => template('icinga/ssl.cfg'),
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0664',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    $icingabot_password = hiera('passwords::phabricator::icinga')

    file { '/etc/icinga/ssl-phabricator.py':
        ensure  => 'present',
        content => template('icinga/ssl-phabricator.py'),
        owner   => 'icinga',
        group   => 'icinga',
        mode    => '0755',
    }

    class { 'icinga::plugins':
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    service { 'icinga':
        ensure    => running,
        hasstatus => false,
        restart   => '/etc/init.d/icinga reload',
    }

    file { '/var/lib/nagios/rw':
        ensure => directory,
        owner  => 'icinga',
        group  => 'nagios',
        mode   => '0777',
    }

    file { '/var/lib/nagios/rw/nagios.cmd':
        ensure => present,
        owner  => 'icinga',
        group  => 'www-data',
        mode   => '0666',
    }

    package { 'nagios-nrpe-plugin':
        ensure => present,
    }

    file { '/etc/apache2/conf-enabled/icinga.conf':
        ensure => absent,
    }

    ssl::cert { 'wildcard.miraheze.org': }

    apache::site { 'icinga.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/icinga/apache/apache.conf',
        require => File['/etc/apache2/conf-enabled/icinga.conf'],
    }

    $mirahezebots_password = hiera('passwords::irc::mirahezebots')

    file { '/etc/icinga/irc.py':
        ensure  => present,
        owner   => 'irc',
        content => template('icinga/bot/irc.py'),
        mode    => '0551',
        notify  => Service['icingabot'],
    }

    file { '/etc/init.d/icingabot':
        ensure => present,
        source => 'puppet:///modules/icinga/bot/icingabot.initd',
        mode   => '0755',
        notify => Service['icingabot'],
    }

    exec { 'Icingabot reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/icingabot.service':
        ensure => present,
        source => 'puppet:///modules/icinga/bot/icingabot.systemd',
        notify => Exec['Icingabot reload systemd'],
    }

    service { 'icingabot':
        ensure => running,
    }

    # collect exported resources
    Nagios_host <<| |>> ~> Service['icinga']
    Nagios_service <<| |>> ~> Service['icinga']
}
