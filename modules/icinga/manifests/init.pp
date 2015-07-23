# icinga
class icinga {
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
        ensure => latest,
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

    file { '/etc/icinga/config/services.cfg':
        source  => 'puppet:///modules/icinga/services.cfg',
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
        mode   => '0775',
    }

    file { '/var/lib/nagios/rw/nagios.cmd':
        ensure => present,
        owner  => 'icinga',
        group  => 'www-data',
        mode   => '0664',
    }

}
