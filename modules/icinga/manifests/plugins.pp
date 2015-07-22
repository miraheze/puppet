# icinga::plugins
class icinga::plugins {
    file { '/usr/lib/nagios':
        ensure => directory,
        owner  => 'icinga',
        group  => 'icinga',
        mode   => '0755',
    }

    file { '/usr/lib/nagios/plugins':
        ensure => directory,
        owner  => 'icinga',
        group  => 'icinga',
        mode   => '0755',
    }

    file { '/var/lib/nagios':
        ensure => directory,
        owner  => 'icinga',
        group  => 'nagios',
        mode   => '0775',
    }

    file { '/etc/nagios-plugins':
        ensure => directory,
        owner  => 'icinga',
        group  => 'icinga',
        mode   => '0755',
    }

    file { '/etc/nagios-plugins/config':
        ensure => directory,
        owner  => 'icinga',
        group  => 'icinga',
        mode   => '0755',
    }
}
